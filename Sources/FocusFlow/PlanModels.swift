import Foundation

// MARK: - Plan data

/// A task you want to do for a set number of minutes on chosen weekdays.
struct PlanTask: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var minutes: Int
    var note: String = ""
    /// Calendar weekdays: 1 = Sunday … 7 = Saturday.
    var weekdays: Set<Int>
    var enabled = true
    var icon: String
    var createdAt = Date()
}

/// A stretch of time on one day: what you did, or what you plan to do.
struct TimeBlock: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case activity, rest }

    var id = UUID()
    var start: Date
    var end: Date
    var title: String
    var taskID: UUID?
    var kind: Kind = .activity

    var seconds: Int { max(0, Int(end.timeIntervalSince(start))) }
}

struct Deadline: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case deadline, exam, meeting, call, portfolio, important

        var id: String { rawValue }

        var label: String {
            switch self {
            case .deadline: return "Deadline"
            case .exam: return "Exam"
            case .meeting: return "Meeting"
            case .call: return "Call"
            case .portfolio: return "Portfolio"
            case .important: return "Important"
            }
        }

        var icon: String {
            switch self {
            case .deadline: return "flag.fill"
            case .exam: return "graduationcap.fill"
            case .meeting: return "person.2.fill"
            case .call: return "phone.fill"
            case .portfolio: return "briefcase.fill"
            case .important: return "star.fill"
            }
        }
    }

    var id = UUID()
    /// The day, plus the time when `hasTime` is on.
    var date: Date
    var hasTime: Bool
    var title: String
    var note: String = ""
    var kind: Kind = .deadline
    var done = false
}

// MARK: - Weekdays

enum Weekdays {
    /// Monday first, as in the designs.
    static let order = [2, 3, 4, 5, 6, 7, 1]
    static let workdays: Set<Int> = [2, 3, 4, 5, 6]

    static func short(_ w: Int) -> String {
        ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][max(1, min(7, w))]
    }

    static func letter(_ w: Int) -> String {
        ["", "S", "M", "T", "W", "T", "F", "S"][max(1, min(7, w))]
    }

    static func names(_ set: Set<Int>) -> String {
        if set.count == 7 { return "every day" }
        if set == workdays { return "weekdays" }
        return order.filter { set.contains($0) }.map { short($0) }.joined(separator: ", ")
    }
}

// MARK: - Progress

/// Answers "what's planned on this day and how far along is it".
struct PlanLogic {
    let tasks: [PlanTask]
    let sessions: [SessionRecord]
    let blocks: [TimeBlock]
    let checks: [String: [UUID]]
    let cal = Calendar.current

    static func key(_ d: Date) -> String { Fmt.fileStamp.string(from: d) }

    func dayRange(_ day: Date) -> (start: Date, end: Date) {
        let s = cal.startOfDay(for: day)
        return (s, cal.date(byAdding: .day, value: 1, to: s) ?? s.addingTimeInterval(86_400))
    }

    func tasks(on day: Date) -> [PlanTask] {
        let wd = cal.component(.weekday, from: day)
        let end = dayRange(day).end
        return tasks.filter { $0.enabled && $0.weekdays.contains(wd) && $0.createdAt < end }
    }

    /// Seconds spent on the task that day: linked focus sessions (timer or manual) and
    /// linked time blocks. Overlaps are counted once.
    func progress(_ t: PlanTask, on day: Date) -> Int {
        let r = dayRange(day)
        var spans: [(Date, Date)] = []
        for s in sessions where s.taskID == t.id && s.phase == .focus && s.countsInStats && s.start >= r.start && s.start < r.end {
            let start = max(s.start, s.end.addingTimeInterval(-Double(s.activeSeconds)))
            spans.append((start, s.end))
        }
        for b in blocks where b.taskID == t.id && b.start >= r.start && b.start < r.end {
            spans.append((b.start, b.end))
        }
        spans.sort { $0.0 < $1.0 }
        var total: TimeInterval = 0
        var current: (Date, Date)?
        for sp in spans where sp.1 > sp.0 {
            if let c = current, sp.0 <= c.1 {
                current = (c.0, max(c.1, sp.1))
            } else {
                if let c = current { total += c.1.timeIntervalSince(c.0) }
                current = sp
            }
        }
        if let c = current { total += c.1.timeIntervalSince(c.0) }
        return Int(total)
    }

    func isChecked(_ t: PlanTask, on day: Date) -> Bool {
        checks[PlanLogic.key(day)]?.contains(t.id) == true
    }

    func isDone(_ t: PlanTask, on day: Date) -> Bool {
        isChecked(t, on: day) || progress(t, on: day) >= t.minutes * 60
    }

    func fraction(_ t: PlanTask, on day: Date) -> Double {
        if isChecked(t, on: day) { return 1 }
        return min(1, Double(progress(t, on: day)) / Double(max(1, t.minutes * 60)))
    }

    func summary(on day: Date) -> (done: Int, total: Int) {
        let list = tasks(on: day)
        return (list.filter { isDone($0, on: day) }.count, list.count)
    }

    /// Days in the week of `day` the task is scheduled, and how many of those are done.
    func week(_ t: PlanTask, of day: Date) -> (done: Int, scheduled: Int) {
        guard let w = cal.dateInterval(of: .weekOfYear, for: day) else { return (0, 0) }
        var done = 0, scheduled = 0
        var d = w.start
        for _ in 0..<7 {
            if t.weekdays.contains(cal.component(.weekday, from: d)) {
                scheduled += 1
                if isDone(t, on: d) { done += 1 }
            }
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86_400)
        }
        return (done, scheduled)
    }
}

// MARK: - Bulk add

struct ParsedTask: Identifiable {
    let id = UUID()
    let name: String
    let minutes: Int
    let note: String
}

enum BulkParser {
    /// One task per line: `Name | minutes | optional note`.
    static func parse(_ text: String) -> [ParsedTask] {
        text.components(separatedBy: .newlines).compactMap { raw -> ParsedTask? in
            let line = raw.replacingOccurrences(of: "｜", with: "|").trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let name = parts.first, !name.isEmpty else { return nil }
            var minutes = 30
            if parts.count > 1 {
                let digits = parts[1].filter { $0.isNumber }
                if let m = Int(digits), m > 0 { minutes = min(m, 24 * 60) }
            }
            let note = parts.count > 2 ? parts[2...].joined(separator: " | ") : ""
            return ParsedTask(name: name, minutes: minutes, note: note)
        }
    }
}

enum TaskIcons {
    static let all = [
        "chevron.left.forwardslash.chevron.right", "doc.text", "graduationcap", "person.3", "book",
        "envelope", "pencil", "lightbulb", "dumbbell", "music.note", "paintbrush", "globe", "checklist",
    ]

    static func guess(_ name: String) -> String {
        let n = name.lowercased()
        let rules: [([String], String)] = [
            (["code", "cuda", "leetcode", "program", "debug", "刷题", "代码"], "chevron.left.forwardslash.chevron.right"),
            (["resume", "essay", "write", "doc", "简历", "写"], "doc.text"),
            (["school", "grad", "application", "exam", "申请", "考试"], "graduationcap"),
            (["interview", "meeting", "面试", "会"], "person.3"),
            (["read", "book", "course", "study", "lecture", "读", "课", "学"], "book"),
            (["mail", "email", "邮件"], "envelope"),
            (["gym", "workout", "run", "exercise", "健身", "跑步"], "dumbbell"),
            (["music", "piano", "guitar", "练琴"], "music.note"),
            (["design", "draw", "paint", "画"], "paintbrush"),
            (["english", "language", "japanese", "korean", "语言", "英语"], "globe"),
        ]
        for (keys, icon) in rules where keys.contains(where: { n.contains($0) }) {
            return icon
        }
        return "checklist"
    }
}
