import SwiftUI
import UniformTypeIdentifiers

struct LCImportSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case common = "Common list", url = "List URL", file = "CSV / JSON", links = "Problem links", single = "Single problem"
        var id: String { rawValue }
    }
    struct Request: Identifiable {
        let id = UUID()
        var mode: Mode
        var preset: LCCommonList? = nil
        var number = ""
    }

    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var mode: Mode
    var preset: LCCommonList?
    var initialProblemNumber = ""
    var onImported: (String, [String]) -> Void
    @State private var problemNumber = ""
    @State private var name = "My problem list"
    @State private var text = ""
    @State private var title = ""
    @State private var difficulty: LCDifficulty = .unknown
    @State private var topics = ""
    @State private var preview: LCImportPreview?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Import LeetCode problems").font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Picker("Import method", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if mode != .common && mode != .single && mode != .url { TextField("List name", text: $name) }
                    inputs
                    if let error = error { Text(error).foregroundColor(Palette.orange).font(.caption) }
                    if let preview = preview { previewView(preview) }
                }.padding(2)
            }
            HStack {
                Text("Existing notes, results and focus history are kept.").font(.caption).foregroundColor(Palette.inkSoft)
                Spacer()
                Button("Confirm import") {
                    guard let p = preview, !p.problems.isEmpty, !p.name.isEmpty else { return }
                    guard let id = store.importProblems(p) else { return }
                    onImported(id, p.problems.map(\.id))
                    dismiss()
                }.buttonStyle(PrimaryButtonStyle(compact: true))
                    .disabled(preview?.problems.isEmpty != false || preview?.name.isEmpty != false)
            }
        }.padding(24).frame(width: 680, height: 610)
            .foregroundColor(Palette.ink).background(Palette.canvas)
            .textFieldStyle(.roundedBorder)
            .onAppear {
                if mode == .single { problemNumber = initialProblemNumber }
                if let preset = preset { preview = LCImporter.common(preset, existing: store.leetcode.problems) }
            }
            .onChange(of: mode) { _ in invalidate() }
            .onChange(of: text) { _ in invalidate() }
            .onChange(of: problemNumber) { _ in invalidate() }
            .onChange(of: name) { _ in invalidate() }
            .onChange(of: title) { _ in invalidate() }
            .onChange(of: topics) { _ in invalidate() }
            .onChange(of: difficulty) { _ in invalidate() }
    }

    @ViewBuilder private var inputs: some View {
        switch mode {
        case .common:
            Text("Choose a common list").font(.headline)
            ForEach(LCCatalog.lists) { list in
                Button {
                    preview = LCImporter.common(list, existing: store.leetcode.problems); error = nil
                } label: {
                    HStack { Label(list.name, systemImage: "books.vertical"); Spacer(); Text("\(list.problemIDs.count) problems") }
                        .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                }.buttonStyle(.plain)
            }
            Text("Bundled offline snapshot · NeetCode / MIT · \(String(LCCatalog.revision.prefix(8)))").font(.caption2).foregroundColor(Palette.muted)
            Link("View data source and version", destination: URL(string: LCCatalog.source)!)
        case .url:
            TextField("Public list URL", text: $text)
            Text("Supports the bundled NeetCode 150 and Blind 75 URLs. Imports the verified offline snapshot, not a live page. Other public/share links may require CSV/JSON or problem links.")
                .font(.caption).foregroundColor(Palette.inkSoft)
            Button("Preview list") { perform { try LCImporter.listURL(text, existing: store.leetcode.problems) } }
        case .file:
            Text("Upload CSV / JSON").font(.headline)
            Text("Fields: url, title, difficulty, topics. Known problems may use id instead. CSV topics use semicolons; JSON topics may be an array. Unknown problems require url and title.")
                .font(.caption).foregroundColor(Palette.inkSoft)
            Button("Choose file…") { chooseFile() }
        case .links:
            Text("One LeetCode problem URL or known problem number per line.").font(.subheadline)
            TextEditor(text: $text).font(.system(size: 13)).frame(height: 140)
            Text("Unknown links or numbers are reported below; use Single problem to supply their title and metadata.")
                .font(.caption).foregroundColor(Palette.inkSoft)
            Button("Preview problems") {
                preview = LCImporter.links(text, name: name, existing: store.leetcode.problems); error = nil
            }
        case .single:
            TextField("Problem number (optional)", text: $problemNumber)
            TextField("LeetCode problem URL", text: $text)
            TextField("Title (required for an unknown problem)", text: $title)
            Picker("Difficulty", selection: $difficulty) { ForEach(LCDifficulty.allCases) { Text($0.rawValue).tag($0) } }
            TextField("Topics, separated by commas (optional)", text: $topics)
            Text("Known problems use their saved metadata. The problem is added to Manual imports, where you can record results and notes immediately.")
                .font(.caption).foregroundColor(Palette.inkSoft)
            Button("Preview problem") {
                perform {
                    let p = try LCImporter.manual(url: text, title: title, difficulty: difficulty, topics: topics, existing: store.leetcode.problems, number: problemNumber)
                    return LCImporter.preview(name: "Manual imports", source: "Manual import", listID: "manual", problems: [p], existing: store.leetcode.problems)
                }
            }
        }
    }

    private func previewView(_ p: LCImportPreview) -> some View {
        CardBox(padding: 14, spacing: 8) {
            Text(p.name.isEmpty ? "Enter a list name before importing" : p.name).font(.headline)
            Text("\(p.problems.count) recognized · \(p.duplicates) duplicates / existing · \(p.rejected.count) unrecognized")
                .font(.caption).foregroundColor(Palette.inkSoft)
            Text("Existing problems will be linked to the list, without replacing progress.").font(.caption2).foregroundColor(Palette.muted)
            ForEach(Array(p.problems.prefix(5))) { Text($0.displayTitle).font(.caption) }
            if p.problems.count > 5 { Text("… and \(p.problems.count - 5) more").font(.caption) }
            ForEach(Array(p.rejected.prefix(5).enumerated()), id: \.offset) { _, message in
                Text(message).font(.caption).foregroundColor(Palette.orange).lineLimit(2)
            }
        }
    }
    private func invalidate() { preview = nil; error = nil }
    private func perform(_ action: () throws -> LCImportPreview) {
        do { preview = try action(); error = nil } catch { preview = nil; self.error = error.localizedDescription }
    }
    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform { try LCImporter.file(url, name: name, existing: store.leetcode.problems) }
    }
}
