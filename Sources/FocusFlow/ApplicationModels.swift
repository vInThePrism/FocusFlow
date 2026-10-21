import Foundation

// Local days use the same stable key as the rest of FocusFlow.
enum ApplicationDay {
    static func key(_ date: Date) -> String { PlanLogic.key(date) }
    static func date(_ key: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar.current
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        f.isLenient = false
        return f.date(from: key)
    }
}

enum ApplicationStageKind: String, Codable, CaseIterable, Identifiable {
    case applied = "Applied", oa = "OA", phone = "Phone screen", vo = "VO", hr = "HR"
    case offer = "Offer", rejected = "Rejected", withdrawn = "Withdrawn", other = "Other"
    var id: String { rawValue }
}

struct ApplicationStage: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: ApplicationStageKind
    var customLabel = ""
    var occurredAt: Date
    var notes = ""
    var createdAt = Date()
    var label: String { customLabel.isEmpty ? kind.rawValue : "\(kind.rawValue) · \(customLabel)" }
}

struct JobApplication: Codable, Identifiable, Hashable {
    var id = UUID()
    var company: String
    var role: String
    var url = ""
    var appliedOn: String
    var notes = ""
    var createdAt = Date()
    var updatedAt = Date()
    var stages: [ApplicationStage] = []
    var orderedStages: [ApplicationStage] {
        stages.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    var currentKind: ApplicationStageKind { orderedStages.last?.kind ?? .applied }
    var currentLabel: String { orderedStages.last?.label ?? "Applied" }
    var safeURL: URL? {
        guard let link = URL(string: url), ["http", "https"].contains(link.scheme?.lowercased() ?? ""),
              let host = link.host, !host.isEmpty else { return nil }
        return link
    }
}

struct DailyApplicationGoalChange: Codable, Identifiable {
    var id = UUID()
    var effectiveOn: String
    var target: Int?
    var updatedAt = Date()
}

enum ApplicationTaskKind: String, Codable, CaseIterable, Identifiable {
    case oa = "OA", vo = "VO", followUp = "Follow-up", other = "Other"
    var id: String { rawValue }
    var deadlineKind: Deadline.Kind {
        switch self { case .oa: return .exam; case .vo: return .meeting; case .followUp: return .call; case .other: return .important }
    }
}

struct ApplicationTaskLink: Codable, Hashable {
    var applicationID: UUID
    var stageID: UUID?
    var kind: ApplicationTaskKind
}

struct ApplicationState: Codable {
    var applications: [JobApplication] = []
    var dailyGoalChanges: [DailyApplicationGoalChange] = []
    // Optional additions keep existing application backups readable.
    var dailyCounts: [String: Int]? = nil
    var countOnlyMode: Bool? = nil

    /// A manually recorded total includes any detailed records for that day.
    func total(on day: Date) -> Int {
        max(sent(on: day).count, dailyCounts?[ApplicationDay.key(day)] ?? 0)
    }
    func total(in interval: DateInterval) -> Int {
        let days = Set(applications.map(\.appliedOn)).union(dailyCounts?.keys.map { $0 } ?? [])
        return days.reduce(0) { sum, key in
            guard let date = ApplicationDay.date(key), date >= interval.start && date < interval.end else { return sum }
            let (next, overflow) = sum.addingReportingOverflow(total(on: date))
            return overflow ? Int.max : next
        }
    }

    func application(_ id: UUID) -> JobApplication? { applications.first { $0.id == id } }
    func sent(on day: Date) -> [JobApplication] {
        applications.filter { $0.appliedOn == ApplicationDay.key(day) }
    }
    func sent(in interval: DateInterval) -> [JobApplication] {
        applications.filter {
            guard let date = ApplicationDay.date($0.appliedOn) else { return false }
            return date >= interval.start && date < interval.end
        }
    }
    func goal(on day: Date) -> Int? {
        let key = ApplicationDay.key(day)
        return dailyGoalChanges.filter { $0.effectiveOn <= key }.sorted {
            if $0.effectiveOn != $1.effectiveOn { return $0.effectiveOn < $1.effectiveOn }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }.last?.target.flatMap { $0 > 0 ? $0 : nil }
    }
    func goalSummary(in interval: DateInterval, now: Date = Date()) -> (met: Int, days: Int) {
        let cal = Calendar.current
        let end = min(interval.end, cal.startOfDay(for: now))
        var day = cal.startOfDay(for: interval.start)
        var result = (met: 0, days: 0)
        while day < end {
            if let target = goal(on: day) {
                result.days += 1
                if total(on: day) >= target { result.met += 1 }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
    mutating func merge(_ incoming: ApplicationState) {
        if let incomingCounts = incoming.dailyCounts {
            var counts = dailyCounts ?? [:]
            for (day, count) in incomingCounts where counts[day] == nil && count >= 0 && ApplicationDay.date(day) != nil {
                counts[day] = count
            }
            dailyCounts = counts
        }
        if countOnlyMode == nil { countOnlyMode = incoming.countOnlyMode }
        var ids = Set(applications.map(\.id))
        for application in incoming.applications where ids.insert(application.id).inserted { applications.append(application) }
        var goalIDs = Set(dailyGoalChanges.map(\.id))
        var days = Set(dailyGoalChanges.map(\.effectiveOn))
        for goal in incoming.dailyGoalChanges where !goalIDs.contains(goal.id) && !days.contains(goal.effectiveOn) {
            dailyGoalChanges.append(goal)
            goalIDs.insert(goal.id)
            days.insert(goal.effectiveOn)
        }
    }
}
