import SwiftUI

/// "Calendar + DDL": deadlines and daily plan completion in one view.
struct CalendarScreen: View {
    enum Mode: String, CaseIterable { case month = "Month", week = "Week", list = "List" }

    @EnvironmentObject var store: Store
    @State private var month = Date()
    @State private var selected = Date()
    @State private var mode: Mode = .month
    @State private var sheet: DeadlineSheet?
    private let cal = Calendar.current

    var body: some View {
        let logic = PlanLogic(tasks: store.tasks, sessions: store.records, blocks: store.blocks, checks: store.checks)
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 14) {
                header
                Group {
                    switch mode {
                    case .month:
                        MonthGrid(month: month, selected: $selected, logic: logic, tall: false)
                    case .week:
                        MonthGrid(month: month, selected: $selected, logic: logic, tall: true)
                    case .list:
                        DeadlineList(from: cal.dateInterval(of: .month, for: month)?.start ?? month,
                                     onEdit: { d in sheet = DeadlineSheet(deadline: d, isNew: false) })
                    }
                }
                .frame(maxHeight: .infinity)
                legend
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(spacing: 14) {
                    DayNavigator(day: $selected)
                        .padding(.horizontal, 4)
                    DeadlinesCard(day: selected,
                                  onAdd: { sheet = DeadlineSheet(deadline: newDeadline(), isNew: true) },
                                  onEdit: { d in sheet = DeadlineSheet(deadline: d, isNew: false) })
                    DailyGoalsCard(day: selected, logic: logic)
                    CompletionSummaryCard(day: selected, logic: logic)
                }
                .padding(.vertical, 2)
            }
            .frame(width: 330)
        }
        .padding(EdgeInsets(top: 24, leading: 18, bottom: 20, trailing: 20))
        .onChange(of: selected) { d in
            if !cal.isDate(d, equalTo: month, toGranularity: .month) { month = d }
        }
        .sheet(item: $sheet) { s in
            DeadlineEditor(deadline: s.deadline, isNew: s.isNew).environmentObject(store)
        }
    }

    private func newDeadline() -> Deadline {
        let end = cal.date(bySettingHour: 23, minute: 59, second: 0, of: selected) ?? selected
        return Deadline(date: end, hasTime: true, title: "")
    }

    private var header: some View {
        HStack(spacing: 14) {
            shift(-1, "chevron.left")
            Text(Fmt.monthLong.string(from: month))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Palette.ink)
                .frame(minWidth: 190)
            shift(1, "chevron.right")
            Button("Today") {
                month = Date()
                selected = Date()
            }
            .buttonStyle(SmallButtonStyle())
            Spacer()
            CapsuleTabs(items: Mode.allCases, selection: $mode, title: { $0.rawValue }, horizontalPadding: 18)
            MoreMenu()
        }
    }

    private func shift(_ delta: Int, _ icon: String) -> some View {
        Button {
            let unit: Calendar.Component = mode == .week ? .weekOfYear : .month
            if mode == .week {
                selected = cal.date(byAdding: .weekOfYear, value: delta, to: selected) ?? selected
            } else if let m = cal.date(byAdding: unit, value: delta, to: month) {
                month = m
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Palette.accentText)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 28) {
            legendItem(AnyView(CompletionRing(fraction: 1, size: 18, lineWidth: 3.5)),
                       "Study time", "Full ring = daily study target reached")
            legendItem(AnyView(HStack(spacing: 3) {
                Circle().fill(Palette.red).frame(width: 8, height: 8)
                Circle().fill(Palette.salmon.opacity(0.7)).frame(width: 8, height: 8)
            }), "Focus sessions", "Manual log · timer")
            legendItem(AnyView(Image(systemName: "flag.fill").foregroundColor(Palette.accentText)),
                       "Deadline / Important", "Upcoming or due date")
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.stroke))
    }

    private func legendItem(_ mark: AnyView, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 10) {
            mark
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(Palette.ink)
                Text(subtitle).font(.system(size: 10)).foregroundColor(Palette.muted)
            }
        }
    }
}

// MARK: - Grid

struct MonthGrid: View {
    @EnvironmentObject var store: Store
    let month: Date
    @Binding var selected: Date
    let logic: PlanLogic
    /// Week mode: only the selected week, with taller cells.
    let tall: Bool
    private let cal = Calendar.current

    private var weeks: [[Date]] {
        if tall {
            let start = cal.dateInterval(of: .weekOfYear, for: selected)?.start ?? cal.startOfDay(for: selected)
            return [(0..<7).compactMap { (i: Int) -> Date? in cal.date(byAdding: .day, value: i, to: start) }]
        }
        guard let m = cal.dateInterval(of: .month, for: month) else { return [] }
        let leading = (cal.component(.weekday, from: m.start) - cal.firstWeekday + 7) % 7
        let gridStart = cal.date(byAdding: .day, value: -leading, to: m.start) ?? m.start
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let rows = Int(ceil(Double(leading + daysInMonth) / 7))
        return (0..<rows).map { (r: Int) -> [Date] in
            (0..<7).compactMap { (c: Int) -> Date? in cal.date(byAdding: .day, value: r * 7 + c, to: gridStart) }
        }
    }

    var body: some View {
        let symbols = Fmt.dayShort.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let order = (0..<7).map { ($0 + cal.firstWeekday - 1) % 7 }
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(order, id: \.self) { w in
                    Text(symbols[w])
                        .font(.system(size: 13))
                        .foregroundColor(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 34)
            VStack(spacing: 0) {
                ForEach(weeks, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { d in
                            DayCell(date: d,
                                    inMonth: tall || cal.isDate(d, equalTo: month, toGranularity: .month),
                                    isSelected: cal.isDate(d, inSameDayAs: selected),
                                    logic: logic,
                                    tall: tall)
                                .onTapGesture { selected = d }
                        }
                    }
                    .frame(maxHeight: tall ? CGFloat(260) : CGFloat.infinity)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.stroke))
            if tall { Spacer(minLength: 0) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Palette.shadow, radius: 10, y: 4)
    }
}

struct DayCell: View {
    @EnvironmentObject var store: Store
    let date: Date
    let inMonth: Bool
    let isSelected: Bool
    let logic: PlanLogic
    let tall: Bool
    private let cal = Calendar.current

    var body: some View {
        let isToday = cal.isDateInToday(date)
        let isPast = cal.startOfDay(for: date) <= cal.startOfDay(for: Date())
        let summary = logic.summary(on: date)
        let study = logic.studySeconds(on: date)
        let target = max(1, Pref.int(Pref.dailyStudyMinutes)) * 60
        let deadlines = store.deadlines.filter { cal.isDate($0.date, inSameDayAs: date) }
        let sessions = store.records.filter { $0.phase == .focus && $0.countsInStats && cal.isDate($0.start, inSameDayAs: date) }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isToday {
                    Text("\(cal.component(.day, from: date))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Palette.redGradient))
                } else {
                    Text("\(cal.component(.day, from: date))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(inMonth ? Palette.ink : Palette.muted.opacity(0.6))
                        .frame(height: 26)
                }
                Spacer()
            }
            VStack(spacing: 4) {
                if (summary.total > 0 || study > 0) && isPast && inMonth {
                    CompletionRing(fraction: Double(study) / Double(target), size: tall ? 30 : 22)
                        .help("Studied \(Fmt.hm(study)) of \(Fmt.hm(target))" + (summary.total > 0 ? " · \(summary.done)/\(summary.total) tasks done" : ""))
                }
                ForEach(deadlines.prefix(tall ? 5 : 2)) { d in
                    HStack(spacing: 3) {
                        Image(systemName: d.kind.icon).font(.system(size: 8))
                        Text(d.title)
                            .font(.system(size: 10, weight: .semibold))
                            .strikethrough(d.done)
                            .lineLimit(1)
                    }
                    .foregroundColor(Palette.accentText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Palette.blush))
                    .opacity(d.done ? 0.5 : 1)
                    .help(d.hasTime ? "\(d.title) · \(Fmt.time.string(from: d.date))" : d.title)
                }
                if deadlines.count > (tall ? 5 : 2) {
                    Text("+\(deadlines.count - (tall ? 5 : 2)) more")
                        .font(.system(size: 9))
                        .foregroundColor(Palette.muted)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            if !sessions.isEmpty && inMonth {
                HStack(spacing: 3) {
                    ForEach(Array(sessions.prefix(5).enumerated()), id: \.offset) { _, s in
                        Circle()
                            .fill(s.isManual ? Palette.red : Palette.salmon.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .help("\(sessions.count) focus \(sessions.count == 1 ? "session" : "sessions") · \(Fmt.hm(sessions.reduce(0) { $0 + $1.activeSeconds }))")
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isSelected ? Palette.blush.opacity(0.75) : (inMonth ? Palette.surface : Palette.outMonth))
        .overlay(Rectangle().strokeBorder(Palette.stroke.opacity(0.8), lineWidth: 0.5))
        .contentShape(Rectangle())
    }
}

struct DeadlineList: View {
    @EnvironmentObject var store: Store
    let from: Date
    var onEdit: (Deadline) -> Void
    private let cal = Calendar.current

    var body: some View {
        let list = store.deadlines.filter { $0.date >= from }
        let groups = Dictionary(grouping: list) { cal.startOfDay(for: $0.date) }.sorted { $0.key < $1.key }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if groups.isEmpty {
                    Text("No deadlines from this month on. Select a day and press + Add.")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.muted)
                        .padding(20)
                }
                ForEach(groups, id: \.key) { g in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Fmt.dayLong.string(from: g.key))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(cal.isDateInToday(g.key) ? Palette.red : Palette.ink)
                        ForEach(g.value) { d in
                            DeadlineRow(deadline: d, onEdit: { onEdit(d) })
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
    }
}

// MARK: - Side panel

struct DeadlineRow: View {
    @EnvironmentObject var store: Store
    let deadline: Deadline
    var onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.toggleDeadline(deadline.id)
            } label: {
                Image(systemName: deadline.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(Palette.accentText)
            }
            .buttonStyle(.plain)
            .help(deadline.done ? "Mark as not done" : "Mark as done")
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: deadline.kind.icon)
                        .font(.system(size: 10))
                        .foregroundColor(Palette.accentText)
                    Text(deadline.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .strikethrough(deadline.done)
                }
                if !deadline.note.isEmpty {
                    Text(deadline.note)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.inkSoft)
                }
            }
            Spacer()
            Text(deadline.hasTime ? Fmt.time.string(from: deadline.date) : "All day")
                .font(.system(size: 12))
                .foregroundColor(Palette.inkSoft)
        }
        .opacity(deadline.done ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onEdit() }
        .contextMenu {
            Button("Edit…") { onEdit() }
            Button(deadline.done ? "Mark as not done" : "Mark as done") { store.toggleDeadline(deadline.id) }
            Divider()
            Button("Delete", role: .destructive) { store.deleteDeadline(deadline.id) }
        }
    }
}

struct DeadlinesCard: View {
    @EnvironmentObject var store: Store
    let day: Date
    var onAdd: () -> Void
    var onEdit: (Deadline) -> Void

    var body: some View {
        let list = store.deadlines.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
        CardBox(spacing: 12) {
            HStack {
                Image(systemName: "flag.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Palette.accentText)
                Text("Deadlines (\(list.count))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Button("+ Add") { onAdd() }
                    .buttonStyle(SmallButtonStyle())
                    .foregroundColor(Palette.accentText)
            }
            if list.isEmpty {
                Text("Nothing due this day.")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.muted)
            } else {
                ForEach(list) { d in
                    DeadlineRow(deadline: d, onEdit: { onEdit(d) })
                }
            }
        }
    }
}

struct DailyGoalsCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    let day: Date
    let logic: PlanLogic

    var body: some View {
        let tasks = logic.tasks(on: day)
        let summary = logic.summary(on: day)
        let study = logic.studySeconds(on: day)
        let target = max(1, Pref.int(Pref.dailyStudyMinutes)) * 60
        CardBox(spacing: 12) {
            HStack {
                Image(systemName: "scope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Palette.accentText)
                Text("Daily goals")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text("\(summary.done) / \(summary.total) completed")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSoft)
            }
            HStack(spacing: 10) {
                Image(systemName: "book")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.accentText)
                    .frame(width: 20)
                Text("Study time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Spacer(minLength: 6)
                ProgressBar(value: Double(study) / Double(target), height: 6)
                    .frame(width: 56)
                Text("\(Fmt.hm(study)) / \(Fmt.hm(target))")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.inkSoft)
                    .frame(width: 80, alignment: .trailing)
            }
            if tasks.isEmpty {
                Button {
                    nav.page = .plan
                } label: {
                    Text("No tasks planned for this day. Set them up in Plan →")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.muted)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(tasks) { t in
                    let fraction = logic.fraction(t, on: day)
                    HStack(spacing: 10) {
                        Button {
                            store.toggleCheck(t.id, on: day)
                        } label: {
                            TaskStatusCircle(fraction: fraction >= 1 ? 1 : 0, size: 20)
                        }
                        .buttonStyle(.plain)
                        .help("Mark done for this day")
                        Text(t.name)
                            .font(.system(size: 13))
                            .foregroundColor(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        ProgressBar(value: fraction, height: 6)
                            .frame(width: 56)
                        Text("\(Fmt.hm(logic.progress(t, on: day))) / \(Fmt.hm(t.minutes * 60))")
                            .font(.system(size: 11))
                            .foregroundColor(Palette.inkSoft)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
        }
    }
}

struct CompletionSummaryCard: View {
    let day: Date
    let logic: PlanLogic

    var body: some View {
        let s = logic.summary(on: day)
        let fraction = s.total > 0 ? Double(s.done) / Double(s.total) : 0
        let study = logic.studySeconds(on: day)
        let target = max(1, Pref.int(Pref.dailyStudyMinutes)) * 60
        let pct = Int((fraction * 100).rounded())
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        CompletionRing(fraction: 0.8, size: 18, lineWidth: 3.5)
                        Text("Completion summary")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Palette.ink)
                    }
                    Text(s.total > 0 ? "\(s.done) of \(s.total)" : "—")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Palette.ink)
                        .padding(.top, 8)
                    Text("planned tasks completed")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.inkSoft)
                    Text("\(Fmt.hm(study)) of \(Fmt.hm(target)) studied")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(study >= target ? Palette.green : Palette.red)
                }
                Spacer()
                ZStack {
                    CompletionRing(fraction: fraction, size: 66, lineWidth: 7)
                    Text("\(pct)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Palette.ink)
                }
            }
            .padding(18)
            ZStack(alignment: .leading) {
                LandscapeView(variant: .card)
                    .frame(height: 92)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sun.horizon")
                        .font(.system(size: 24))
                        .foregroundColor(Palette.accentText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(fraction, s.total))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Palette.ink)
                        Text(message(pct, s.total))
                            .font(.system(size: 11))
                            .foregroundColor(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Palette.shadow, radius: 10, y: 4)
    }

    private func title(_ f: Double, _ total: Int) -> String {
        if total == 0 { return "No plan for this day" }
        if f >= 1 { return "All done!" }
        return f >= 0.5 ? "Good progress!" : "Keep going!"
    }

    private func message(_ pct: Int, _ total: Int) -> String {
        if total == 0 { return "Add recurring tasks in Plan to track this day." }
        return "You completed \(pct)% of your daily plan."
    }
}
