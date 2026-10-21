import Foundation

enum LCDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy", medium = "Medium", hard = "Hard", unknown = "Unknown"
    var id: String { rawValue }
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 3 }
}

enum LCOutcome: String, Codable, CaseIterable, Identifiable {
    case yes, hints, notYet = "not-yet", skipped
    var id: String { rawValue }
    var title: String {
        switch self {
        case .yes: return "Yes"
        case .hints: return "With hints"
        case .notYet: return "Not yet"
        case .skipped: return "Skip"
        }
    }
    var status: String {
        switch self {
        case .yes: return "Solved"
        case .hints: return "Solved with hints"
        case .notYet: return "Attempted"
        case .skipped: return "Not started"
        }
    }
    var solved: Bool { self == .yes || self == .hints }
}

struct LCProblem: Codable, Identifiable, Hashable {
    /// Canonical slug, shared across lists and both LeetCode domains.
    var id: String
    var number: String?
    var title: String
    var difficulty: LCDifficulty
    var topics: [String]
    var url: URL { URL(string: "https://leetcode.com/problems/\(id)/")! }
    var displayTitle: String { number.map { "\($0). \(title)" } ?? title }
}

struct LCList: Codable, Identifiable {
    var id: String
    var name: String
    var source: String
    var importedAt: Date
    /// An ordered many-to-many relationship; progress lives on the problem.
    var problemIDs: [String]
}

struct LCProgress: Codable {
    var outcome: LCOutcome = .skipped
    var notes = ""
    var lastAttemptAt: Date?
    var nextReviewDate: Date?
    var reviewStage = 0
}

struct LCAttempt: Codable, Identifiable {
    var id = UUID()
    var problemID: String
    var timestamp: Date
    var outcome: LCOutcome
    var sessionID: UUID?
    /// Keeps an accidentally checked completion in history without counting it.
    var completionUndone: Bool? = nil
}

struct LCReview: Codable, Identifiable {
    var id = UUID()
    var problemID: String
    var timestamp: Date
    var remembered: Bool
}

struct LCDailyQueue: Codable {
    var date: String
    var topic: String
    var targetCount: Int
    var problemIDs: [String]
    var generatedAt: Date
}

struct LCState: Codable {
    var problems: [LCProblem] = []
    var lists: [LCList] = []
    var progress: [String: LCProgress] = [:]
    var attempts: [LCAttempt] = []
    var reviews: [LCReview] = []
    var queues: [String: LCDailyQueue] = [:]
    var topic = "Any topic"
    var targetCount = 3
    var commonListsSeeded: Bool? = nil

    func problem(_ id: String?) -> LCProblem? { problems.first { $0.id == id } }
    func progressFor(_ id: String) -> LCProgress { progress[id] ?? LCProgress() }
    func due(on date: Date = Date(), calendar: Calendar = .current) -> [LCProblem] {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return problems.filter { p in
            guard let due = progress[p.id]?.nextReviewDate else { return false }
            return due < tomorrow
        }.sorted {
            let a = progress[$0.id]!.nextReviewDate!, b = progress[$1.id]!.nextReviewDate!
            return a == b ? $0.id < $1.id : a < b
        }
    }
    var topics: [String] { Array(Set((LCCatalog.problems + problems).flatMap(\.topics))).sorted() }

    func recommendations(topic: String, count: Int) -> [String] {
        var seen = Set<String>()
        let ordered = lists.flatMap(\.problemIDs).filter { seen.insert($0).inserted }
        let positions = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1, $0) })
        return Array(ordered.compactMap { problem($0) }.filter {
            !progressFor($0.id).outcome.solved && (topic == "Any topic" || $0.topics.contains(topic))
        }.sorted {
            let a = progressFor($0.id).lastAttemptAt, b = progressFor($1.id).lastAttemptAt
            // Never attempted first, then least recently attempted, difficulty and source order.
            if a != b { return (a ?? .distantPast) < (b ?? .distantPast) }
            if $0.difficulty.rank != $1.difficulty.rank { return $0.difficulty.rank < $1.difficulty.rank }
            return positions[$0.id, default: 0] < positions[$1.id, default: 0]
        }.prefix(max(0, count)).map(\.id))
    }

    func completedProblemIDs(on day: Date, granularity: Calendar.Component, records: [SessionRecord], calendar: Calendar = .current) -> Set<String> {
        let eligible = Set(records.filter { $0.phase == .focus && $0.countsInStats }.map(\.id))
        return Set(attempts.filter {
            $0.outcome.solved && $0.completionUndone != true && calendar.isDate($0.timestamp, equalTo: day, toGranularity: granularity)
                && ($0.sessionID == nil || eligible.contains($0.sessionID!))
        }.map(\.problemID))
    }

    /// One practiced problem per local date/period, preferring a successful attempt.
    func practicedProblems(on day: Date, granularity: Calendar.Component, records: [SessionRecord], calendar: Calendar = .current) -> [LCAttempt] {
        let eligible = Set(records.filter { $0.phase == .focus && $0.countsInStats }.map(\.id))
        let matching = attempts.filter {
            $0.outcome != .skipped && $0.completionUndone != true
                && calendar.isDate($0.timestamp, equalTo: day, toGranularity: granularity)
                && ($0.sessionID == nil || eligible.contains($0.sessionID!))
        }.sorted { $0.timestamp < $1.timestamp }
        var byProblem: [String: LCAttempt] = [:]
        for attempt in matching {
            if byProblem[attempt.problemID]?.outcome.solved != true || attempt.outcome.solved {
                byProblem[attempt.problemID] = attempt
            }
        }
        return byProblem.values.sorted {
            $0.timestamp == $1.timestamp ? $0.problemID < $1.problemID : $0.timestamp < $1.timestamp
        }
    }

    mutating func merge(_ other: LCState) {
        for p in other.problems where problem(p.id) == nil { problems.append(p) }
        for list in other.lists {
            if let i = lists.firstIndex(where: { $0.id == list.id }) {
                for id in list.problemIDs where !lists[i].problemIDs.contains(id) { lists[i].problemIDs.append(id) }
            } else { lists.append(list) }
        }
        for (id, value) in other.progress where progress[id] == nil { progress[id] = value }
        for a in other.attempts {
            if let i = attempts.firstIndex(where: { $0.id == a.id }) {
                if a.completionUndone == true { attempts[i].completionUndone = true }
            } else { attempts.append(a) }
        }
        var reviewIDs = Set(reviews.map(\.id))
        for r in other.reviews where reviewIDs.insert(r.id).inserted { reviews.append(r) }
        for (day, queue) in other.queues where queues[day] == nil { queues[day] = queue }
    }
}

struct LCImportPreview {
    var name: String
    var source: String
    var listID: String?
    var problems: [LCProblem]
    var duplicates: Int
    var rejected: [String]
}

struct LCCommonList: Identifiable {
    var id: String
    var name: String
    var url: String
    var problemIDs: [String]
}
