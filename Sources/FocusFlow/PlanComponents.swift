import SwiftUI

// MARK: - Small pieces shared by Plan, Calendar, Focus and History

func combine(day: Date, time: Date) -> Date {
    let cal = Calendar.current
    let t = cal.dateComponents([.hour, .minute], from: time)
    return cal.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day) ?? day
}

func durationText(_ seconds: Int) -> String {
    let m = max(0, seconds) / 60
    if m < 60 { return "\(m) min" }
    let h = m / 60, r = m % 60
    return r == 0 ? (h == 1 ? "1 hour" : "\(h) hours") : "\(h) hour\(h == 1 ? "" : "s") \(r) min"
}

/// Mon…Sun chips. Tap to toggle when `onToggle` is set.
struct WeekdayChips: View {
    enum Style { case letter, short }

    var selected: Set<Int>
    var today: Int? = nil
    var style: Style = .short
    var onToggle: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: style == .short ? 5 : 4) {
            ForEach(Weekdays.order, id: \.self) { w in
                chip(w)
            }
        }
    }

    @ViewBuilder
    private func chip(_ w: Int) -> some View {
        let on = selected.contains(w)
        let isToday = today == w
        let label = Text(style == .short ? Weekdays.short(w) : Weekdays.letter(w))
            .font(.system(size: style == .short ? 11 : 10, weight: .medium))
            .foregroundColor(chipText(on: on, isToday: isToday))
            .frame(width: style == .short ? 34 : 22, height: style == .short ? 22 : 18)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(chipFill(on: on, isToday: isToday))
            )
        if let toggle = onToggle {
            Button { toggle(w) } label: { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private func chipFill(on: Bool, isToday: Bool) -> AnyShapeStyle {
        if style == .short {
            return on ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.chipOff)
        }
        if isToday && on { return AnyShapeStyle(Palette.redGradient) }
        if on { return AnyShapeStyle(Palette.blush) }
        return AnyShapeStyle(Palette.chipOff)
    }

    private func chipText(on: Bool, isToday: Bool) -> Color {
        if style == .short { return on ? .white : Palette.muted }
        if isToday && on { return .white }
        return on ? Palette.red : Palette.muted.opacity(0.8)
    }
}

/// Done = filled check, in progress = partial ring, not started = empty circle.
struct TaskStatusCircle: View {
    var fraction: Double
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            if fraction >= 1 {
                Circle().fill(Palette.redGradient)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Circle().stroke(fraction > 0 ? Palette.track : Palette.circleOff, lineWidth: size * 0.1)
                if fraction > 0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(fraction))
                        .stroke(Palette.red, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct FormField<Content: View>: View {
    let label: String
    var icon: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Palette.inkSoft)
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Palette.inkSoft)
                }
                content()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.stroke))
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 8 : 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.redGradient))
            .shadow(color: Palette.red.opacity(0.25), radius: 6, y: 3)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(Palette.ink)
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.stroke))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Segmented capsule tabs in the house style.
struct CapsuleTabs<T: Hashable>: View {
    let items: [T]
    @Binding var selection: T
    let title: (T) -> String
    var icon: ((T) -> String)? = nil
    var horizontalPadding: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let on = selection == item
                Button {
                    selection = item
                } label: {
                    HStack(spacing: 7) {
                        if let icon = icon {
                            Image(systemName: icon(item)).font(.system(size: 13, weight: .medium))
                        }
                        Text(title(item)).font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(on ? .white : Palette.inkSoft)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(on ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Color.clear))
                            .shadow(color: on ? Palette.red.opacity(0.25) : .clear, radius: 5, y: 2)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Palette.tabTrack))
    }
}

struct DayNavigator: View {
    @Binding var day: Date
    var allowFuture = true

    var body: some View {
        HStack {
            arrow("chevron.left", -1)
            Spacer()
            Button {
                day = Date()
            } label: {
                Text(Fmt.dayLong.string(from: day))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.ink)
            }
            .buttonStyle(.plain)
            .help("Back to today")
            Spacer()
            arrow("chevron.right", 1)
        }
    }

    private func arrow(_ name: String, _ delta: Int) -> some View {
        Button {
            if let d = Calendar.current.date(byAdding: .day, value: delta, to: day) {
                day = allowFuture ? d : min(d, Date())
            }
        } label: {
            Image(systemName: name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Palette.accentText)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Palette.surface))
                .overlay(Circle().strokeBorder(Palette.stroke))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editors

struct TaskEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var task: PlanTask
    let isNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New daily task" : "Edit task")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Palette.ink)
            FormField(label: "Name") {
                TextField("e.g. LeetCode Practice", text: $task.name)
                    .textFieldStyle(.plain)
                    .onChange(of: task.name) { name in
                        if isNew { task.icon = TaskIcons.guess(name) }
                    }
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time per day").font(.system(size: 12, weight: .medium)).foregroundColor(Palette.inkSoft)
                    ValueStepper(value: $task.minutes, range: 15...960, step: 15, width: 130, format: { Fmt.hm($0 * 60) })
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active").font(.system(size: 12, weight: .medium)).foregroundColor(Palette.inkSoft)
                    Toggle("", isOn: $task.enabled).toggleStyle(PillToggleStyle()).labelsHidden()
                }
            }
            FormField(label: "Note (optional)") {
                TextField("What this covers", text: $task.note)
                    .textFieldStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Repeat on").font(.system(size: 12, weight: .medium)).foregroundColor(Palette.inkSoft)
                WeekdayChips(selected: task.weekdays) { w in
                    if task.weekdays.contains(w) { task.weekdays.remove(w) } else { task.weekdays.insert(w) }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon").font(.system(size: 12, weight: .medium)).foregroundColor(Palette.inkSoft)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 8), count: 9), alignment: .leading, spacing: 8) {
                    ForEach(TaskIcons.all, id: \.self) { icon in
                        Button {
                            task.icon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .foregroundColor(task.icon == icon ? .white : Palette.red)
                                .frame(width: 34, height: 30)
                                .background(RoundedRectangle(cornerRadius: 8).fill(task.icon == icon ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.blushLight)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                if !isNew {
                    Button("Delete") {
                        store.deleteTask(task.id)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Palette.accentText)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                Button(isNew ? "Add task" : "Save") {
                    task.name = task.name.trimmingCharacters(in: .whitespaces)
                    store.saveTask(task)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(task.name.trimmingCharacters(in: .whitespaces).isEmpty || task.weekdays.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Palette.card)
        .preferredColorScheme(ColorTheme.current.scheme)
    }
}

struct BlockEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var block: TimeBlock
    let isNew: Bool
    @State var startTime = Date()
    @State var endTime = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "Add time block" : "Edit time block")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Palette.ink)
            Text(Fmt.dayLong.string(from: block.start))
                .font(.system(size: 12))
                .foregroundColor(Palette.inkSoft)
            FormField(label: "What") {
                TextField("e.g. Lunch, Course Study", text: $block.title)
                    .textFieldStyle(.plain)
            }
            FormField(label: "Counts toward task") {
                Picker("", selection: $block.taskID) {
                    Text("No task").tag(UUID?.none)
                    ForEach(store.tasks) { t in
                        Text(t.name).tag(UUID?.some(t.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: block.taskID) { id in
                    if let t = store.task(id), block.title.trimmingCharacters(in: .whitespaces).isEmpty {
                        block.title = t.name
                    }
                    if id != nil { block.kind = .activity }
                }
            }
            HStack(spacing: 12) {
                FormField(label: "Start", icon: "clock") {
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
                FormField(label: "End", icon: "clock") {
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
            }
            HStack {
                Text("Break / rest").font(.system(size: 13)).foregroundColor(Palette.ink)
                Spacer()
                Toggle("", isOn: Binding(get: { block.kind == .rest }, set: { block.kind = $0 ? .rest : .activity }))
                    .toggleStyle(PillToggleStyle())
                    .labelsHidden()
            }
            if !valid {
                Text("End time must be after start time.")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.accentText)
            }
            HStack {
                if !isNew {
                    Button("Delete") {
                        store.deleteBlock(block.id)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Palette.accentText)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                Button(isNew ? "Add" : "Save") {
                    var b = block
                    b.start = combine(day: block.start, time: startTime)
                    b.end = combine(day: block.start, time: endTime)
                    if b.title.trimmingCharacters(in: .whitespaces).isEmpty {
                        b.title = b.kind == .rest ? "Break" : "Untitled"
                    }
                    store.saveBlock(b)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!valid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 380)
        .background(Palette.card)
        .preferredColorScheme(ColorTheme.current.scheme)
        .onAppear {
            startTime = block.start
            endTime = block.end
        }
    }

    private var valid: Bool {
        combine(day: block.start, time: endTime) > combine(day: block.start, time: startTime)
    }
}

struct DeadlineEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var deadline: Deadline
    let isNew: Bool
    @State var day = Date()
    @State var time = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "Add deadline" : "Edit deadline")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Palette.ink)
            FormField(label: "Title") {
                TextField("e.g. Design essay draft", text: $deadline.title)
                    .textFieldStyle(.plain)
            }
            FormField(label: "Note (optional)") {
                TextField("e.g. Write 1,000 words", text: $deadline.note)
                    .textFieldStyle(.plain)
            }
            HStack(spacing: 12) {
                FormField(label: "Date", icon: "calendar") {
                    DatePicker("", selection: $day, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
                FormField(label: "Time", icon: "clock") {
                    Toggle("", isOn: $deadline.hasTime).toggleStyle(.checkbox).labelsHidden()
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .disabled(!deadline.hasTime)
                        .opacity(deadline.hasTime ? 1 : 0.4)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Type").font(.system(size: 12, weight: .medium)).foregroundColor(Palette.inkSoft)
                HStack(spacing: 6) {
                    ForEach(Deadline.Kind.allCases) { k in
                        let on = deadline.kind == k
                        Button {
                            deadline.kind = k
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: k.icon).font(.system(size: 10))
                                Text(k.label).font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(on ? .white : Palette.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(on ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.blushLight)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                if !isNew {
                    Button("Delete") {
                        store.deleteDeadline(deadline.id)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Palette.accentText)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                Button(isNew ? "Add" : "Save") {
                    var d = deadline
                    d.date = d.hasTime ? combine(day: day, time: time) : Calendar.current.startOfDay(for: day)
                    d.title = d.title.trimmingCharacters(in: .whitespaces)
                    store.saveDeadline(d)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(deadline.title.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(Palette.card)
        .preferredColorScheme(ColorTheme.current.scheme)
        .onAppear {
            day = deadline.date
            time = deadline.hasTime ? deadline.date : (Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: deadline.date) ?? deadline.date)
        }
    }
}

/// Drives a BlockEditor sheet for a new or existing block.
struct BlockSheet: Identifiable {
    let block: TimeBlock
    let isNew: Bool
    var id: UUID { block.id }
}

struct DeadlineSheet: Identifiable {
    let deadline: Deadline
    let isNew: Bool
    var id: UUID { deadline.id }
}

/// Small completion ring used on calendar days and summaries.
struct CompletionRing: View {
    var fraction: Double
    var size: CGFloat = 22
    var lineWidth: CGFloat = 3.5

    var body: some View {
        ZStack {
            Circle().stroke(Palette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, fraction))))
                .stroke(Palette.redGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
