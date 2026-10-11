import Foundation

struct DayValue: Identifiable {
    let date: Date
    let focus: Int
    let breaks: Int
    var id: Date { date }
}

struct MonthValue: Identifiable {
    let index: Int
    let date: Date
    let seconds: Int
    var id: Int { index }
}

struct CalendarCell: Identifiable {
    let id: Int
    let date: Date?
    let seconds: Int
}

struct WeekdayValue: Identifiable {
    let id: Int
    let label: String
    let seconds: Int
}

struct FocusWindow {
    let startHour: Int
    let percentMore: Int?
}

enum StatsScope: String, CaseIterable, Identifiable {
    case day = "Day", month = "Month", year = "Year"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .day: return "smallcircle.filled.circle"
        case .month: return "calendar"
        case .year: return "chart.bar"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .month: return .month
        case .year: return .year
        }
    }

    var compareLabel: String {
        switch self {
        case .day: return "vs. last week"
        case .month: return "vs. last month"
        case .year: return "vs. last year"
        }
    }

    var goalWord: String {
        switch self {
        case .day: return "weekly"
        case .month: return "monthly"
        case .year: return "yearly"
        }
    }
}

/// Read-only calculations over a list of sessions.
struct Analytics {
    let records: [SessionRecord]
    let cal = Calendar.current
    private let focusByDay: [Date: Int]
    private let breakByDay: [Date: Int]

    /// Records switched out of statistics are ignored here.
    init(records all: [SessionRecord]) {
        let records = all.filter { $0.countsInStats }
        self.records = records
        let c = Calendar.current
        var f: [Date: Int] = [:]
        var b: [Date: Int] = [:]
        for r in records {
            let d = c.startOfDay(for: r.start)
            if r.phase == .focus {
                f[d, default: 0] += r.activeSeconds
            } else {
                b[d, default: 0] += r.activeSeconds
            }
        }
        focusByDay = f
        breakByDay = b
    }

    // MARK: Periods

    func period(_ scope: StatsScope, _ anchor: Date) -> DateInterval {
        cal.dateInterval(of: scope.component, for: anchor) ?? DateInterval(start: anchor, duration: 86_400)
    }

    func previousPeriod(_ scope: StatsScope, _ anchor: Date) -> DateInterval {
        let shifted: Date
        switch scope {
        case .day: shifted = cal.date(byAdding: .day, value: -7, to: anchor) ?? anchor
        case .month: shifted = cal.date(byAdding: .month, value: -1, to: anchor) ?? anchor
        case .year: shifted = cal.date(byAdding: .year, value: -1, to: anchor) ?? anchor
        }
        return period(scope, shifted)
    }

    /// The range the goal donut measures: the week for Day view, otherwise the period itself.
    func goalPeriod(_ scope: StatsScope, _ anchor: Date) -> DateInterval {
        if scope == .day {
            return cal.dateInterval(of: .weekOfYear, for: anchor) ?? period(.day, anchor)
        }
        return period(scope, anchor)
    }

    /// Where "Best day" looks: the month for Day/Month view, the year for Year view.
    func bestDayPeriod(_ scope: StatsScope, _ anchor: Date) -> DateInterval {
        scope == .year ? period(.year, anchor) : period(.month, anchor)
    }

    /// Where "strongest focus window" looks.
    func windowPeriod(_ scope: StatsScope, _ anchor: Date) -> DateInterval {
        if scope == .day {
            let end = period(.day, anchor).end
            let start = cal.date(byAdding: .day, value: -30, to: end) ?? end
            return DateInterval(start: start, end: end)
        }
        return period(scope, anchor)
    }

    // MARK: Totals

    func records(in i: DateInterval) -> [SessionRecord] {
        records.filter { $0.start >= i.start && $0.start < i.end }
    }

    func focusSeconds(_ i: DateInterval) -> Int {
        days(in: i).reduce(0) { $0 + dayFocus($1) }
    }

    func completedCount(_ i: DateInterval) -> Int {
        records(in: i).filter { $0.phase == .focus && $0.completed }.count
    }

    func dayFocus(_ d: Date) -> Int { focusByDay[cal.startOfDay(for: d)] ?? 0 }
    func dayBreak(_ d: Date) -> Int { breakByDay[cal.startOfDay(for: d)] ?? 0 }

    func days(in i: DateInterval) -> [Date] {
        var out: [Date] = []
        var d = cal.startOfDay(for: i.start)
        while d < i.end {
            out.append(d)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }

    func dailyValues(_ i: DateInterval) -> [DayValue] {
        days(in: i).map { DayValue(date: $0, focus: dayFocus($0), breaks: dayBreak($0)) }
    }

    func lastDays(_ n: Int, endingAt date: Date) -> [DayValue] {
        let end = cal.startOfDay(for: date)
        return (0..<n).reversed().compactMap { (offset: Int) -> DayValue? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return DayValue(date: d, focus: dayFocus(d), breaks: dayBreak(d))
        }
    }

    /// Consecutive days with at least a minute of focus, counting back from `date`.
    /// If `date` itself has nothing yet, the streak is counted from the day before.
    func streak(at date: Date) -> Int {
        var day = cal.startOfDay(for: date)
        if dayFocus(day) < 60 {
            guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var count = 0
        while dayFocus(day) >= 60 {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    func bestDay(in i: DateInterval) -> DayValue? {
        dailyValues(i).filter { $0.focus > 0 }.max { $0.focus < $1.focus }
    }

    func monthValues(year: Date) -> [MonthValue] {
        let y = period(.year, year)
        return (0..<12).compactMap { (m: Int) -> MonthValue? in
            guard let d = cal.date(byAdding: .month, value: m, to: y.start),
                  let mi = cal.dateInterval(of: .month, for: d) else { return nil }
            return MonthValue(index: m, date: d, seconds: focusSeconds(mi))
        }
    }

    /// Average focus per weekday, counting only days that have already happened.
    func weekdayAverages(_ i: DateInterval) -> [WeekdayValue] {
        var sums = Array(repeating: 0, count: 7)
        var counts = Array(repeating: 0, count: 7)
        let now = Date()
        for d in days(in: i) where d <= now {
            let w = cal.component(.weekday, from: d) - 1
            sums[w] += dayFocus(d)
            counts[w] += 1
        }
        let symbols = Fmt.dayShort.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdayOrder().map { w in
            WeekdayValue(id: w, label: symbols[w], seconds: counts[w] > 0 ? sums[w] / counts[w] : 0)
        }
    }

    /// Weekday indexes (0 = Sunday) in the order the user's calendar starts the week.
    func weekdayOrder() -> [Int] {
        let first = cal.firstWeekday - 1
        return (0..<7).map { ($0 + first) % 7 }
    }

    func monthGrid(_ month: Date) -> [CalendarCell] {
        guard let m = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: m.start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [CalendarCell] = []
        var idx = 0
        for _ in 0..<leading {
            cells.append(CalendarCell(id: idx, date: nil, seconds: 0))
            idx += 1
        }
        for d in days(in: m) {
            cells.append(CalendarCell(id: idx, date: d, seconds: dayFocus(d)))
            idx += 1
        }
        while cells.count % 7 != 0 {
            cells.append(CalendarCell(id: idx, date: nil, seconds: 0))
            idx += 1
        }
        return cells
    }

    // MARK: Hours

    /// Focus seconds that fell into each hour of the day across the range.
    func hourly(_ i: DateInterval) -> [Double] {
        var bins = Array(repeating: 0.0, count: 24)
        for r in records(in: i) where r.phase == .focus && r.activeSeconds > 0 {
            let span = max(r.end.timeIntervalSince(r.start), 1)
            let rate = min(1, Double(r.activeSeconds) / span)
            var t = r.start
            var guardCount = 0
            while t < r.end && guardCount < 48 {
                guardCount += 1
                let hourEnd = cal.dateInterval(of: .hour, for: t)?.end ?? t.addingTimeInterval(3600)
                let next = min(r.end, hourEnd)
                if next <= t { break }
                bins[cal.component(.hour, from: t)] += next.timeIntervalSince(t) * rate
                t = next
            }
        }
        return bins
    }

    func strongestWindow(_ i: DateInterval) -> FocusWindow? {
        let bins = hourly(i)
        let total = bins.reduce(0, +)
        guard total >= 1800 else { return nil }
        var best = 0
        var bestSum = -1.0
        for h in 0..<23 {
            let s = bins[h] + bins[h + 1]
            if s > bestSum {
                bestSum = s
                best = h
            }
        }
        let others = bins.enumerated()
            .filter { $0.offset != best && $0.offset != best + 1 && $0.element > 0 }
            .map { $0.element }
        guard !others.isEmpty else { return FocusWindow(startHour: best, percentMore: nil) }
        let outRate = others.reduce(0, +) / Double(others.count)
        let inRate = bestSum / 2
        guard outRate > 0 else { return FocusWindow(startHour: best, percentMore: nil) }
        return FocusWindow(startHour: best, percentMore: Int(((inRate / outRate) - 1) * 100))
    }
}

/// What the "Today" widgets need.
struct TodaySummary {
    let records: [SessionRecord]

    init(all: [SessionRecord], day: Date = Date()) {
        let c = Calendar.current
        records = all.filter { $0.countsInStats && c.isDate($0.start, inSameDayAs: day) }.sorted { $0.start < $1.start }
    }

    var completed: Int { records.filter { $0.phase == .focus && $0.completed }.count }
    var focusSeconds: Int { records.filter { $0.phase == .focus }.reduce(0) { $0 + $1.activeSeconds } }
}

/// Rounds an axis maximum up to a friendly number.
func niceCeil(_ value: Double) -> Int {
    guard value > 0 else { return 1 }
    let steps: [Double] = [1, 2, 3, 4, 5, 6, 8, 10]
    let magnitude = pow(10, floor(log10(value)))
    for s in steps where s * magnitude >= value {
        return Int(s * magnitude)
    }
    return Int(10 * magnitude)
}
