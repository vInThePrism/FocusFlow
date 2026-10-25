import Foundation

enum InterviewCategory: String, Codable, CaseIterable, Identifiable {
    case codingQuestions, projectBQs, projectReviews, generalQuestions, mockInterviews
    var id: String { rawValue }
    var title: String {
        switch self {
        case .codingQuestions: return "Coding Questions"
        case .projectBQs: return "Project BQs"
        case .projectReviews: return "Project Reviews"
        case .generalQuestions: return "General Questions"
        case .mockInterviews: return "Mock Interviews"
        }
    }
    var unit: String {
        switch self {
        case .projectReviews: return "passes"
        case .mockInterviews: return "sessions"
        default: return "questions"
        }
    }
    static let preferenceKey = "lastInterviewCategory"
    static var lastSelected: InterviewCategory? {
        UserDefaults.standard.string(forKey: preferenceKey).flatMap(Self.init(rawValue:))
    }
}

struct InterviewEntry: Codable, Identifiable, Equatable {
    enum Source: String, Codable { case focusCompletion, manual }
    var id = UUID()
    var taskID: UUID
    var sessionID: UUID?
    var occurredAt: Date
    var category: InterviewCategory
    var quantity: Int
    var notes = ""
    var source: Source
    var createdAt = Date()
    var updatedAt = Date()
}

/// A blank row is optional; selecting a category explicitly enables it.
struct InterviewDraft: Identifiable {
    var id = UUID()
    var category: InterviewCategory? = InterviewCategory.lastSelected
    var quantity = 1
    var notes = ""
    var valid: Bool { quantity >= 0 }
    var hasOutput: Bool { category != nil && quantity > 0 }
}

extension PlanTask {
    var isInterviewPreparation: Bool {
        ["interview preparation", "interview preparing", "面试准备"].contains(
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }
}

struct InterviewSummary {
    let entries: [InterviewEntry]
    let sessions: [SessionRecord]

    func entries(in range: DateInterval) -> [InterviewEntry] {
        entries.filter { $0.quantity > 0 && $0.occurredAt >= range.start && $0.occurredAt < range.end }
    }
    func total(_ category: InterviewCategory, in range: DateInterval) -> Int {
        entries(in: range).filter { $0.category == category }.reduce(0) {
            let (sum, overflow) = $0.addingReportingOverflow($1.quantity)
            return overflow ? Int.max : sum
        }
    }
    func focusSeconds(in range: DateInterval) -> Int {
        sessions.filter { $0.phase == .focus && $0.countsInStats && $0.start >= range.start && $0.start < range.end }
            .reduce(0) { $0 + $1.activeSeconds }
    }
}
