import SwiftUI

struct RightColumn: View {
    @EnvironmentObject var engine: Engine

    private var finished: Bool { engine.phase == .focus && engine.state == .finished }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                MoreMenu()
            }
            .frame(height: 20)
            .padding(.top, -14)
            TodayCard()
            if finished {
                TodayTimelineCard()
            } else {
                Last7DaysCard()
            }
            QuoteCard(text: finished
                      ? "You’re building something great.\nA little more time can go a long way."
                      : "Small blocks of focused time\ncreate a bigger, brighter you.")
        }
    }
}

struct TodayCard: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @AppStorage(Pref.dailyGoal) private var goal = 6

    var body: some View {
        let today = TodaySummary(all: store.merged(with: engine.liveRecord))
        CardBox {
            Button {
                nav.page = .stats
            } label: {
                HStack(spacing: 8) {
                    Text("Today")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Text(Fmt.dayShort.string(from: Date()))
                        .font(.system(size: 13))
                        .foregroundColor(Palette.inkSoft)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.inkSoft)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            InnerBox {
                HStack(spacing: 10) {
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Palette.red)
                    Text("Focus goal")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    (Text("\(today.completed)").bold().foregroundColor(Palette.ink)
                     + Text(" / \(goal) sessions").foregroundColor(Palette.inkSoft))
                        .font(.system(size: 13))
                }
                ProgressBar(value: Double(today.completed) / Double(max(goal, 1)), height: 12)
            }

            HStack(spacing: 12) {
                StatMini(icon: "checkmark.circle", title: "Sessions\ncompleted", value: "\(today.completed)")
                StatMini(icon: "clock", title: "Total focused\ntime", value: Fmt.minutes(today.focusSeconds))
            }
        }
    }
}

struct StatMini: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        InnerBox(padding: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Palette.red)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSoft)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct Last7DaysCard: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav

    var body: some View {
        let days = Analytics(records: store.merged(with: engine.liveRecord)).lastDays(7, endingAt: Date())
        CardBox(stretch: false) {
            Button {
                nav.page = .stats
            } label: {
                HStack {
                    Text("Last 7 days")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.inkSoft)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            WeekBars(days: days)
                .frame(height: 140)
        }
    }
}

struct WeekBars: View {
    let days: [DayValue]
    private let plot: CGFloat = 108

    private var scaleMinutes: Int {
        let peak = days.map { ($0.focus + $0.breaks) / 60 }.max() ?? 0
        return max(120, Int(ceil(Double(peak) / 60.0)) * 60)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(days) { d in
                    column(d)
                }
            }
            VStack(alignment: .leading) {
                Text("\(scaleMinutes)")
                Spacer()
                Text("\(scaleMinutes / 2)")
                Spacer()
                Text("0 (min)")
            }
            .font(.system(size: 10))
            .foregroundColor(Palette.muted)
            .frame(height: plot)
            .fixedSize()
        }
    }

    private func height(_ seconds: Int) -> CGFloat {
        let v = Double(seconds) / 60 / Double(scaleMinutes)
        if seconds <= 0 { return 0 }
        return max(4, plot * CGFloat(min(1, v)))
    }

    private func column(_ d: DayValue) -> some View {
        let isToday = Calendar.current.isDateInToday(d.date)
        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: 0xF9E3DB))
                    .frame(height: height(d.focus + d.breaks))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isToday ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.salmon))
                    .frame(height: height(d.focus))
            }
            .frame(width: 20, height: plot, alignment: .bottom)
            Text(Fmt.weekday.string(from: d.date))
                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? Palette.ink : Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .help("\(Fmt.dayShort.string(from: d.date)): \(Fmt.hm(d.focus)) focus")
    }
}

struct TodayTimelineCard: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: Store

    var body: some View {
        let liveID = engine.liveRecord?.id
        let items = Array(TodaySummary(all: store.records).records.filter { $0.id != liveID }.suffix(4))
        CardBox(spacing: 12) {
            Text("Today’s timeline")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Palette.ink)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items) { r in
                    TimelineRow(record: r)
                }
                completeRow
            }
        }
    }

    private var completeRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Palette.red)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(Palette.blush, lineWidth: 3).frame(width: 18, height: 18))
                .frame(width: 14)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    Text("Session complete")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text(Fmt.time.string(from: engine.liveRecord?.end ?? Date()))
                        .font(.system(size: 11))
                        .foregroundColor(Palette.muted)
                }
                Text(engine.canExtend ? "Ready to extend" : "Ready for a break")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSoft)
            }
            Spacer()
        }
        .padding(.top, 4)
    }
}

struct TimelineRow: View {
    let record: SessionRecord

    private var name: String {
        switch record.phase {
        case .focus: return "Focus session"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(record.phase == .focus ? Palette.red : Palette.peach)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                Rectangle()
                    .fill(Palette.stroke)
                    .frame(width: 2)
            }
            .frame(width: 14)
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(Palette.ink)
                .help(record.intention)
            Spacer()
            Text(Fmt.time.string(from: record.start))
                .font(.system(size: 11))
                .foregroundColor(Palette.muted)
                .frame(width: 62, alignment: .leading)
            Text(Fmt.minutes(record.activeSeconds))
                .font(.system(size: 13))
                .foregroundColor(Palette.inkSoft)
                .frame(width: 56, alignment: .trailing)
        }
        .frame(height: 36)
    }
}

struct QuoteCard: View {
    let text: String

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.card
            LandscapeView(variant: .card)
                .frame(height: 100)
            VStack {
                HStack(alignment: .top, spacing: 10) {
                    Text("\u{201C}")
                        .font(.system(size: 54, weight: .bold, design: .serif))
                        .foregroundColor(Palette.peach)
                        .frame(height: 40, alignment: .top)
                    Text(text)
                        .font(.system(size: 15, design: .serif).italic())
                        .foregroundColor(Palette.inkSoft)
                        .lineSpacing(4)
                        .padding(.top, 8)
                    Spacer(minLength: 0)
                }
                .padding(20)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Palette.shadow, radius: 10, y: 4)
    }
}
