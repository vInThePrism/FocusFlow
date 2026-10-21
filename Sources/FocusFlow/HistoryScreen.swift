import SwiftUI

struct HistoryGroup: Identifiable {
    let day: Date
    let records: [SessionRecord]
    var id: Date { day }

    var focusSeconds: Int {
        records.filter { $0.phase == .focus && $0.countsInStats }.reduce(0) { $0 + $1.activeSeconds }
    }

    static func make(_ records: [SessionRecord]) -> [HistoryGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: records) { cal.startOfDay(for: $0.start) }
        return grouped
            .map { HistoryGroup(day: $0.key, records: $0.value.sorted { $0.start < $1.start }) }
            .sorted { $0.day > $1.day }
    }
}

/// The values the manual-record panel edits.
struct ManualDraft: Identifiable {
    let id = UUID()
    var existing: SessionRecord?
    var day: Date
    var start: Date
    var end: Date
    var taskID: UUID?
    var note: String
    var counts: Bool
    var problemID: String? = nil

    static func fresh(taskID: UUID?) -> ManualDraft {
        let cal = Calendar.current
        let now = Date()
        let minute = cal.component(.minute, from: now)
        let end = cal.date(bySettingHour: cal.component(.hour, from: now), minute: minute - minute % 5, second: 0, of: now) ?? now
        let start = end.addingTimeInterval(-25 * 60)
        return ManualDraft(existing: nil, day: now, start: start, end: end, taskID: taskID, note: "", counts: true)
    }

    static func editing(_ r: SessionRecord) -> ManualDraft {
        ManualDraft(existing: r, day: r.start, start: r.start, end: r.end, taskID: r.taskID, note: r.note, counts: r.countsInStats, problemID: r.problemID)
    }
}

/// "History + Manual Log"
struct HistoryScreen: View {
    enum Filter: String, CaseIterable { case all = "All sessions", focus = "Focus only", manual = "Manual only" }

    @EnvironmentObject var store: Store
    @EnvironmentObject var engine: Engine
    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var collapsed: Set<Date> = []
    @State private var draft: ManualDraft?
    @State private var renaming: SessionRecord?
    @State private var renameText = ""
    @State private var deleting: SessionRecord?

    private func title(_ r: SessionRecord) -> String {
        if let p = store.leetcode.problem(r.problemID) { return p.displayTitle + (r.problemOutcome.map { " · " + ($0 == .skipped ? "Skipped result" : $0.title) } ?? "") }
        if let t = store.task(r.taskID) { return t.name }
        switch r.phase {
        case .focus: return r.intention.isEmpty ? (r.isManual ? "Manual focus" : "Focus session") : r.intention
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    private var visible: [SessionRecord] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return store.records.filter { r in
            switch filter {
            case .all: break
            case .focus: if r.phase != .focus || r.isManual { return false }
            case .manual: if !r.isManual { return false }
            }
            if q.isEmpty { return true }
            return title(r).lowercased().contains(q) || r.intention.lowercased().contains(q) || r.note.lowercased().contains(q)
        }
    }

    var body: some View {
        let groups = HistoryGroup.make(visible)
        VStack(alignment: .leading, spacing: 16) {
            header
            CapsuleTabs(items: Filter.allCases, selection: $filter, title: { $0.rawValue },
                        icon: { f in f == .all ? "square.stack" : (f == .focus ? "calendar" : "pencil") },
                        horizontalPadding: 22)
            table(groups)
        }
        .padding(EdgeInsets(top: 34, leading: 26, bottom: 0, trailing: 26))
        .overlay(alignment: .topTrailing) {
            if let d = draft {
                ManualRecordPanel(draft: d) { draft = nil }
                    .id(d.id)
                    .padding(.top, 70)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: draft?.id)
        .alert("Rename session", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Intention", text: $renameText)
            Button("Save") {
                if let r = renaming { store.rename(r.id, to: renameText) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("Delete this session?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let r = deleting { store.delete(r.id) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("It will be removed from History and stats. Yesterday's copy stays in Backups for 30 days.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus History")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Palette.ink)
                Text("View, edit, and add focus sessions.")
                    .font(.system(size: 14))
                    .foregroundColor(Palette.inkSoft)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Palette.inkSoft)
                TextField("Search sessions or tasks…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 14)
            .frame(width: 250, height: 38)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.stroke))
            Button {
                draft = ManualDraft.fresh(taskID: engine.linkedTaskID)
            } label: {
                Label("Add manual record", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func table(_ groups: [HistoryGroup]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Date").frame(width: 44, alignment: .leading)
                Text("Start time").frame(width: 100, alignment: .leading)
                Text("End time").frame(width: 100, alignment: .leading)
                Text("Duration").frame(width: 84, alignment: .leading)
                Text("Task").frame(maxWidth: .infinity, alignment: .leading)
                Text("Type").frame(width: 84, alignment: .leading)
                Spacer().frame(width: 34)
            }
            .font(.system(size: 12))
            .foregroundColor(Palette.inkSoft)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            Rectangle().fill(Palette.stroke).frame(height: 1)
            if groups.isEmpty {
                Text(search.isEmpty ? "No sessions yet. Finished pomodoros and manual records show up here." : "Nothing matches “\(search)”.")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.muted)
                    .padding(30)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups) { g in
                            groupHeader(g)
                            if !collapsed.contains(g.day) {
                                ForEach(g.records) { r in
                                    row(r)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.bottom, 20)
    }

    private func groupHeader(_ g: HistoryGroup) -> some View {
        Button {
            if collapsed.contains(g.day) { collapsed.remove(g.day) } else { collapsed.insert(g.day) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: collapsed.contains(g.day) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Palette.inkSoft)
                    .frame(width: 14)
                Text(Fmt.dayLong.string(from: g.day))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text("\(Fmt.hm(g.focusSeconds)) focus")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSoft)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ r: SessionRecord) -> some View {
        HStack(spacing: 0) {
            rowIcon(r).frame(width: 44, alignment: .leading)
            Text(Fmt.time.string(from: r.start)).frame(width: 100, alignment: .leading)
            Text(Fmt.time.string(from: r.end)).frame(width: 100, alignment: .leading)
            Text(Fmt.minutes(r.activeSeconds))
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 84, alignment: .leading)
            HStack(spacing: 6) {
                Text(title(r)).lineLimit(1)
                if !r.note.isEmpty {
                    Image(systemName: "note.text")
                        .font(.system(size: 10))
                        .foregroundColor(Palette.muted)
                        .help(r.note)
                }
                if r.phase == .focus && r.extendedSeconds >= 60 {
                    Text("+\(r.extendedSeconds / 60)m")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Palette.accentText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Palette.blush))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            typeBadge(r).frame(width: 84, alignment: .leading)
            rowMenu(r).frame(width: 34)
        }
        .font(.system(size: 13))
        .foregroundColor(Palette.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .opacity(r.countsInStats ? 1 : 0.5)
        .help(r.countsInStats ? "" : "Not counted in statistics")
        .contentShape(Rectangle())
        .contextMenu { menuItems(r) }
    }

    @ViewBuilder
    private func rowIcon(_ r: SessionRecord) -> some View {
        if r.isManual {
            Image(systemName: "pencil")
                .font(.system(size: 14))
                .foregroundColor(Palette.ink)
        } else if r.phase == .focus {
            LogoMark(size: 14)
        } else {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 12))
                .foregroundColor(Palette.inkSoft)
        }
    }

    private func typeBadge(_ r: SessionRecord) -> some View {
        let (label, fg, bg): (String, Color, Color) = r.isManual
            ? ("Manual", Palette.manualFg, Palette.manualBg)
            : (r.phase == .focus ? ("Focus", Palette.red, Palette.blush) : ("Break", Palette.inkSoft, Palette.restFill))
        return Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(bg))
    }

    private func rowMenu(_ r: SessionRecord) -> some View {
        Menu {
            menuItems(r)
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private func menuItems(_ r: SessionRecord) -> some View {
        if r.isManual {
            Button("Edit…") { draft = ManualDraft.editing(r) }
        } else if r.phase == .focus {
            Button("Rename…") {
                renameText = r.intention
                renaming = r
            }
        }
        if r.phase == .focus {
            Menu("Link to task") {
                Button("No task") { relink(r, nil) }
                ForEach(store.tasks) { t in
                    Button(t.name) { relink(r, t.id) }
                }
            }
        }
        Button(r.countsInStats ? "Exclude from statistics" : "Include in statistics") {
            store.setCountsInStats(r.id, !r.countsInStats)
        }
        Divider()
        Button("Delete…", role: .destructive) { deleting = r }
    }

    private func relink(_ r: SessionRecord, _ id: UUID?) {
        var copy = r
        copy.taskID = id
        store.upsert(copy)
    }
}

// MARK: - Add / edit a manual record

struct ManualRecordPanel: View {
    @EnvironmentObject var store: Store
    @State var draft: ManualDraft
    var onClose: () -> Void

    private var start: Date { combine(day: draft.day, time: draft.start) }
    private var end: Date { combine(day: draft.day, time: draft.end) }
    private var seconds: Int { Int(end.timeIntervalSince(start)) }
    private var valid: Bool { seconds >= 60 && seconds <= 16 * 3600 }

    /// Another counted focus session that overlaps this time, to warn about double counting.
    private var overlap: SessionRecord? {
        store.records.first { r in
            r.id != draft.existing?.id && r.phase == .focus && r.countsInStats && r.start < end && r.end > start
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.existing == nil ? "Add manual focus record" : "Edit manual record")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Text("Log a past focus session to keep your stats accurate.")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.inkSoft)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Palette.inkSoft)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FormField(label: "Date", icon: "calendar") {
                        DatePicker("", selection: $draft.day, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.field)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        FormField(label: "Start time", icon: "clock") {
                            DatePicker("", selection: $draft.start, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.field)
                            Spacer()
                        }
                        FormField(label: "End time", icon: "clock") {
                            DatePicker("", selection: $draft.end, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.field)
                            Spacer()
                        }
                    }
                    durationBox
                    FormField(label: "Task", icon: "scope") {
                        Picker("", selection: $draft.taskID) {
                            Text("No task").tag(UUID?.none)
                            ForEach(store.tasks) { t in
                                Text(t.name).tag(UUID?.some(t.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    Text("Link to a planned task to keep your data organized.")
                        .font(.system(size: 11))
                        .foregroundColor(Palette.muted)
                        .padding(.top, -8)
                    FormField(label: "LeetCode problem (optional)", icon: "chevron.left.forwardslash.chevron.right") {
                        Picker("Problem", selection: $draft.problemID) {
                            Text("No problem").tag(String?.none)
                            ForEach(store.leetcode.problems) { p in
                                Text(p.displayTitle).tag(String?.some(p.id))
                            }
                        }.labelsHidden().pickerStyle(.menu)
                    }
                    noteField
                    HStack(alignment: .top, spacing: 12) {
                        Toggle("", isOn: $draft.counts)
                            .toggleStyle(PillToggleStyle())
                            .labelsHidden()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include in statistics")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Palette.ink)
                            Text("Manual records count toward daily and monthly totals and task progress.")
                                .font(.system(size: 12))
                                .foregroundColor(Palette.inkSoft)
                        }
                    }
                    infoBox
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 12) {
                Button("Cancel", action: onClose)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                Button(draft.existing == nil ? "Add record" : "Save changes") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(!valid)
                    .opacity(valid ? 1 : 0.5)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 14)
        }
        .padding(24)
        .frame(width: 430)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.stroke))
        .shadow(color: Palette.panelShadow, radius: 24, y: 10)
    }

    private var durationBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Duration")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Palette.inkSoft)
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .foregroundColor(Palette.inkSoft)
                Text(valid ? durationText(seconds) : "—")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.ink)
                    .frame(minWidth: 110, alignment: .leading)
                VStack(spacing: 0) {
                    stepButton("chevron.up", 5)
                    stepButton("chevron.down", -5)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.stroke))
            .fixedSize()
            if !valid {
                Text("End time must be after start time (up to 16 hours).")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.accentText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.blushLight))
    }

    private func stepButton(_ icon: String, _ minutes: Int) -> some View {
        Button {
            let candidate = draft.end.addingTimeInterval(Double(minutes * 60))
            if combine(day: draft.day, time: candidate) > start {
                draft.end = candidate
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Palette.muted)
                .frame(width: 18, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note (optional)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Palette.inkSoft)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundColor(Palette.inkSoft)
                    .padding(.top, 8)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draft.note)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .frame(height: 54)
                        .onChange(of: draft.note) { v in
                            if v.count > 200 { draft.note = String(v.prefix(200)) }
                        }
                    if draft.note.isEmpty {
                        Text("e.g. Read and summarized key takeaways…")
                            .font(.system(size: 13).italic())
                            .foregroundColor(Palette.muted.opacity(0.7))
                            .padding(.top, 1)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.stroke))
            HStack {
                Spacer()
                Text("\(draft.note.count)/200")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.muted)
            }
        }
    }

    private var infoBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: overlap == nil ? "info.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(overlap == nil ? Palette.muted : Palette.orange)
            Text(infoText)
                .font(.system(size: 12))
                .foregroundColor(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.blushLight))
    }

    private var infoText: String {
        if let o = overlap {
            return "This overlaps a focus session from \(Fmt.time.string(from: o.start)) to \(Fmt.time.string(from: o.end)). Both will count unless you turn off statistics for one."
        }
        return draft.counts
            ? "This session will appear in your history and be included in your analytics."
            : "This session will appear in your history but won't change your analytics."
    }

    private func save() {
        guard valid else { return }
        let task = store.task(draft.taskID)
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = note.components(separatedBy: .newlines).first ?? ""
        let record = SessionRecord(
            id: draft.existing?.id ?? UUID(),
            phase: .focus,
            intention: task?.name ?? (firstLine.isEmpty ? "Manual focus" : String(firstLine.prefix(60))),
            start: start,
            end: end,
            plannedSeconds: seconds,
            extensionSeconds: 0,
            extensions: 0,
            activeSeconds: seconds,
            completed: true,
            taskID: draft.taskID,
            isManual: true,
            note: note,
            countsInStats: draft.counts,
            problemID: draft.problemID,
            problemOutcome: draft.problemID == nil ? nil : (draft.existing?.problemID == draft.problemID ? (draft.existing?.problemOutcome ?? .skipped) : .skipped)
        )
        store.upsert(record)
        onClose()
    }
}
