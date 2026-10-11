import SwiftUI

struct HistoryGroup: Identifiable {
    let day: Date
    let records: [SessionRecord]
    var id: Date { day }

    var focusSeconds: Int { records.filter { $0.phase == .focus }.reduce(0) { $0 + $1.activeSeconds } }
    var focusCount: Int { records.filter { $0.phase == .focus }.count }

    static func make(_ records: [SessionRecord]) -> [HistoryGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: records) { cal.startOfDay(for: $0.start) }
        return grouped
            .map { HistoryGroup(day: $0.key, records: $0.value.sorted { $0.start > $1.start }) }
            .sorted { $0.day > $1.day }
    }
}

struct HistoryScreen: View {
    @EnvironmentObject var store: Store
    @State private var renaming: SessionRecord?
    @State private var renameText = ""
    @State private var deleting: SessionRecord?

    var body: some View {
        let groups = HistoryGroup.make(store.records)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Text("Every session is saved on this Mac — \(store.records.count) so far.")
                        .font(.system(size: 14))
                        .foregroundColor(Palette.inkSoft)
                }
                Spacer()
                Button("Export…") { DataActions.exportJSON(store) }
                    .buttonStyle(SmallButtonStyle())
                MoreMenu()
            }

            if groups.isEmpty {
                CardBox {
                    Text("No sessions yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Palette.ink)
                    Text("Finished focus sessions and breaks will show up here, grouped by day.")
                        .font(.system(size: 13))
                        .foregroundColor(Palette.inkSoft)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groups) { g in
                            daySection(g)
                        }
                    }
                    .padding(.bottom, 24)
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(EdgeInsets(top: 34, leading: 28, bottom: 0, trailing: 28))
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
            Text("It will be removed from your stats. Yesterday's copy stays in Backups for 30 days.")
        }
    }

    private func dayTitle(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        return Fmt.dayLong.string(from: d)
    }

    private func daySection(_ g: HistoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayTitle(g.day))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text("\(Fmt.hm(g.focusSeconds)) focus · \(g.focusCount) \(g.focusCount == 1 ? "session" : "sessions")")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSoft)
            }
            VStack(spacing: 0) {
                ForEach(Array(g.records.enumerated()), id: \.element.id) { idx, r in
                    if idx > 0 {
                        Rectangle().fill(Palette.stroke).frame(height: 1).padding(.leading, 38)
                    }
                    HistoryRow(record: r)
                        .contextMenu {
                            if r.phase == .focus {
                                Button("Rename…") {
                                    renameText = r.intention
                                    renaming = r
                                }
                            }
                            Button("Delete…", role: .destructive) { deleting = r }
                        }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.stroke))
        }
    }
}

struct HistoryRow: View {
    let record: SessionRecord

    private var title: String {
        switch record.phase {
        case .focus: return record.intention.isEmpty ? "Focus session" : record.intention
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: record.phase == .focus ? "scope" : record.phase.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(record.phase == .focus ? Palette.red : Palette.inkSoft)
                .frame(width: 24, height: 24)
                .background(Circle().fill(record.phase == .focus ? Palette.blush : Color(hex: 0xF4ECE8)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                Text("\(Fmt.time.string(from: record.start)) – \(Fmt.time.string(from: record.end))")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.muted)
            }
            Spacer()
            if record.extensions > 0 {
                tag("+\(record.extensionSeconds / 60) min · \(record.extensions)×", fill: Palette.blush, text: Palette.red)
            }
            if record.phase == .focus && !record.completed {
                tag("Ended early", fill: Color(hex: 0xF4ECE8), text: Palette.inkSoft)
            }
            Text(Fmt.hm(record.activeSeconds))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.ink)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func tag(_ text: String, fill: Color, text color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(fill))
    }
}
