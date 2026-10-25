import SwiftUI
import Charts

struct InterviewItemEditor: View {
    @Binding var items: [InterviewDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($items) { $item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Picker("Type", selection: $item.category) {
                            Text("Choose type (optional)").tag(InterviewCategory?.none)
                            ForEach(InterviewCategory.allCases) { category in
                                Text(category.title).tag(InterviewCategory?.some(category))
                            }
                        }
                        .onChange(of: item.category) { category in
                            if let category { UserDefaults.standard.set(category.rawValue, forKey: InterviewCategory.preferenceKey) }
                        }
                        if items.count > 1 {
                            Button { items.removeAll { $0.id == item.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.plain).accessibilityLabel("Remove item")
                        }
                    }
                    HStack {
                        TextField("Quantity", value: $item.quantity, format: .number)
                            .frame(width: 75).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Quantity for \(item.category?.title ?? "preparation")")
                        Stepper("Quantity", value: $item.quantity, in: 0...Int.max).labelsHidden()
                            .accessibilityLabel("Adjust quantity")
                        Text(item.category?.unit ?? "items").font(.caption).foregroundColor(Palette.inkSoft)
                        Spacer()
                    }
                    TextField("Notes (optional)", text: $item.notes).textFieldStyle(.roundedBorder)
                    if !item.valid { Text("Enter a non-negative whole number.").font(.caption).foregroundColor(Palette.accentText) }
                }
                .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
            }
            Button { items.append(InterviewDraft()) } label: { Label("Add item", systemImage: "plus") }
                .buttonStyle(.link)
        }
    }
}

struct InterviewQuickLog: View {
    @EnvironmentObject var store: Store
    let session: SessionRecord
    let onClose: () -> Void
    @State private var items = [InterviewDraft()]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Log Interview Preparation").font(.title2.bold())
            Text("\(Fmt.hm(session.activeSeconds)) focus saved · \(Fmt.dayLong.string(from: session.start))")
                .foregroundColor(Palette.inkSoft)
            Text("Preparation details are optional. Skipping keeps your focus time.").font(.caption).foregroundColor(Palette.inkSoft)
            ScrollView { InterviewItemEditor(items: $items) }.frame(maxHeight: 330)
            HStack {
                Button("Skip", action: onClose).buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    store.addInterviewItems(items, to: session, source: .focusCompletion)
                    onClose()
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(!items.allSatisfy(\.valid))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26).frame(width: 500).foregroundColor(Palette.ink).background(Palette.canvas)
    }
}

struct InterviewPreparationDetails: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var nav: Nav
    @Environment(\.dismiss) private var dismiss
    let task: PlanTask
    @State private var editing: InterviewEntry?

    var body: some View {
        let summary = store.interviewSummary(taskID: task.id, sessions: store.merged(with: engine.liveRecord))
        let today = Analytics(records: []).period(.day, Date())
        let recent = store.interviewEntries.filter { $0.taskID == task.id }.sorted { $0.occurredAt > $1.occurredAt }
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(task.name).font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Today · \(Fmt.hm(summary.focusSeconds(in: today))) focus").foregroundColor(Palette.inkSoft)
            InterviewCounts(summary: summary, range: today)
            HStack {
                Button("Start Focus") {
                    guard engine.state == .idle, store.task(task.id) != nil else { return }
                    engine.select(.focus)
                    engine.link(store.task(task.id))
                    engine.start()
                    nav.page = .focus
                    dismiss()
                }.buttonStyle(PrimaryButtonStyle()).disabled(engine.state != .idle || store.task(task.id) == nil)
                if engine.state != .idle { Text("Finish the current timer to start a new focus.").font(.caption).foregroundColor(Palette.inkSoft) }
            }
            Text("Recent preparation").font(.headline)
            if recent.isEmpty { Text("No preparation details yet. You can log them after focus or from History.").font(.caption).foregroundColor(Palette.inkSoft) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(recent.prefix(20))) { entry in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(entry.category.title) · \(entry.quantity) \(entry.category.unit)").font(.subheadline.bold())
                                Text(Fmt.dayLong.string(from: entry.occurredAt)).font(.caption).foregroundColor(Palette.inkSoft)
                                if !entry.notes.isEmpty { Text(entry.notes).font(.caption).foregroundColor(Palette.inkSoft) }
                            }
                            Spacer()
                            Button("Edit") { editing = entry }.buttonStyle(.link)
                            Button("Delete", role: .destructive) { store.deleteInterviewEntry(entry.id) }.buttonStyle(.link)
                        }.padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
                    }
                }
            }.frame(height: 260)
        }
        .padding(26).frame(width: 630).foregroundColor(Palette.ink).background(Palette.canvas)
        .sheet(item: $editing) { entry in
            InterviewEntryEditor(entry: entry).environmentObject(store)
        }
    }
}

struct InterviewEntryEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var entry: InterviewEntry
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit preparation record").font(.title2.bold())
            Picker("Type", selection: $entry.category) {
                ForEach(InterviewCategory.allCases) { Text($0.title).tag($0) }
            }
            TextField("Quantity (0 removes record)", value: $entry.quantity, format: .number).textFieldStyle(.roundedBorder)
            if entry.sessionID == nil { DatePicker("Date", selection: $entry.occurredAt, displayedComponents: .date) }
            else { Text("Date follows its focus session: \(Fmt.dayLong.string(from: entry.occurredAt))").font(.caption).foregroundColor(Palette.inkSoft) }
            TextField("Notes (optional)", text: $entry.notes).textFieldStyle(.roundedBorder)
            if let error { Text(error).font(.caption).foregroundColor(Palette.accentText) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    if entry.quantity == 0 { store.deleteInterviewEntry(entry.id); dismiss() }
                    else if store.saveInterviewEntry(entry) { dismiss() }
                    else { error = "The linked task or session no longer exists." }
                }.buttonStyle(PrimaryButtonStyle()).disabled(entry.quantity < 0).keyboardShortcut(.defaultAction)
            }
        }.padding(26).frame(width: 470).foregroundColor(Palette.ink).background(Palette.canvas)
    }
}

struct InterviewCounts: View {
    let summary: InterviewSummary
    let range: DateInterval
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], alignment: .leading, spacing: 12) {
            ForEach(InterviewCategory.allCases) { category in
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title).font(.caption).foregroundColor(Palette.inkSoft)
                    Text("\(summary.total(category, in: range)) \(category.unit)").font(.system(size: 15, weight: .semibold))
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
            }
        }
    }
}

struct InterviewStatsSection: View {
    @EnvironmentObject var store: Store
    let scope: StatsScope
    let anchor: Date
    @State private var expanded = true

    var body: some View {
        let summary = store.interviewSummary()
        let range = Analytics(records: []).period(scope, anchor)
        if store.tasks.contains(where: \.isInterviewPreparation) {
            CardBox(spacing: 12) {
                DisclosureGroup(isExpanded: $expanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Interview focus time · \(Fmt.hm(summary.focusSeconds(in: range)))").font(.subheadline).foregroundColor(Palette.inkSoft)
                        InterviewCounts(summary: summary, range: range)
                        if summary.entries(in: range).isEmpty {
                            Text("No preparation details in this period.").font(.caption).foregroundColor(Palette.muted)
                        } else {
                            trend(summary: summary, range: range)
                        }
                    }.padding(.top, 12)
                } label: { Text("Interview Preparation").font(.headline) }
            }
        }
    }

    private func trend(summary: InterviewSummary, range: DateInterval) -> some View {
        let calendar = Calendar.current
        let component: Calendar.Component = scope == .year ? .weekOfYear : .day
        let grouped = Dictionary(grouping: summary.entries(in: range)) {
            calendar.dateInterval(of: component, for: $0.occurredAt)?.start ?? calendar.startOfDay(for: $0.occurredAt)
        }
        return Chart {
            ForEach(grouped.keys.sorted(), id: \.self) { day in
                ForEach(InterviewCategory.allCases) { category in
                    let total = InterviewSummary(entries: grouped[day] ?? [], sessions: []).total(category, in: range)
                    if total > 0 {
                        BarMark(x: .value("Date", day, unit: component), y: .value("Count", total))
                            .foregroundStyle(by: .value("Type", category.title))
                            .accessibilityLabel("\(Fmt.dayShort.string(from: day)), \(category.title)")
                            .accessibilityValue("\(total) \(category.unit)")
                    }
                }
            }
        }
        .chartForegroundStyleScale(domain: InterviewCategory.allCases.map(\.title), range: [Palette.red, Palette.orange, Palette.green, Palette.accentText, Palette.muted])
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 165)
    }
}

/// Reuses the same item editor for additions and the existing entry editor for corrections.
struct InterviewSessionEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let session: SessionRecord
    @State private var items = [InterviewDraft()]
    @State private var editing: InterviewEntry?
    @State private var adding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preparation details").font(.title2.bold())
            Text(Fmt.dayLong.string(from: session.start)).font(.caption).foregroundColor(Palette.inkSoft)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.interviewEntries.filter { $0.sessionID == session.id }) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(entry.category.title) · \(entry.quantity) \(entry.category.unit)")
                                if !entry.notes.isEmpty { Text(entry.notes).font(.caption).foregroundColor(Palette.inkSoft) }
                            }
                            Spacer()
                            Button("Edit") { editing = entry }
                            Button("Delete", role: .destructive) { store.deleteInterviewEntry(entry.id) }
                        }
                    }
                    DisclosureGroup("Add preparation details", isExpanded: $adding) {
                        InterviewItemEditor(items: $items).padding(.top, 10)
                    }
                }
            }.frame(maxHeight: 360)
            HStack {
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if adding {
                    Button("Save items") {
                        store.addInterviewItems(items, to: session, source: .manual)
                        dismiss()
                    }.buttonStyle(PrimaryButtonStyle()).disabled(!items.allSatisfy(\.valid))
                }
            }
        }.padding(26).frame(width: 550).foregroundColor(Palette.ink).background(Palette.canvas)
            .sheet(item: $editing) { entry in InterviewEntryEditor(entry: entry).environmentObject(store) }
    }
}
