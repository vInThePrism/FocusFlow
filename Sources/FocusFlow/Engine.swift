import Foundation
import AppKit
import Combine
import CoreGraphics

/// The timer. Times are measured against wall-clock end dates, so sleep or a busy
/// main thread never makes the countdown drift.
@MainActor
final class Engine: ObservableObject {
    enum RunState { case idle, running, paused, finished }

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var state: RunState = .idle
    @Published private(set) var remaining: TimeInterval = 1500
    @Published private(set) var planned: TimeInterval = 1500
    @Published private(set) var extensionSeconds = 0
    @Published private(set) var extensions = 0
    @Published private(set) var completedInCycle = 0
    @Published private(set) var idlePaused = false
    @Published var intention: String {
        didSet { UserDefaults.standard.set(intention, forKey: Pref.intention) }
    }

    private let store: Store
    private var endDate: Date?
    private var recordID: UUID?
    private var startDate: Date?
    private var finishedAt: Date?
    private var frozenAt: Date?
    private var accumulated: TimeInterval = 0
    private var resumedAt: Date?
    private var completedOnce = false
    private var lastCheckpoint = Date.distantPast
    private var lastIdleCheck = Date.distantPast
    private var ticker: AnyCancellable?
    private var bag = Set<AnyCancellable>()

    init(store: Store) {
        self.store = store
        intention = UserDefaults.standard.string(forKey: Pref.intention) ?? ""
        loadCycle()
        prepare(.focus)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: Notifier.extendRequested)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.extend() }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: Notifier.breakRequested)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.startBreak(nil) }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: Notifier.focusRequested)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.startFocusFromNotification() }
            .store(in: &bag)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tick() }
            .store(in: &bag)
    }

    // MARK: - Derived values

    var total: TimeInterval { planned + TimeInterval(extensionSeconds) }

    var activeSeconds: TimeInterval {
        accumulated + (resumedAt.map { Date().timeIntervalSince($0) } ?? 0)
    }

    /// 0 at the start, 1 when time is up.
    var progress: Double {
        if state == .finished { return 1 }
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    var extendStep: Int { max(1, Pref.int(Pref.extendMinutes)) }

    var canExtend: Bool {
        guard phase == .focus, state != .idle else { return false }
        return Pref.bool(Pref.repeatExtension) || extensions == 0
    }

    var dailyGoal: Int { max(1, Pref.int(Pref.dailyGoal)) }

    /// 1-based number of the pomodoro in the current cycle, for "Pomodoro 1 of 4".
    var pomodoroIndex: Int {
        if phase != .focus { return min(completedInCycle, Pref.cycleLength) }
        if state == .finished { return min(max(completedInCycle, 1), Pref.cycleLength) }
        return min(completedInCycle + 1, Pref.cycleLength)
    }

    var suggestedBreak: Phase { completedInCycle >= Pref.cycleLength ? .longBreak : .shortBreak }

    func duration(for p: Phase) -> TimeInterval {
        let key: String
        switch p {
        case .focus: key = Pref.focusMinutes
        case .shortBreak: key = Pref.shortBreakMinutes
        case .longBreak: key = Pref.longBreakMinutes
        }
        return TimeInterval(max(1, Pref.int(key)) * 60)
    }

    /// The session in progress, as it would be saved right now.
    var liveRecord: SessionRecord? {
        guard state != .idle, let id = recordID, let start = startDate else { return nil }
        let end: Date
        switch state {
        case .running: end = Date()
        case .finished: end = finishedAt ?? Date()
        default: end = frozenAt ?? Date()
        }
        return SessionRecord(
            id: id,
            phase: phase,
            intention: phase == .focus ? intention : "",
            start: start,
            end: end,
            plannedSeconds: Int(planned.rounded()),
            extensionSeconds: extensionSeconds,
            extensions: extensions,
            activeSeconds: Int(activeSeconds.rounded()),
            completed: completedOnce
        )
    }

    // MARK: - Actions

    func select(_ p: Phase) {
        if p == phase && state == .idle { return }
        if state != .idle { commit() }
        prepare(p)
    }

    func start() {
        guard state == .idle else { return }
        recordID = UUID()
        startDate = Date()
        accumulated = 0
        if phase == .longBreak {
            completedInCycle = 0
            saveCycle()
        }
        Sound.play(.start)
        run()
    }

    func pause() {
        guard state == .running else { return }
        freezeClock()
        state = .paused
        stopTicker()
        checkpoint()
    }

    func resume() {
        guard state == .paused else { return }
        run()
    }

    func toggle() {
        switch state {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        case .finished: extend()
        }
    }

    /// Adds time. After time's up this restarts the countdown with the added minutes.
    func extend(minutes: Int? = nil) {
        guard canExtend else { return }
        let add = (minutes ?? extendStep) * 60
        extensionSeconds += add
        extensions += 1
        switch state {
        case .finished:
            remaining = TimeInterval(add)
            finishedAt = nil
            run()
        case .running:
            endDate = endDate?.addingTimeInterval(TimeInterval(add))
            remaining += TimeInterval(add)
        case .paused:
            remaining += TimeInterval(add)
        case .idle:
            break
        }
        checkpoint()
    }

    /// "Finish session": save and get ready for the next focus.
    func finishSession() {
        if state != .idle { commit() }
        prepare(.focus)
    }

    /// Saves the focus session (if any) and starts a break.
    func startBreak(_ kind: Phase?) {
        if state != .idle { commit() }
        prepare(kind ?? suggestedBreak)
        start()
    }

    /// "Reset": stop this timer and set it back to full length. Time already focused is kept.
    func reset() {
        if state != .idle { commit() }
        prepare(phase)
    }

    func skipBreak() {
        if state != .idle { commit() }
        prepare(.focus)
    }

    func resetCycle() {
        completedInCycle = 0
        saveCycle()
    }

    func saveOnQuit() {
        guard state != .idle else { return }
        if state == .running { freezeClock() }
        commit()
    }

    private func startFocusFromNotification() {
        if phase != .focus || state == .finished { finishSession() }
        if state == .idle { start() }
    }

    // MARK: - Internals

    private func prepare(_ p: Phase) {
        stopTicker()
        phase = p
        state = .idle
        planned = duration(for: p)
        remaining = planned
        extensionSeconds = 0
        extensions = 0
        recordID = nil
        startDate = nil
        finishedAt = nil
        frozenAt = nil
        accumulated = 0
        resumedAt = nil
        endDate = nil
        completedOnce = false
        idlePaused = false
    }

    private func run() {
        let now = Date()
        resumedAt = now
        frozenAt = nil
        endDate = now.addingTimeInterval(remaining)
        state = .running
        idlePaused = false
        lastIdleCheck = now
        ticker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func freezeClock() {
        let now = Date()
        if let r = resumedAt { accumulated += now.timeIntervalSince(r) }
        resumedAt = nil
        if let e = endDate { remaining = max(0, e.timeIntervalSince(now)) }
        endDate = nil
        frozenAt = now
    }

    private func tick() {
        guard state == .running, let e = endDate else { return }
        remaining = max(0, e.timeIntervalSinceNow)
        if remaining <= 0 {
            complete()
            return
        }
        checkIdle()
        if Date().timeIntervalSince(lastCheckpoint) >= 30 { checkpoint() }
    }

    private func complete() {
        freezeClock()
        remaining = 0
        stopTicker()
        Sound.play(.end)
        if phase == .focus {
            if !completedOnce {
                completedOnce = true
                completedInCycle += 1
                saveCycle()
            }
            state = .finished
            finishedAt = Date()
            checkpoint()
            Notifier.shared.focusDone(minutes: Int((activeSeconds / 60).rounded()), intention: intention, step: extendStep)
        } else {
            completedOnce = true
            commit()
            prepare(.focus)
            Notifier.shared.breakDone()
            if Pref.bool(Pref.autoStart) { start() }
        }
    }

    /// Writes the running session to disk. Short focus attempts (< 1 min) aren't kept.
    private func checkpoint() {
        lastCheckpoint = Date()
        guard let r = liveRecord, r.activeSeconds >= 60 || r.completed else { return }
        store.upsert(r)
    }

    /// Final save before the session is cleared.
    private func commit() {
        if state == .running { freezeClock() }
        guard let r = liveRecord else { return }
        if r.activeSeconds >= 60 || r.completed {
            store.upsert(r)
        } else {
            store.delete(r.id)
        }
    }

    private func checkIdle() {
        guard phase == .focus, Pref.bool(Pref.idlePause) else { return }
        let now = Date()
        guard now.timeIntervalSince(lastIdleCheck) >= 5 else { return }
        lastIdleCheck = now
        guard let anyInput = CGEventType(rawValue: ~0) else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        let threshold = TimeInterval(max(1, Pref.int(Pref.idleMinutes)) * 60)
        guard idle >= threshold else { return }
        freezeClock()
        // Give back the minutes you were away, so they don't count as focus.
        let giveBack = min(idle, accumulated)
        accumulated -= giveBack
        remaining = min(total, remaining + giveBack)
        state = .paused
        idlePaused = true
        stopTicker()
        checkpoint()
    }

    private func settingsChanged() {
        if state == .idle {
            let d = duration(for: phase)
            if d != planned {
                planned = d
                remaining = d
            }
        }
        objectWillChange.send()
    }

    private func loadCycle() {
        let today = Fmt.fileStamp.string(from: Date())
        if UserDefaults.standard.string(forKey: Pref.cycleDay) == today {
            completedInCycle = Pref.int(Pref.cycleCount)
        } else {
            completedInCycle = 0
        }
    }

    private func saveCycle() {
        UserDefaults.standard.set(completedInCycle, forKey: Pref.cycleCount)
        UserDefaults.standard.set(Fmt.fileStamp.string(from: Date()), forKey: Pref.cycleDay)
    }
}
