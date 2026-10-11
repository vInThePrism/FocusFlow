import Foundation
import AppKit

/// Saves every session to a JSON file on this Mac.
///
/// Safety measures:
/// - every write is atomic (written to a temp file, then swapped in), so a crash mid-write can't corrupt the file
/// - the running session is checkpointed every 30 s, so a crash or power cut loses at most 30 s
/// - before the first write of each day the previous file is copied to Backups/ (30 days kept)
/// - an unreadable file is never overwritten: it is copied aside and the newest good backup is restored
@MainActor
final class Store: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []
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
    }

    // MARK: - Reading

    private func prepareFolder() {
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            problem = "Couldn't create the data folder: \(error.localizedDescription)"
        }
    }

    static func decode(_ data: Data) -> [SessionRecord]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let body = try? decoder.decode(FileBody.self, from: data) { return body.sessions }
        if let list = try? decoder.decode([SessionRecord].self, from: data) { return list }
        return nil
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        if let data = try? Data(contentsOf: fileURL), let list = Store.decode(data) {
            records = list.sorted { $0.start < $1.start }
            return
        }
        // The file exists but can't be read. Keep it untouched under another name,
        // then fall back to the newest backup that still reads.
        let damaged = quarantine(fileURL)
        if let found = newestGoodBackup() {
            records = found.records.sorted { $0.start < $1.start }
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

    private func newestGoodBackup() -> (records: [SessionRecord], name: String)? {
        for url in backupFiles() {
            if let data = try? Data(contentsOf: url), let list = Store.decode(data) {
                return (list, url.lastPathComponent)
            }
        }
        return nil
    }

    // MARK: - Writing

    private func encoded(_ list: [SessionRecord]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(FileBody(app: "FocusFlow", version: 1, savedAt: Date(), sessions: list))
    }

    private func save() {
        backupIfNeeded()
        do {
            try encoded(records).write(to: fileURL, options: .atomic)
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

    // MARK: - Changes

    func upsert(_ record: SessionRecord) {
        if let i = records.firstIndex(where: { $0.id == record.id }) {
            records[i] = record
        } else {
            records.append(record)
            records.sort { $0.start < $1.start }
        }
        save()
    }

    func delete(_ id: UUID) {
        guard records.contains(where: { $0.id == id }) else { return }
        records.removeAll { $0.id == id }
        save()
    }

    func rename(_ id: UUID, to text: String) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        records[i].intention = text.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    /// Adds sessions that aren't here yet. Never removes anything.
    @discardableResult
    func merge(_ incoming: [SessionRecord]) -> Int {
        var byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var added = 0
        for r in incoming {
            if let current = byID[r.id] {
                if r.end > current.end { byID[r.id] = r }
            } else {
                byID[r.id] = r
                added += 1
            }
        }
        records = byID.values.sorted { $0.start < $1.start }
        save()
        return added
    }

    /// Records plus the session that's running right now.
    func merged(with live: SessionRecord?) -> [SessionRecord] {
        guard let live = live else { return records }
        var out = records.filter { $0.id != live.id }
        out.append(live)
        return out
    }

    // MARK: - Location, export, import

    /// Copies everything into another folder (for example iCloud Drive) and keeps using it.
    /// The old file stays where it was.
    func moveData(to newFolder: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: newFolder, withIntermediateDirectories: true)
        let target = newFolder.appendingPathComponent("sessions.json")
        var existing: [SessionRecord] = []
        if fm.fileExists(atPath: target.path) {
            if let data = try? Data(contentsOf: target), let list = Store.decode(data) {
                existing = list
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
        try encoded(records).write(to: url, options: .atomic)
    }

    func exportCSV(to url: URL) throws {
        let iso = ISO8601DateFormatter()
        var lines = ["id,type,intention,start,end,planned_min,extensions,extension_min,focused_min,completed"]
        for r in records {
            let intention = "\"" + r.intention.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let fields: [String] = [
                r.id.uuidString,
                r.phase.rawValue,
                intention,
                iso.string(from: r.start),
                iso.string(from: r.end),
                String(format: "%.1f", Double(r.plannedSeconds) / 60),
                String(r.extensions),
                String(format: "%.1f", Double(r.extensionSeconds) / 60),
                String(format: "%.1f", Double(r.activeSeconds) / 60),
                r.completed ? "yes" : "no",
            ]
            lines.append(fields.joined(separator: ","))
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reads a FocusFlow JSON file (an export or a backup) and adds what's missing.
    func importFile(_ url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        guard let list = Store.decode(data) else {
            throw NSError(domain: "FocusFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file isn't a FocusFlow data file."])
        }
        return merge(list)
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
        merge(converted)
    }
}
