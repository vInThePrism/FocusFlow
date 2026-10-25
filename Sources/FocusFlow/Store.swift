import Foundation
import AppKit

/// Everything FocusFlow saves, in one file.
struct Payload {
    var sessions: [SessionRecord] = []
    var tasks: [PlanTask] = []
    var blocks: [TimeBlock] = []
    var deadlines: [Deadline] = []
    var checks: [String: [UUID]] = [:]
    var leetcode = LCState()
    var applications = ApplicationState()
    var interviewEntries: [InterviewEntry] = []
}

/// Saves sessions, plan tasks, time blocks and deadlines to a JSON file on this Mac.
///
/// Safety measures:
/// - every write is atomic (written to a temp file, then swapped in), so a crash mid-write can't corrupt the file
/// - the running session is checkpointed every 30 s, so a crash or power cut loses at most 30 s
/// - before the first write of each day the previous file is copied to Backups/ (30 days kept)
/// - an unreadable file is never overwritten: it is copied aside and the newest good backup is restored
@MainActor
final class Store: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []
    @Published private(set) var tasks: [PlanTask] = []
    @Published private(set) var blocks: [TimeBlock] = []
    @Published private(set) var deadlines: [Deadline] = []
    @Published private(set) var checks: [String: [UUID]] = [:]
    @Published private(set) var leetcode = LCState()
    @Published private(set) var applications = ApplicationState()
    @Published private(set) var interviewEntries: [InterviewEntry] = []
    private var noteSave: Task<Void, Never>?
    @Published private(set) var lastSaved: Date?
    @Published private(set) var problem: String?
    @Published private(set) var folderURL: URL

    var fileURL: URL { folderURL.appendingPathComponent("sessions.json") }
    var backupsURL: URL { folderURL.appendingPathComponent("Backups", isDirectory: true) }
    var usesDefaultFolder: Bool { folderURL.standardizedFileURL == Store.defaultFolder.standardizedFileURL }
    var backupCount: Int { backupFiles().count }

    static let defaultFolder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FocusFlow", isDirectory: true)
    }()

    private struct FileBody: Codable {
        var app: String
        var version: Int
        var savedAt: Date
        var sessions: [SessionRecord]
        var tasks: [PlanTask]?
        var blocks: [TimeBlock]?
        var deadlines: [Deadline]?
        var checks: [String: [UUID]]?
        var leetcode: LCState?
        var applications: ApplicationState?
        var interviewEntries: [InterviewEntry]?
    }

    init() {
        Pref.register()
        if let path = UserDefaults.standard.string(forKey: Pref.dataFolder), !path.isEmpty {
            folderURL = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            folderURL = Store.defaultFolder
        }
        prepareFolder()
        load()
        importLegacyIfNeeded()
        seedCommonListsIfNeeded()
    }

    // MARK: - Reading

    private func prepareFolder() {
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            problem = "Couldn't create the data folder: \(error.localizedDescription)"
        }
    }

    static func decode(_ data: Data) -> Payload? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let body = try? decoder.decode(FileBody.self, from: data) {
            return Payload(sessions: body.sessions, tasks: body.tasks ?? [], blocks: body.blocks ?? [],
                           deadlines: body.deadlines ?? [], checks: body.checks ?? [:], leetcode: body.leetcode ?? LCState(), applications: body.applications ?? ApplicationState(), interviewEntries: body.interviewEntries ?? [])
        }
        if let list = try? decoder.decode([SessionRecord].self, from: data) {
            return Payload(sessions: list)
        }
        return nil
    }

    private func apply(_ p: Payload) {
        records = p.sessions.sorted { $0.start < $1.start }
        tasks = p.tasks
        blocks = p.blocks.sorted { $0.start < $1.start }
        deadlines = p.deadlines.sorted { $0.date < $1.date }
        checks = p.checks
        leetcode = p.leetcode
        applications = p.applications
        interviewEntries = p.interviewEntries
        repairInterviewLinks()
        repairApplicationLinks()
    }

    private var payload: Payload {
        Payload(sessions: records, tasks: tasks, blocks: blocks, deadlines: deadlines, checks: checks, leetcode: leetcode, applications: applications, interviewEntries: interviewEntries)
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        if let data = try? Data(contentsOf: fileURL), let p = Store.decode(data) {
            apply(p)
            return
        }
        // The file exists but can't be read. Keep it untouched under another name,
        // then fall back to the newest backup that still reads.
        let damaged = quarantine(fileURL)
        if let found = newestGoodBackup() {
            apply(found.payload)
            problem = "sessions.json couldn't be read, so FocusFlow restored \(found.name). The original was kept as \(damaged)."
            save()
        } else {
            problem = "sessions.json couldn't be read. It was kept as \(damaged) so nothing is lost."
        }
    }

    @discardableResult
    private func quarantine(_ url: URL) -> String {
        let stamp = Int(Date().timeIntervalSince1970)
        let target = url.deletingLastPathComponent().appendingPathComponent("sessions.damaged-\(stamp).json")
        try? FileManager.default.copyItem(at: url, to: target)
        return target.lastPathComponent
    }

    private func backupFiles() -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: backupsURL, includingPropertiesForKeys: nil)) ?? []
        return items
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func newestGoodBackup() -> (payload: Payload, name: String)? {
        for url in backupFiles() {
            if let data = try? Data(contentsOf: url), let p = Store.decode(data) {
                return (p, url.lastPathComponent)
            }
        }
        return nil
    }

    // MARK: - Writing

    private func encoded(_ p: Payload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let body = FileBody(app: "FocusFlow", version: 5, savedAt: Date(), sessions: p.sessions,
                            tasks: p.tasks, blocks: p.blocks, deadlines: p.deadlines, checks: p.checks, leetcode: p.leetcode, applications: p.applications, interviewEntries: p.interviewEntries)
        return try encoder.encode(body)
    }

    private func save() {
        backupIfNeeded()
        do {
            try encoded(payload).write(to: fileURL, options: .atomic)
            lastSaved = Date()
            if problem?.hasPrefix("Couldn't save") == true { problem = nil }
        } catch {
            problem = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func backupIfNeeded() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        try? fm.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        let target = backupsURL.appendingPathComponent("sessions-\(Fmt.fileStamp.string(from: Date())).json")
        guard !fm.fileExists(atPath: target.path) else { return }
        try? fm.copyItem(at: fileURL, to: target)
        for old in backupFiles().dropFirst(30) {
            try? fm.removeItem(at: old)
        }
    }

    // MARK: - Sessions

    func upsert(_ record: SessionRecord) {
        if let i = records.firstIndex(where: { $0.id == record.id }) {
            records[i] = record
        } else {
            records.append(record)
            records.sort { $0.start < $1.start }
        }
        repairInterviewLinks()
        save()
    }

    func delete(_ id: UUID) {
        guard records.contains(where: { $0.id == id }) else { return }
        records.removeAll { $0.id == id }
        interviewEntries.removeAll { $0.sessionID == id }
        save()
    }

    func rename(_ id: UUID, to text: String) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        records[i].intention = text.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func setCountsInStats(_ id: UUID, _ on: Bool) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        records[i].countsInStats = on
        save()
    }

    /// Records plus the session that's running right now.
    func merged(with live: SessionRecord?) -> [SessionRecord] {
        guard let live = live else { return records }
        var out = records.filter { $0.id != live.id }
        out.append(live)
        return out
    }

    // MARK: - Plan tasks

    func task(_ id: UUID?) -> PlanTask? {
        guard let id = id else { return nil }
        return tasks.first { $0.id == id }
    }

    func saveTask(_ t: PlanTask) {
        if let i = tasks.firstIndex(where: { $0.id == t.id }) {
            tasks[i] = t
        } else {
            tasks.append(t)
        }
        save()
    }

    func deleteTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        interviewEntries.removeAll { $0.taskID == id }
        save()
    }

    /// Adds the parsed tasks on the chosen weekdays. A task with the same name is updated
    /// (minutes and note replaced, weekdays added) instead of duplicated.
    @discardableResult
    func applyBulk(_ parsed: [ParsedTask], weekdays: Set<Int>) -> Int {
        guard !weekdays.isEmpty else { return 0 }
        for p in parsed {
            if let i = tasks.firstIndex(where: { $0.name.caseInsensitiveCompare(p.name) == .orderedSame }) {
                tasks[i].minutes = p.minutes
                if !p.note.isEmpty { tasks[i].note = p.note }
                tasks[i].weekdays.formUnion(weekdays)
                tasks[i].enabled = true
            } else {
                tasks.append(PlanTask(name: p.name, minutes: p.minutes, note: p.note, weekdays: weekdays,
                                      icon: TaskIcons.guess(p.name)))
            }
        }
        save()
        return parsed.count
    }

    func toggleCheck(_ taskID: UUID, on day: Date) {
        let key = PlanLogic.key(day)
        var list = checks[key] ?? []
        if let i = list.firstIndex(of: taskID) {
            list.remove(at: i)
        } else {
            list.append(taskID)
        }
        checks[key] = list.isEmpty ? nil : list
        save()
    }

    // MARK: - Time blocks

    func saveBlock(_ b: TimeBlock) {
        if let i = blocks.firstIndex(where: { $0.id == b.id }) {
            blocks[i] = b
        } else {
            blocks.append(b)
        }
        blocks.sort { $0.start < $1.start }
        save()
    }

    func deleteBlock(_ id: UUID) {
        blocks.removeAll { $0.id == id }
        save()
    }

    // MARK: - Deadlines

    func saveDeadline(_ d: Deadline) {
        if let i = deadlines.firstIndex(where: { $0.id == d.id }) {
            deadlines[i] = d
        } else {
            deadlines.append(d)
        }
        deadlines.sort { $0.date < $1.date }
        save()
    }

    func deleteDeadline(_ id: UUID) {
        deadlines.removeAll { $0.id == id }
        save()
    }

    func toggleDeadline(_ id: UUID) {
        guard let i = deadlines.firstIndex(where: { $0.id == id }) else { return }
        deadlines[i].done.toggle()
        save()
    }

    // MARK: - Merge, location, export, import

    /// Adds whatever isn't here yet. Never removes anything.
    @discardableResult
    func merge(_ incoming: Payload) -> Int {
        var byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var added = 0
        for r in incoming.sessions {
            if let current = byID[r.id] {
                if r.end > current.end { byID[r.id] = r }
            } else {
                byID[r.id] = r
                added += 1
            }
        }
        records = byID.values.sorted { $0.start < $1.start }

        let taskIDs = Set(tasks.map { $0.id })
        tasks += incoming.tasks.filter { !taskIDs.contains($0.id) }
        let blockIDs = Set(blocks.map { $0.id })
        blocks = (blocks + incoming.blocks.filter { !blockIDs.contains($0.id) }).sorted { $0.start < $1.start }
        let deadlineIDs = Set(deadlines.map { $0.id })
        deadlines = (deadlines + incoming.deadlines.filter { !deadlineIDs.contains($0.id) }).sorted { $0.date < $1.date }
        for (key, ids) in incoming.checks {
            let existing = checks[key] ?? []
            checks[key] = existing + ids.filter { !existing.contains($0) }
        }
        leetcode.merge(incoming.leetcode)
        var entries = Dictionary(interviewEntries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for entry in incoming.interviewEntries {
            if entries[entry.id] == nil || entry.updatedAt > entries[entry.id]!.updatedAt { entries[entry.id] = entry }
        }
        interviewEntries = Array(entries.values)
        repairInterviewLinks()
        applications.merge(incoming.applications)
        repairApplicationLinks()
        for i in records.indices where records[i].problemOutcome == nil {
            if let attempt = leetcode.attempts.first(where: { $0.sessionID == records[i].id && $0.problemID == records[i].problemID }) {
                records[i].problemOutcome = attempt.outcome
            }
        }
        save()
        return added
    }

    /// Copies everything into another folder (for example iCloud Drive) and keeps using it.
    /// The old file stays where it was.
    func moveData(to newFolder: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: newFolder, withIntermediateDirectories: true)
        let target = newFolder.appendingPathComponent("sessions.json")
        var existing = Payload()
        if fm.fileExists(atPath: target.path) {
            if let data = try? Data(contentsOf: target), let p = Store.decode(data) {
                existing = p
            } else {
                quarantine(target)
            }
        }
        folderURL = newFolder
        if newFolder.standardizedFileURL == Store.defaultFolder.standardizedFileURL {
            UserDefaults.standard.removeObject(forKey: Pref.dataFolder)
        } else {
            UserDefaults.standard.set(newFolder.path, forKey: Pref.dataFolder)
        }
        merge(existing)
    }

    func exportJSON(to url: URL) throws {
        try encoded(payload).write(to: url, options: .atomic)
    }

    func exportCSV(to url: URL) throws {
        let iso = ISO8601DateFormatter()
        func quoted(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["id,type,manual,intention,task,start,end,planned_min,extensions,extension_min,focused_min,completed,in_stats,note,leetcode_problem,leetcode_result"]
        for r in records {
            let fields: [String] = [
                r.id.uuidString,
                r.phase.rawValue,
                r.isManual ? "yes" : "no",
                quoted(r.intention),
                quoted(task(r.taskID)?.name ?? ""),
                iso.string(from: r.start),
                iso.string(from: r.end),
                String(format: "%.1f", Double(r.plannedSeconds) / 60),
                String(r.extensions),
                String(format: "%.1f", Double(r.extensionSeconds) / 60),
                String(format: "%.1f", Double(r.activeSeconds) / 60),
                r.completed ? "yes" : "no",
                r.countsInStats ? "yes" : "no",
                quoted(r.note),
                quoted(r.problemID ?? ""),
                quoted(r.problemOutcome?.rawValue ?? ""),
            ]
            lines.append(fields.joined(separator: ","))
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reads a FocusFlow JSON file (an export or a backup) and adds what's missing.
    func importFile(_ url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        guard let p = Store.decode(data) else {
            throw NSError(domain: "FocusFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file isn't a FocusFlow data file."])
        }
        return merge(p)
    }

    // MARK: - Earlier "番茄钟" build

    private struct LegacySession: Codable {
        let id: UUID
        let start: Date
        let end: Date
        let seconds: Int
        let extensions: Int
    }

    private func importLegacyIfNeeded() {
        let key = "importedLegacyTomato"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Tomato/sessions.json")
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let old = try? decoder.decode([LegacySession].self, from: data), !old.isEmpty else { return }
        let converted = old.map {
            SessionRecord(id: $0.id, phase: .focus, intention: "", start: $0.start, end: $0.end,
                          plannedSeconds: $0.seconds, extensionSeconds: 0, extensions: $0.extensions,
                          activeSeconds: $0.seconds, completed: true)
        }
        merge(Payload(sessions: converted))
    }
}

// MARK: - LeetCode (same file, backups and export as existing focus records)
extension Store {
    @discardableResult
    func importProblems(_ preview: LCImportPreview) -> String? {
        guard !preview.problems.isEmpty, !preview.name.isEmpty else { return nil }
        for p in preview.problems {
            if let i = leetcode.problems.firstIndex(where: { $0.id == p.id }) {
                if leetcode.problems[i].number == nil { leetcode.problems[i].number = p.number }
            } else { leetcode.problems.append(p) }
        }
        let id = preview.listID ?? UUID().uuidString
        if let index = leetcode.lists.firstIndex(where: { $0.id == id }) {
            for p in preview.problems where !leetcode.lists[index].problemIDs.contains(p.id) {
                leetcode.lists[index].problemIDs.append(p.id)
            }
        } else {
            leetcode.lists.append(LCList(id: id, name: preview.name, source: preview.source,
                                        importedAt: Date(), problemIDs: preview.problems.map(\.id)))
        }
        save()
        return id
    }

    private func seedCommonListsIfNeeded() {
        guard leetcode.commonListsSeeded != true, problem == nil else { return }
        for p in LCCatalog.problems where leetcode.problem(p.id) == nil { leetcode.problems.append(p) }
        for common in LCCatalog.lists where !leetcode.lists.contains(where: { $0.id == common.id }) {
            leetcode.lists.append(LCList(id: common.id, name: common.name, source: LCCatalog.source,
                                        importedAt: Date(), problemIDs: common.problemIDs))
        }
        leetcode.commonListsSeeded = true
        save()
    }

    func setProblemNotes(_ id: String, _ text: String) {
        guard leetcode.problem(id) != nil else { return }
        leetcode.progress[id, default: LCProgress()].notes = text
        noteSave?.cancel()
        noteSave = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
            self?.save()
        }
    }

    func flushProblemNotes() {
        noteSave?.cancel()
        noteSave = nil
        save()
    }

    func generateProblems(topic: String, count: Int, now: Date = Date()) {
        let key = PlanLogic.key(now)
        leetcode.topic = topic
        leetcode.targetCount = count
        leetcode.queues[key] = LCDailyQueue(date: key, topic: topic, targetCount: count,
                                          problemIDs: leetcode.recommendations(topic: topic, count: count), generatedAt: now)
        save()
    }

    func addProblemToToday(_ id: String, now: Date = Date()) {
        guard leetcode.problem(id) != nil else { return }
        let key = PlanLogic.key(now)
        var queue = leetcode.queues[key] ?? LCDailyQueue(date: key, topic: "Any topic", targetCount: 1,
                                                        problemIDs: [], generatedAt: now)
        guard !queue.problemIDs.contains(id) else { return }
        queue.problemIDs.append(id)
        queue.targetCount = max(queue.targetCount, queue.problemIDs.count)
        leetcode.queues[key] = queue
        save()
    }

    func recordProblemResult(_ id: String, outcome: LCOutcome, sessionID: UUID? = nil, now: Date = Date()) {
        guard leetcode.problem(id) != nil else { return }
        // A checkpoint, extended timer or repeated sheet action must never duplicate the attempt.
        if let sessionID = sessionID {
            guard let index = records.firstIndex(where: { $0.id == sessionID && $0.problemID == id }) else { return }
            if let existing = leetcode.attempts.first(where: { $0.sessionID == sessionID }) {
                records[index].problemOutcome = existing.outcome
                save()
                return
            }
            records[index].problemOutcome = outcome
        }
        leetcode.attempts.append(LCAttempt(problemID: id, timestamp: now, outcome: outcome, sessionID: sessionID))
        var progress = leetcode.progressFor(id)
        progress.lastAttemptAt = now
        // A later failed practice does not erase a previous successful solve.
        if outcome != .skipped && (!progress.outcome.solved || outcome == .yes) { progress.outcome = outcome }
        if outcome.solved && progress.nextReviewDate == nil && progress.reviewStage == 0 {
            progress.nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))
        }
        leetcode.progress[id] = progress
        save()
    }

    func setProblemCompleted(_ id: String, completed: Bool) {
        guard leetcode.problem(id) != nil, leetcode.progressFor(id).outcome.solved != completed else { return }
        if completed {
            recordProblemResult(id, outcome: .yes)
        } else {
            // Undo the latest completion only; earlier practice dates remain intact.
            if let index = leetcode.attempts.indices.filter({
                leetcode.attempts[$0].problemID == id && leetcode.attempts[$0].outcome.solved
                    && leetcode.attempts[$0].completionUndone != true
            }).max(by: { leetcode.attempts[$0].timestamp < leetcode.attempts[$1].timestamp }) {
                leetcode.attempts[index].completionUndone = true
            }
            leetcode.progress[id, default: LCProgress()].outcome = .notYet
            leetcode.progress[id, default: LCProgress()].nextReviewDate = nil
            leetcode.progress[id, default: LCProgress()].reviewStage = 0
            save()
        }
    }

    func reviewProblem(_ id: String, remembered: Bool, now: Date = Date(), calendar: Calendar = .current) {
        guard leetcode.due(on: now, calendar: calendar).contains(where: { $0.id == id }) else { return }
        var progress = leetcode.progressFor(id)
        let intervals = [1, 3, 7, 14, 30]
        progress.reviewStage = remembered ? min(progress.reviewStage + 1, intervals.count) : 0
        progress.nextReviewDate = progress.reviewStage < intervals.count
            ? calendar.date(byAdding: .day, value: intervals[progress.reviewStage], to: calendar.startOfDay(for: now)) : nil
        leetcode.progress[id] = progress
        leetcode.reviews.append(LCReview(problemID: id, timestamp: now, remembered: remembered))
        save()
    }
}

// MARK: - Applications
extension Store {
    func setApplicationCountOnlyMode(_ enabled: Bool) {
        applications.countOnlyMode = enabled
        save()
    }

    @discardableResult
    func setDailyApplicationCount(_ count: Int, on day: Date) -> String? {
        guard count >= 0, Calendar.current.startOfDay(for: day) <= Calendar.current.startOfDay(for: Date()) else {
            return "Enter a non-negative whole number for today or a past date."
        }
        let detailed = applications.sent(on: day).count
        guard count >= detailed else { return "This day already has \(detailed) detailed applications. The total must include them." }
        var counts = applications.dailyCounts ?? [:]
        counts[ApplicationDay.key(day)] = count
        applications.dailyCounts = counts
        save()
        return nil
    }

    func incrementDailyApplicationCount(_ amount: Int, on day: Date = Date()) {
        let (count, overflow) = applications.total(on: day).addingReportingOverflow(amount)
        guard !overflow else { return }
        _ = setDailyApplicationCount(count, on: day)
    }

    func saveApplication(_ value: JobApplication) -> String? {
        var value = value
        value.company = value.company.trimmingCharacters(in: .whitespacesAndNewlines)
        value.role = value.role.trimmingCharacters(in: .whitespacesAndNewlines)
        value.url = value.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.company.isEmpty, !value.role.isEmpty else { return "Company and role are required." }
        guard let date = ApplicationDay.date(value.appliedOn), date <= Calendar.current.startOfDay(for: Date()) else {
            return "Choose a valid application date up to today."
        }
        guard value.stages.filter({ $0.kind != .applied }).allSatisfy({ $0.occurredAt >= date && $0.occurredAt <= Date() }) else {
            return "A stage occurs before this application date. Edit that stage first."
        }
        if let initial = value.stages.firstIndex(where: { $0.kind == .applied }) {
            value.stages[initial].occurredAt = date
        } else { value.stages.append(ApplicationStage(kind: .applied, occurredAt: date)) }
        value.updatedAt = Date()
        if let i = applications.applications.firstIndex(where: { $0.id == value.id }) { applications.applications[i] = value }
        else { applications.applications.append(value) }
        save()
        return nil
    }

    func deleteApplication(_ id: UUID) {
        applications.applications.removeAll { $0.id == id }
        deadlines.removeAll { $0.applicationLink?.applicationID == id }
        save()
    }

    func saveApplicationStage(_ stage: ApplicationStage, applicationID: UUID) -> String? {
        guard let i = applications.applications.firstIndex(where: { $0.id == applicationID }),
              let start = ApplicationDay.date(applications.applications[i].appliedOn) else { return "Application no longer exists." }
        guard stage.kind != .applied else { return "Edit the application date to change the Applied stage." }
        guard stage.occurredAt >= start && stage.occurredAt <= Date() else { return "Stage date must be between the application date and now." }
        var stage = stage
        stage.customLabel = stage.customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stage.kind != .other || !stage.customLabel.isEmpty else { return "Enter a stage name." }
        if let j = applications.applications[i].stages.firstIndex(where: { $0.id == stage.id }) {
            applications.applications[i].stages[j] = stage
        } else { applications.applications[i].stages.append(stage) }
        applications.applications[i].updatedAt = Date()
        save()
        return nil
    }

    func deleteApplicationStage(_ id: UUID, applicationID: UUID) {
        guard let i = applications.applications.firstIndex(where: { $0.id == applicationID }) else { return }
        guard applications.applications[i].stages.contains(where: { $0.id == id && $0.kind != .applied }) else { return }
        applications.applications[i].stages.removeAll { $0.id == id }
        applications.applications[i].updatedAt = Date()
        for j in deadlines.indices where deadlines[j].applicationLink?.applicationID == applicationID && deadlines[j].applicationLink?.stageID == id {
            deadlines[j].applicationLink?.stageID = nil
        }
        save()
    }

    func setApplicationGoal(_ target: Int?, now: Date = Date()) {
        guard target == nil || target! > 0 else { return }
        let day = ApplicationDay.key(now)
        if let i = applications.dailyGoalChanges.firstIndex(where: { $0.effectiveOn == day }) {
            applications.dailyGoalChanges[i].target = target
            applications.dailyGoalChanges[i].updatedAt = now
        } else { applications.dailyGoalChanges.append(DailyApplicationGoalChange(effectiveOn: day, target: target, updatedAt: now)) }
        save()
    }

    private func repairApplicationLinks() {
        for i in deadlines.indices {
            guard let link = deadlines[i].applicationLink else { continue }
            guard let application = applications.application(link.applicationID) else { deadlines[i].applicationLink = nil; continue }
            if let stageID = link.stageID, !application.stages.contains(where: { $0.id == stageID }) {
                deadlines[i].applicationLink?.stageID = nil
            }
        }
    }
}

// MARK: - Interview Preparation (counts never carry session duration)
extension Store {
    func interviewSummary(taskID: UUID? = nil, sessions: [SessionRecord]? = nil) -> InterviewSummary {
        let ids = taskID.map { Set([$0]) } ?? Set(tasks.filter(\.isInterviewPreparation).map(\.id))
        let linked = (sessions ?? records).filter { $0.taskID.map(ids.contains) == true }
        let included = Set(linked.filter { $0.countsInStats && $0.phase == .focus }.map(\.id))
        return InterviewSummary(entries: interviewEntries.filter {
            ids.contains($0.taskID) && ($0.sessionID == nil || included.contains($0.sessionID!))
        }, sessions: linked)
    }

    @discardableResult
    func saveInterviewEntry(_ entry: InterviewEntry) -> Bool {
        guard entry.quantity > 0, task(entry.taskID) != nil else { return false }
        var entry = entry
        if let sessionID = entry.sessionID {
            guard let session = records.first(where: { $0.id == sessionID && $0.phase == .focus && $0.taskID == entry.taskID }) else { return false }
            entry.occurredAt = session.start
        }
        entry.notes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.updatedAt = Date()
        if let index = interviewEntries.firstIndex(where: { $0.id == entry.id }) { interviewEntries[index] = entry }
        else { interviewEntries.append(entry) }
        save()
        return true
    }

    func deleteInterviewEntry(_ id: UUID) {
        interviewEntries.removeAll { $0.id == id }
        save()
    }

    func addInterviewItems(_ items: [InterviewDraft], to session: SessionRecord, source: InterviewEntry.Source) {
        guard task(session.taskID)?.isInterviewPreparation == true, let taskID = session.taskID else { return }
        for item in items where item.valid && item.hasOutput {
            guard let category = item.category else { continue }
            saveInterviewEntry(InterviewEntry(taskID: taskID, sessionID: session.id, occurredAt: session.start,
                category: category, quantity: item.quantity, notes: item.notes, source: source))
        }
    }

    private func repairInterviewLinks() {
        let taskIDs = Set(tasks.map(\.id))
        let sessions = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        interviewEntries = interviewEntries.compactMap { entry in
            guard taskIDs.contains(entry.taskID), entry.quantity > 0 else { return nil }
            var entry = entry
            if let id = entry.sessionID {
                guard let session = sessions[id], session.phase == .focus, let taskID = session.taskID, taskIDs.contains(taskID) else { return nil }
                entry.taskID = taskID
                entry.occurredAt = session.start
            }
            return entry
        }
    }
}
