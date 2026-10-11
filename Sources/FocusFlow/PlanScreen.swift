import SwiftUI

/// "Plan Builder": recurring daily tasks, bulk add, and the day's time blocks.
struct PlanScreen: View {
    @EnvironmentObject var store: Store
    @State private var editing: PlanTask?
    @State private var creating = false
    @State private var day = Date()

    var body: some View {
        let logic = PlanLogic(tasks: store.tasks, sessions: store.records, blocks: store.blocks, checks: store.checks)
        HStack(alignment: .top, spacing: 18) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tasksCard(logic)
                    BulkApplyCard()
                }
                .padding(.vertical, 24)
                .padding(.leading, 2)
            }
            DayPlanPanel(day: $day)
                .frame(width: 330)
                .padding(.vertical, 24)
        }
        .padding(.leading, 18)
        .padding(.trailing, 20)
        .sheet(item: $editing) { t in
            TaskEditor(task: t, isNew: false).environmentObject(store)
        }
        .sheet(isPresented: $creating) {
            TaskEditor(task: PlanTask(name: "", minutes: 60, weekdays: Weekdays.workdays, icon: "checklist"), isNew: true)
                .environmentObject(store)
        }
    }

    private func tasksCard(_ logic: PlanLogic) -> some View {
        CardBox(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recurring daily tasks")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Text("Set the activities you want to repeat each week.")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.inkSoft)
                }
                Spacer()
                Button {
                    creating = true
                } label: {
                    Label("Add task", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))
            }
            if store.tasks.isEmpty {
                Text("No tasks yet. Add one, or paste a few lines into Bulk apply below.")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.muted)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.tasks) { t in
                    TaskRow(task: t, logic: logic) { editing = t }
                }
            }
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject var store: Store
    let task: PlanTask
    let logic: PlanLogic
    let onEdit: () -> Void

    var body: some View {
        let week = logic.week(task, of: Date())
        HStack(spacing: 12) {
            Image(systemName: task.icon)
                .font(.system(size: 19))
                .foregroundColor(Palette.red)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                Text(task.note.isEmpty ? " " : task.note)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSoft)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(task.minutes) min")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.ink)
                .fixedSize()
            WeekdayChips(selected: task.weekdays) { w in
                var t = task
                if t.weekdays.contains(w) { t.weekdays.remove(w) } else { t.weekdays.insert(w) }
                if !t.weekdays.isEmpty { store.saveTask(t) }
            }
            .fixedSize()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Toggle("", isOn: Binding(get: { task.enabled }, set: { on in
                        var t = task
                        t.enabled = on
                        store.saveTask(t)
                    }))
                    .toggleStyle(PillToggleStyle())
                    .labelsHidden()
                    Menu {
                        Button("Edit…") { onEdit() }
                        Button("Delete", role: .destructive) { store.deleteTask(task.id) }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                Text("\(week.done) / \(week.scheduled) days")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.inkSoft)
                ProgressBar(value: week.scheduled > 0 ? Double(week.done) / Double(week.scheduled) : 0, height: 4)
                    .frame(width: 60)
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.stroke))
        .opacity(task.enabled ? 1 : 0.55)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onEdit() }
    }
}

struct BulkApplyCard: View {
    @EnvironmentObject var store: Store
    @State private var text = ""
    @State private var days: Set<Int> = Weekdays.workdays
    @State private var applied: String?

    private let placeholder = "CUDA Coding Practice | 120 | GPU programming\nLeetCode Practice | 90 | Algorithm problem solving\nResume Submission | 30"

    var body: some View {
        let parsed = BulkParser.parse(text)
        CardBox(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bulk apply / Quick add")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Palette.ink)
                Text("Add multiple tasks at once. One per line, format: Name | minutes | optional note")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.inkSoft)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundColor(Palette.muted.opacity(0.7))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 118)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.stroke))

            HStack(spacing: 12) {
                Text("Apply to")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.inkSoft)
                WeekdayChips(selected: days) { w in
                    if days.contains(w) { days.remove(w) } else { days.insert(w) }
                }
                Spacer()
                Button(parsed.count == 1 ? "Apply 1 task" : "Apply \(parsed.count) tasks") {
                    let n = store.applyBulk(parsed, weekdays: days)
                    applied = "Applied \(n) \(n == 1 ? "task" : "tasks") to \(Weekdays.names(days))."
                    text = ""
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))
                .disabled(parsed.isEmpty || days.isEmpty)
                .opacity(parsed.isEmpty || days.isEmpty ? 0.5 : 1)
            }

            if !parsed.isEmpty {
                preview(parsed)
            } else if let note = applied {
                Label(note, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.green)
            }
        }
    }

    private func preview(_ parsed: [ParsedTask]) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(Palette.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("Preview")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.green)
                Text(days.isEmpty ? "Pick at least one day" : "Will apply to \(Weekdays.names(days))")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.ink)
                Text("\(parsed.count) \(parsed.count == 1 ? "task" : "tasks") scheduled")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.muted)
            }
            .fixedSize()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(parsed) { p in
                        VStack(spacing: 4) {
                            Image(systemName: TaskIcons.guess(p.name))
                                .font(.system(size: 15))
                                .foregroundColor(Palette.red)
                            Text(p.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Palette.ink)
                                .lineLimit(1)
                            Text("\(p.minutes) min")
                                .font(.system(size: 10))
                                .foregroundColor(Palette.muted)
                        }
                        .frame(width: 76)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                        .help(p.note.isEmpty ? p.name : "\(p.name) — \(p.note)")
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.blushLight))
    }
}

// MARK: - Right panel: the day's blocks

struct DayPlanPanel: View {
    enum Mode: String, CaseIterable { case day = "Day view", week = "Week view" }

    @EnvironmentObject var store: Store
    @Binding var day: Date
    @State private var mode: Mode = .day
    @State private var sheet: BlockSheet?

    var body: some View {
        VStack(spacing: 14) {
            DayNavigator(day: $day)
            CapsuleTabs(items: Mode.allCases, selection: $mode, title: { $0.rawValue }, horizontalPadding: 30)
            switch mode {
            case .day:
                DaySchedule(day: day,
                            onAdd: { s, e in sheet = BlockSheet(block: TimeBlock(start: s, end: e, title: ""), isNew: true) },
                            onEdit: { b in sheet = BlockSheet(block: b, isNew: false) })
            case .week:
                WeekSchedule(day: day) { d in
                    day = d
                    mode = .day
                }
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Palette.shadow, radius: 10, y: 4)
        .sheet(item: $sheet) { s in
            BlockEditor(block: s.block, isNew: s.isNew).environmentObject(store)
        }
    }
}

private struct FreeSlot: Identifiable {
    let start: Date
    let end: Date
    var id: Date { start }
}

struct DaySchedule: View {
    @EnvironmentObject var store: Store
    let day: Date
    var onAdd: (Date, Date) -> Void
    var onEdit: (TimeBlock) -> Void
    private let hourHeight: CGFloat = 46
    private let cal = Calendar.current

    var body: some View {
        let dayStart = cal.startOfDay(for: day)
        let blocks = store.blocks.filter { cal.isDate($0.start, inSameDayAs: day) }
        let range = hourRange(blocks)
        let origin = dayStart.addingTimeInterval(Double(range.lo) * 3600)
        let slots = freeSlots(blocks, from: origin, to: dayStart.addingTimeInterval(Double(range.hi) * 3600))
        ScrollView {
            ZStack(alignment: .topLeading) {
                ForEach(range.lo...range.hi, id: \.self) { h in
                    HStack(alignment: .center, spacing: 8) {
                        Text(Fmt.hourLabel(h))
                            .font(.system(size: 11))
                            .foregroundColor(Palette.muted)
                            .frame(width: 44, alignment: .trailing)
                        Rectangle().fill(Palette.stroke).frame(height: 1)
                    }
                    .offset(y: CGFloat(h - range.lo) * hourHeight - 6)
                }
                ForEach(slots) { s in
                    Button {
                        onAdd(s.start, s.end)
                    } label: {
                        Text("Free time")
                            .font(.system(size: 12))
                            .foregroundColor(Palette.muted)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .foregroundColor(Color(hex: 0xE2D3CC))
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Add a time block here")
                    .frame(height: max(22, height(s.start, s.end) - 4))
                    .padding(.leading, 54)
                    .offset(y: y(s.start, origin) + 2)
                }
                ForEach(blocks) { b in
                    BlockCard(block: b, task: store.task(b.taskID), height: max(26, height(b.start, b.end) - 4), onEdit: { onEdit(b) })
                        .padding(.leading, 54)
                        .offset(y: y(b.start, origin) + 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: CGFloat(range.hi - range.lo) * hourHeight + 12, alignment: .topLeading)
            .padding(.top, 8)
        }
        .frame(maxHeight: .infinity)
        HStack {
            Spacer()
            Button {
                let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
                onAdd(start, start.addingTimeInterval(3600))
            } label: {
                Label("Add time block", systemImage: "plus.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.ink)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.blushLight))
    }

    private func hourRange(_ blocks: [TimeBlock]) -> (lo: Int, hi: Int) {
        var lo = 7, hi = 22
        for b in blocks {
            lo = min(lo, cal.component(.hour, from: b.start))
            let endHour = Int(ceil(b.end.timeIntervalSince(cal.startOfDay(for: day)) / 3600))
            hi = max(hi, min(24, endHour))
        }
        return (lo, hi)
    }

    private func y(_ d: Date, _ origin: Date) -> CGFloat {
        CGFloat(d.timeIntervalSince(origin) / 3600) * hourHeight
    }

    private func height(_ s: Date, _ e: Date) -> CGFloat {
        CGFloat(e.timeIntervalSince(s) / 3600) * hourHeight
    }

    private func freeSlots(_ blocks: [TimeBlock], from start: Date, to end: Date) -> [FreeSlot] {
        var out: [FreeSlot] = []
        var cursor = start
        for b in blocks.sorted(by: { $0.start < $1.start }) {
            if b.start.timeIntervalSince(cursor) >= 1800 {
                out.append(FreeSlot(start: cursor, end: b.start))
            }
            cursor = max(cursor, b.end)
        }
        if end.timeIntervalSince(cursor) >= 1800 {
            out.append(FreeSlot(start: cursor, end: end))
        }
        return out
    }
}

struct BlockCard: View {
    @EnvironmentObject var store: Store
    let block: TimeBlock
    let task: PlanTask?
    let height: CGFloat
    let onEdit: () -> Void

    private var icon: String {
        if let t = task { return t.icon }
        return block.kind == .rest ? "fork.knife" : "square.and.pencil"
    }

    var body: some View {
        let rest = block.kind == .rest
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: height > 40 ? 18 : 13))
                .foregroundColor(rest ? Palette.inkSoft : Palette.red)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                if height > 38 {
                    Text("\(Fmt.clockShort.string(from: block.start)) - \(Fmt.clockShort.string(from: block.end)) · \(block.seconds / 60) min")
                        .font(.system(size: 10))
                        .foregroundColor(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("Edit…") { onEdit() }
                Button("Delete", role: .destructive) { store.deleteBlock(block.id) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(rest ? Color(hex: 0xF1EBE8) : Palette.blush))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(rest ? Palette.muted.opacity(0.6) : Palette.red)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

struct WeekSchedule: View {
    @EnvironmentObject var store: Store
    let day: Date
    var onPick: (Date) -> Void
    private let cal = Calendar.current

    var body: some View {
        let week = cal.dateInterval(of: .weekOfYear, for: day)?.start ?? cal.startOfDay(for: day)
        let days: [Date] = (0..<7).compactMap { (i: Int) -> Date? in cal.date(byAdding: .day, value: i, to: week) }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(days, id: \.self) { d in
                    let blocks = store.blocks.filter { cal.isDate($0.start, inSameDayAs: d) }
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            onPick(d)
                        } label: {
                            HStack {
                                Text(Fmt.dayShort.string(from: d))
                                    .font(.system(size: 13, weight: cal.isDateInToday(d) ? .bold : .semibold))
                                    .foregroundColor(cal.isDateInToday(d) ? Palette.red : Palette.ink)
                                Spacer()
                                Text(blocks.isEmpty ? "Free" : Fmt.hm(blocks.reduce(0) { $0 + $1.seconds }))
                                    .font(.system(size: 11))
                                    .foregroundColor(Palette.muted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        ForEach(blocks) { b in
                            HStack(spacing: 8) {
                                Rectangle().fill(b.kind == .rest ? Palette.muted : Palette.red).frame(width: 3, height: 16)
                                Text(Fmt.clockShort.string(from: b.start))
                                    .font(.system(size: 11))
                                    .foregroundColor(Palette.muted)
                                    .frame(width: 36, alignment: .leading)
                                Text(b.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(Palette.ink)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.stroke))
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}
