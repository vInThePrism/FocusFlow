import Foundation
import AppKit

// MARK: - Session types

enum Phase: String, Codable, CaseIterable, Identifiable {
    case focus, shortBreak, longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var lowerTitle: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "scope"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "tree"
        }
    }

    var isBreak: Bool { self != .focus }
}

/// One saved session. Focus sessions keep their extensions in the same record.
struct SessionRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var phase: Phase
    var intention: String
    var start: Date
    var end: Date
    /// Length the timer was originally set to.
    var plannedSeconds: Int
    /// Total minutes added through +5 / +10 / +15, in seconds.
    var extensionSeconds: Int
    /// How many times time was added.
    var extensions: Int
    /// Time the timer actually ran (pauses excluded).
    var activeSeconds: Int
    /// True once the timer reached zero at least once.
    var completed: Bool

    var baseSeconds: Int { min(activeSeconds, plannedSeconds) }
    var extendedSeconds: Int { max(0, activeSeconds - plannedSeconds) }

    enum CodingKeys: String, CodingKey {
        case id, phase, intention, start, end, plannedSeconds, extensionSeconds, extensions, activeSeconds, completed
    }
}

extension SessionRecord {
    /// Tolerant decoding so older or hand-edited files still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        start = try c.decode(Date.self, forKey: .start)
        end = (try? c.decode(Date.self, forKey: .end)) ?? start
        phase = (try? c.decode(Phase.self, forKey: .phase)) ?? .focus
        intention = (try? c.decode(String.self, forKey: .intention)) ?? ""
        activeSeconds = (try? c.decode(Int.self, forKey: .activeSeconds)) ?? Int(end.timeIntervalSince(start))
        plannedSeconds = (try? c.decode(Int.self, forKey: .plannedSeconds)) ?? activeSeconds
        extensionSeconds = (try? c.decode(Int.self, forKey: .extensionSeconds)) ?? 0
        extensions = (try? c.decode(Int.self, forKey: .extensions)) ?? 0
        completed = (try? c.decode(Bool.self, forKey: .completed)) ?? true
    }
}

// MARK: - Preferences

enum Pref {
    static let focusMinutes = "focusMinutes"
    static let shortBreakMinutes = "shortBreakMinutes"
    static let longBreakMinutes = "longBreakMinutes"
    static let autoStart = "autoStartNext"
    static let soundsOn = "soundsOn"
    static let soundTheme = "soundTheme"
    static let idlePause = "idlePause"
    static let idleMinutes = "idleMinutes"
    static let dailyGoal = "dailyGoalSessions"
    static let weeklyGoalHours = "weeklyGoalHours"
    static let repeatExtension = "repeatExtension"
    static let extendMinutes = "extendMinutes"
    static let menuBarTime = "menuBarShowsTime"
    static let miniTimer = "showMiniTimer"
    static let intention = "currentIntention"
    static let dataFolder = "dataFolderPath"
    static let cycleCount = "cycleCount"
    static let cycleDay = "cycleDay"

    static let cycleLength = 4

    static func register() {
        UserDefaults.standard.register(defaults: [
            focusMinutes: 25,
            shortBreakMinutes: 5,
            longBreakMinutes: 15,
            autoStart: true,
            soundsOn: true,
            soundTheme: SoundTheme.calm.rawValue,
            idlePause: true,
            idleMinutes: 5,
            dailyGoal: 6,
            weeklyGoalHours: 25,
            repeatExtension: true,
            extendMinutes: 5,
            menuBarTime: true,
            miniTimer: false,
            intention: "",
        ])
    }

    static func int(_ key: String) -> Int { UserDefaults.standard.integer(forKey: key) }
    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
}

// MARK: - Sounds

enum SoundTheme: String, CaseIterable, Identifiable {
    case calm = "Calm", bright = "Bright", classic = "Classic", soft = "Soft"

    var id: String { rawValue }

    var startSound: String {
        switch self {
        case .calm: return "Purr"
        case .bright: return "Pop"
        case .classic: return "Tink"
        case .soft: return "Bottle"
        }
    }

    var endSound: String {
        switch self {
        case .calm: return "Glass"
        case .bright: return "Hero"
        case .classic: return "Ping"
        case .soft: return "Submarine"
        }
    }
}

enum Sound {
    enum Event { case start, end }

    static func play(_ event: Event, force: Bool = false) {
        guard force || Pref.bool(Pref.soundsOn) else { return }
        let raw = UserDefaults.standard.string(forKey: Pref.soundTheme) ?? ""
        let theme = SoundTheme(rawValue: raw) ?? .calm
        let name = event == .start ? theme.startSound : theme.endSound
        NSSound(named: NSSound.Name(name))?.play()
    }
}
