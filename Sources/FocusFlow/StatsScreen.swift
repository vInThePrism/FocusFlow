import SwiftUI

struct StatsScreen: View {
    @EnvironmentObject var store: Store
    @State private var scope: StatsScope = .day
    @State private var anchor = Date()
    @State private var calendarMonth = Date()
    @State private var chartYear = Date()

    var body: some View {
        let a = Analytics(records: store.records)
        ScrollView {
            VStack(spacing: 16) {
                header
                KPIRow(a: a, scope: scope, anchor: anchor)
                HStack(alignment: .top, spacing: 16) {
                    PrimaryChartCard(a: a, scope: scope, anchor: anchor)
                    GoalCard(a: a, scope: scope, anchor: anchor)
                        .frame(width: 410)
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 16) {
                    ByTypeCard(a: a, scope: scope, anchor: anchor)
                    WindowCard(a: a, scope: scope, anchor: anchor)
                        .frame(width: 410)
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 16) {
                    CalendarCard(a: a, month: $calendarMonth)
                        .frame(width: 430)
                    MonthlyCard(a: a, year: $chartYear, selected: anchor) { month in
                        scope = .month
                        anchor = month
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(EdgeInsets(top: 22, leading: 18, bottom: 24, trailing: 20))
        }
        .onChange(of: anchor) { d in
            calendarMonth = d
            chartYear = d
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ScopeTabs(scope: $scope)
            Spacer()
            DateNavigator(scope: scope, anchor: $anchor)
            MoreMenu()
        }
    }
}

struct ScopeTabs: View {
    @Binding var scope: StatsScope

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StatsScope.allCases) { s in
                tab(s)
            }
        }
        .padding(5)
        .background(Capsule().fill(Palette.tabTrack))
    }

    private func tab(_ s: StatsScope) -> some View {
        let on = scope == s
        return Button {
            scope = s
        } label: {
            HStack(spacing: 9) {
                Image(systemName: s.icon).font(.system(size: 14, weight: .medium))
                Text(s.rawValue).font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(on ? .white : Palette.inkSoft)
            .padding(.horizontal, 34)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(on ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Color.clear))
                    .shadow(color: on ? Palette.red.opacity(0.3) : .clear, radius: 6, y: 3)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct DateNavigator: View {
    let scope: StatsScope
    @Binding var anchor: Date
    private let cal = Calendar.current

    private var title: String {
        switch scope {
        case .day: return Fmt.dayLong.string(from: anchor)
        case .month: return Fmt.monthLong.string(from: anchor)
        case .year: return Fmt.year.string(from: anchor)
        }
    }

    private var isCurrent: Bool {
        cal.isDate(anchor, equalTo: Date(), toGranularity: scope.component)
    }

    var body: some View {
        HStack(spacing: 14) {
            arrow("chevron.left", -1)
            Button {
                anchor = Date()
            } label: {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .frame(minWidth: 140)
            }
            .buttonStyle(.plain)
            .help("Back to today")
            arrow("chevron.right", 1)
                .disabled(isCurrent)
                .opacity(isCurrent ? 0.3 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(Palette.stroke))
    }

    private func arrow(_ name: String, _ delta: Int) -> some View {
        Button {
            if let d = cal.date(byAdding: scope.component, value: delta, to: anchor) {
                anchor = min(d, Date())
            }
        } label: {
            Image(systemName: name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Palette.accentText)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - KPI row

struct Delta {
    let text: String
    let up: Bool

    static func percent(_ now: Int, _ before: Int) -> Delta? {
        guard before > 0 else { return now > 0 ? Delta(text: "New", up: true) : nil }
        let change = (Double(now) - Double(before)) / Double(before) * 100
        return Delta(text: String(format: "%+.0f%%", change), up: change >= 0)
    }

    static func difference(_ now: Int, _ before: Int) -> Delta {
        let d = now - before
        return Delta(text: d >= 0 ? "+\(d)" : "\(d)", up: d >= 0)
    }
}

struct KPIRow: View {
    let a: Analytics
    let scope: StatsScope
    let anchor: Date

    var body: some View {
        let cal = Calendar.current
        let cur = a.period(scope, anchor)
        let prev = a.previousPeriod(scope, anchor)
        let focusNow = a.focusSeconds(cur)
        let focusPrev = a.focusSeconds(prev)
        let doneNow = a.completedCount(cur)
        let donePrev = a.completedCount(prev)
        let streakDay = min(cur.end.addingTimeInterval(-1), Date())
        let streak = a.streak(at: streakDay)
        let streakPrev = a.streak(at: cal.date(byAdding: .day, value: -7, to: streakDay) ?? streakDay)
        let best = a.bestDay(in: a.bestDayPeriod(scope, anchor))

        HStack(spacing: 14) {
            KPICard(icon: "timer", tint: Palette.red, title: "Total focus time", value: Fmt.hm(focusNow),
                    delta: Delta.percent(focusNow, focusPrev), deltaLabel: scope.compareLabel)
            KPICard(icon: "checkmark.circle", tint: Palette.red, title: "Completed sessions", value: "\(doneNow)",
                    delta: Delta.difference(doneNow, donePrev), deltaLabel: scope.compareLabel)
            KPICard(icon: "flame.fill", tint: Palette.orange, title: "Current streak",
                    value: streak == 1 ? "1 day" : "\(streak) days",
                    delta: Delta.difference(streak, streakPrev), deltaLabel: "vs. last week")
            KPICard(icon: "trophy.fill", tint: Palette.gold, title: "Best day",
                    value: best.map { Fmt.hm($0.focus) } ?? "—",
                    footnote: best.map { Fmt.dayLong.string(from: $0.date) } ?? "No sessions yet")
        }
    }
}

struct KPICard: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    var delta: Delta? = nil
    var deltaLabel: String = ""
    var footnote: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            IconBadge(systemName: icon, tint: tint, size: 42)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(Palette.inkSoft)
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let d = delta {
                    HStack(spacing: 4) {
                        Image(systemName: d.up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                        Text(d.text)
                            .font(.system(size: 12, weight: .semibold))
                        Text(deltaLabel)
                            .font(.system(size: 12))
                            .foregroundColor(Palette.muted)
                    }
                    .foregroundColor(d.up ? Palette.green : Palette.red)
                    .lineLimit(1)
                } else if let f = footnote {
                    Text(f)
                        .font(.system(size: 12))
                        .foregroundColor(Palette.inkSoft)
                        .lineLimit(1)
                } else {
                    Text(deltaLabel.isEmpty ? " " : "— \(deltaLabel)")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Palette.shadow, radius: 10, y: 4)
    }
}

// MARK: - Main chart (timeline / daily / weekday)

struct PrimaryChartCard: View {
    let a: Analytics
    let scope: StatsScope
    let anchor: Date

    private var title: String {
        switch scope {
        case .day: return Calendar.current.isDateInToday(anchor) ? "Today’s focus timeline" : "Focus timeline"
        case .month: return "Daily focus"
        case .year: return "Average day of the week"
        }
    }

    var body: some View {
        let range = a.period(scope, anchor)
        CardBox(stretch: true) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                (Text("Total focus  ").foregroundColor(Palette.inkSoft)
                 + Text(Fmt.hm(a.focusSeconds(range))).bold().foregroundColor(Palette.ink))
                    .font(.system(size: 13))
            }
            switch scope {
            case .day:
                DayTimeline(records: a.records(in: range), day: range.start)
            case .month:
                DailyBars(days: a.dailyValues(range))
            case .year:
                WeekdayBars(values: a.weekdayAverages(range))
            }
        }
    }
}

struct DayTimeline: View {
    let records: [SessionRecord]
    let day: Date
    @AppStorage(Pref.extendMinutes) private var extendMin = 5

    private var hourRange: (lo: Int, hi: Int) {
        var lo = 8, hi = 20
        let cal = Calendar.current
        for r in records {
            lo = min(lo, cal.component(.hour, from: r.start))
            let endHours = Int(ceil(r.end.timeIntervalSince(day) / 3600))
            hi = max(hi, min(24, endHours))
        }
        if (hi - lo) % 2 == 1 {
            if hi < 24 { hi += 1 } else { lo -= 1 }
        }
        return (lo, hi)
    }

    var body: some View {
        let range = hourRange
        let origin = day.addingTimeInterval(Double(range.lo) * 3600)
        let span = Double(range.hi - range.lo) * 3600
        let marks = Array(stride(from: range.lo, through: range.hi, by: 2))
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Palette.timelineBg)
                        .frame(width: w, height: 62)
                    ForEach(marks, id: \.self) { h in
                        Rectangle()
                            .fill(Palette.stroke)
                            .frame(width: 1, height: 62)
                            .offset(x: w * CGFloat(Double(h - range.lo) * 3600 / span))
                    }
                    ForEach(records) { r in
                        block(r, width: w, origin: origin, span: span)
                    }
                }
            }
            .frame(height: 62)

            GeometryReader { g in
                ForEach(marks, id: \.self) { h in
                    Text(Fmt.hourLabel(h))
                        .font(.system(size: 11))
                        .foregroundColor(Palette.muted)
                        .fixedSize()
                        .position(x: min(max(g.size.width * CGFloat(Double(h - range.lo) * 3600 / span), 18), g.size.width - 18), y: 7)
                }
            }
            .frame(height: 14)

            HStack(spacing: 22) {
                LegendDot(color: Palette.red, label: "Focus")
                LegendDot(color: Palette.peach, label: "Break")
                LegendDot(color: Palette.coral, label: "Extended (+\(extendMin) min)")
            }
            .padding(.top, 4)

            if records.isEmpty {
                Text("No sessions on this day.")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.muted)
            }
        }
    }

    @ViewBuilder
    private func block(_ r: SessionRecord, width w: CGFloat, origin: Date, span: Double) -> some View {
        let x0 = CGFloat(max(0, r.start.timeIntervalSince(origin)) / span) * w
        let duration = max(r.end.timeIntervalSince(r.start), Double(r.activeSeconds))
        let bw = min(max(3, CGFloat(duration / span) * w), max(3, w - x0))
        if r.phase == .focus {
            let extFrac = r.activeSeconds > 0 ? CGFloat(r.extendedSeconds) / CGFloat(r.activeSeconds) : 0
            HStack(spacing: 0) {
                Rectangle().fill(Palette.red).frame(width: bw * (1 - extFrac))
                Rectangle().fill(Palette.coral).frame(width: bw * extFrac)
            }
            .frame(width: bw, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .offset(x: x0, y: 4)
            .help("\(r.intention.isEmpty ? "Focus" : r.intention) · \(Fmt.time.string(from: r.start)) · \(Fmt.hm(r.activeSeconds))")
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Palette.peach)
                .frame(width: bw, height: 54)
                .offset(x: x0, y: 4)
                .help("\(r.phase.lowerTitle) · \(Fmt.time.string(from: r.start)) · \(Fmt.hm(r.activeSeconds))")
        }
    }
}

struct DailyBars: View {
    let days: [DayValue]
    private let plot: CGFloat = 116

    var body: some View {
        let peak = max(60, days.map { $0.focus }.max() ?? 0)
        let cal = Calendar.current
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(days) { d in
                let day = cal.component(.day, from: d.date)
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(cal.isDateInToday(d.date) ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.salmon))
                            .frame(height: d.focus > 0 ? max(3, plot * CGFloat(d.focus) / CGFloat(peak)) : 0)
                    }
                    .frame(height: plot)
                    Text(day == 1 || day % 5 == 0 ? "\(day)" : " ")
                        .font(.system(size: 9))
                        .foregroundColor(Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .help("\(Fmt.dayShort.string(from: d.date)): \(Fmt.hm(d.focus))")
            }
        }
    }
}

struct WeekdayBars: View {
    let values: [WeekdayValue]
    private let plot: CGFloat = 116

    var body: some View {
        let peak = max(60, values.map { $0.seconds }.max() ?? 0)
        HStack(alignment: .bottom, spacing: 18) {
            ForEach(values) { v in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(v.seconds == peak ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.salmon))
                            .frame(height: v.seconds > 0 ? max(3, plot * CGFloat(v.seconds) / CGFloat(peak)) : 0)
                    }
                    .frame(height: plot)
                    Text(v.label)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .help("\(v.label): \(Fmt.hm(v.seconds)) on average")
            }
        }
    }
}

// MARK: - Goal

struct GoalCard: View {
    let a: Analytics
    let scope: StatsScope
    let anchor: Date
    @AppStorage(Pref.weeklyGoalHours) private var weeklyHours = 25
    @State private var editing = false

    var body: some View {
        let range = a.goalPeriod(scope, anchor)
        let dayCount = Double(a.days(in: range).count)
        let goal = Int(Double(weeklyHours) * 3600 * dayCount / 7)
        let done = a.focusSeconds(range)
        let fraction = goal > 0 ? Double(done) / Double(goal) : 0
        let pct = Int((fraction * 100).rounded())

        CardBox(stretch: true) {
            HStack {
                Text("Goal completion")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Button("Edit goal") { editing = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.accentText)
                    .popover(isPresented: $editing, arrowEdge: .bottom) {
                        GoalEditor(hours: $weeklyHours)
                    }
            }
            HStack(alignment: .center, spacing: 22) {
                ZStack {
                    Circle().stroke(Palette.donutTrack, lineWidth: 20)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1, fraction)))
                        .stroke(Palette.redGradient, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(pct)%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Palette.ink)
                        Text("\(Fmt.hm(done))\nof \(Fmt.hm(goal))")
                            .font(.system(size: 12))
                            .foregroundColor(Palette.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 140, height: 140)
                .padding(10)

                VStack(alignment: .leading, spacing: 14) {
                    valueRow(color: Palette.red, label: "Focused time", value: Fmt.hm(done))
                    valueRow(color: Palette.peach, label: "Remaining", value: Fmt.hm(max(0, goal - done)))
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "scope")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Palette.accentText)
                        Text(fraction >= 1
                             ? "You reached your \(scope.goalWord) goal. Wonderful!"
                             : "You’re \(pct)% to your \(scope.goalWord) goal. Keep going!")
                            .font(.system(size: 12))
                            .foregroundColor(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.blushLight))
                }
            }
        }
    }

    private func valueRow(color: Color, label: String, value: String) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 13)).foregroundColor(Palette.inkSoft)
            Spacer()
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(Palette.ink)
        }
    }
}

struct GoalEditor: View {
    @Binding var hours: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly focus goal")
                .font(.system(size: 13, weight: .semibold))
            ValueStepper(value: $hours, range: 1...100, suffix: " h", width: 110)
            Text("Monthly and yearly goals scale from this.")
                .font(.system(size: 11))
                .foregroundColor(Palette.muted)
        }
        .padding(16)
    }
}

// MARK: - By type

struct ByTypeCard: View {
    let a: Analytics
    let scope: StatsScope
    let anchor: Date
    @AppStorage(Pref.focusMinutes) private var focusMin = 25
    @AppStorage(Pref.shortBreakMinutes) private var breakMin = 5
    @AppStorage(Pref.extendMinutes) private var extendMin = 5

    var body: some View {
        let recs = a.records(in: a.period(scope, anchor))
        let focus = recs.filter { $0.phase == .focus }.reduce(0) { $0 + $1.baseSeconds }
        let extended = recs.filter { $0.phase == .focus }.reduce(0) { $0 + $1.extendedSeconds }
        let breaks = recs.filter { $0.phase.isBreak }.reduce(0) { $0 + $1.activeSeconds }
        let total = focus + extended + breaks

        CardBox(spacing: 16, stretch: true) {
            HStack {
                Text("Focus time by type")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text("\(Fmt.hm(total)) total")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.inkSoft)
            }
            TypeRow(color: Palette.red, label: "Focus (\(focusMin) min)", seconds: focus, total: total)
            TypeRow(color: Palette.peach, label: "Break (\(breakMin) min)", seconds: breaks, total: total)
            TypeRow(color: Palette.coral, label: "Extended (+\(extendMin) min)", seconds: extended, total: total)
        }
    }
}

struct TypeRow: View {
    let color: Color
    let label: String
    let seconds: Int
    let total: Int

    var body: some View {
        let fraction = total > 0 ? Double(seconds) / Double(total) : 0
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 11, height: 11)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Palette.inkSoft)
                .frame(width: 130, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.typeTrack)
                    Capsule().fill(color).frame(width: fraction > 0 ? max(8, g.size.width * CGFloat(fraction)) : 0)
                }
            }
            .frame(height: 12)
            Text(Fmt.hm(seconds))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.ink)
                .frame(width: 60, alignment: .trailing)
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 12))
                .foregroundColor(Palette.inkSoft)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

// MARK: - Strongest window

struct WindowCard: View {
    let a: Analytics
    let scope: StatsScope
    let anchor: Date

    var body: some View {
        let window = a.strongestWindow(a.windowPeriod(scope, anchor))
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sun.max")
                .font(.system(size: 28, weight: .regular))
                .foregroundColor(Palette.gold)
            VStack(alignment: .leading, spacing: 8) {
                Text("Your strongest focus window")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Text(window.map { Fmt.hourRange($0.startHour) } ?? "Not enough data yet")
                    .font(.system(size: window == nil ? 20 : 30, weight: .bold))
                    .foregroundColor(Palette.ink)
                Text(description(window))
                    .font(.system(size: 13))
                    .foregroundColor(Palette.inkSoft)
                    .frame(maxWidth: 230, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack(alignment: .bottomTrailing) {
                Palette.card
                LandscapeView(variant: .corner)
                    .frame(width: 230, height: 96)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Palette.shadow, radius: 10, y: 4)
    }

    private func description(_ w: FocusWindow?) -> String {
        guard let w = w else { return "Focus for a few more sessions and FocusFlow will find your peak hours." }
        guard let p = w.percentMore else { return "Almost all of your focus happens in this window." }
        if p <= 0 { return "Your focus is spread evenly through the day." }
        return "You focus \(p)% more during this time compared to the rest of the day."
    }
}

// MARK: - Calendar heatmap

struct CalendarCard: View {
    let a: Analytics
    @Binding var month: Date

    private static var levels: [Color] { Palette.heat }

    private func level(_ seconds: Int) -> Int {
        let m = seconds / 60
        if m <= 0 { return 0 }
        if m < 30 { return 1 }
        if m < 90 { return 2 }
        if m < 180 { return 3 }
        return 4
    }

    var body: some View {
        let cells = a.monthGrid(month)
        let symbols = Fmt.dayShort.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let order = a.weekdayOrder()
        let isCurrent = Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)

        CardBox(spacing: 12, stretch: true) {
            HStack {
                Text("Focus calendar")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                shiftButton("chevron.left", -1)
                Text(Fmt.monthYear.string(from: month))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .frame(minWidth: 70)
                shiftButton("chevron.right", 1)
                    .disabled(isCurrent)
                    .opacity(isCurrent ? 0.3 : 1)
            }
            HStack(spacing: 6) {
                ForEach(order, id: \.self) { w in
                    Text(symbols[w])
                        .font(.system(size: 11))
                        .foregroundColor(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(cells) { c in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(c.date == nil ? Color.clear : CalendarCard.levels[level(c.seconds)])
                        .frame(height: 20)
                        .help(c.date.map { "\(Fmt.dayShort.string(from: $0)): \(Fmt.hm(c.seconds))" } ?? "")
                }
            }
            HStack(spacing: 6) {
                Spacer()
                Text("Less focus").font(.system(size: 11)).foregroundColor(Palette.muted)
                ForEach(0..<5, id: \.self) { i in
                    Circle().fill(CalendarCard.levels[i]).frame(width: 10, height: 10)
                }
                Text("More focus").font(.system(size: 11)).foregroundColor(Palette.muted)
                Spacer()
            }
        }
    }

    private func shiftButton(_ name: String, _ delta: Int) -> some View {
        Button {
            if let d = Calendar.current.date(byAdding: .month, value: delta, to: month) {
                month = min(d, Date())
            }
        } label: {
            Image(systemName: name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Palette.accentText)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Monthly bars

struct MonthlyCard: View {
    let a: Analytics
    @Binding var year: Date
    let selected: Date
    var onPick: (Date) -> Void
    @State private var hovered: Int?
    private let plot: CGFloat = 130

    var body: some View {
        let cal = Calendar.current
        let months = a.monthValues(year: year)
        let peakHours = Double(months.map { $0.seconds }.max() ?? 0) / 3600
        let axisMax = max(2, niceCeil(peakHours))
        let selectedIndex: Int? = cal.isDate(selected, equalTo: year, toGranularity: .year) ? cal.component(.month, from: selected) - 1 : nil
        let highlight = hovered ?? selectedIndex
        let isCurrent = cal.isDate(year, equalTo: Date(), toGranularity: .year)

        CardBox(spacing: 12, stretch: true) {
            HStack {
                Text("Monthly focus time")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                shiftButton("chevron.left", -1)
                Text(Fmt.year.string(from: year))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .frame(minWidth: 44)
                shiftButton("chevron.right", 1)
                    .disabled(isCurrent)
                    .opacity(isCurrent ? 0.3 : 1)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .trailing) {
                    Text("\(axisMax)h")
                    Spacer()
                    Text("\(axisMax / 2)h")
                    Spacer()
                    Text("0h")
                }
                .font(.system(size: 10))
                .foregroundColor(Palette.muted)
                .frame(height: plot)
                .fixedSize()
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(months) { m in
                        column(m, axisMax: axisMax, highlighted: m.index == highlight)
                    }
                }
            }
            .padding(.top, 26)
        }
    }

    private func barHeight(_ m: MonthValue, axisMax: Int) -> CGFloat {
        guard m.seconds > 0 else { return 0 }
        return max(3, plot * CGFloat(Double(m.seconds) / 3600 / Double(axisMax)))
    }

    private func column(_ m: MonthValue, axisMax: Int, highlighted: Bool) -> some View {
        let h = barHeight(m, axisMax: axisMax)
        return VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Color.clear
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(highlighted ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.peach))
                    .frame(height: h)
            }
            .frame(height: plot)
            .overlay(alignment: .bottom) {
                if highlighted {
                    VStack(spacing: 1) {
                        Text(Fmt.hm(m.seconds))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Palette.ink)
                        Text(Fmt.monthYear.string(from: m.date))
                            .font(.system(size: 10))
                            .foregroundColor(Palette.inkSoft)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.stroke))
                    .shadow(color: Palette.shadow, radius: 6, y: 2)
                    .fixedSize()
                    .offset(y: -(h + 8))
                }
            }
            Text(Fmt.monthAbbr.string(from: m.date))
                .font(.system(size: 11, weight: highlighted ? .bold : .regular))
                .foregroundColor(highlighted ? Palette.ink : Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .zIndex(highlighted ? 1 : 0)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside {
                hovered = m.index
            } else if hovered == m.index {
                hovered = nil
            }
        }
        .onTapGesture { onPick(m.date) }
    }

    private func shiftButton(_ name: String, _ delta: Int) -> some View {
        Button {
            if let d = Calendar.current.date(byAdding: .year, value: delta, to: year) {
                year = min(d, Date())
            }
        } label: {
            Image(systemName: name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Palette.accentText)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
