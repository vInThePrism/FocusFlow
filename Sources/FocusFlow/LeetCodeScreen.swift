import SwiftUI

struct LeetCodeScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var nav: Nav
    @State private var importRequest: LCImportSheet.Request?
    @State private var selectedID: String?
    @State private var listID: String?
    @State private var reviewing = false
    @State private var topic = "Any topic"
    @State private var count = 3
    @State private var regenerate = false
    @State private var busy = false
    @State private var search = ""
    @State private var browsingTopic = false

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var searchResults: [LCProblem] {
        let number = Int(query).map(String.init)
        return store.leetcode.problems.filter {
            if let number = number { return $0.number == number }
            return $0.title.localizedCaseInsensitiveContains(query)
        }.sorted { (Int($0.number ?? "") ?? Int.max, $0.title) < (Int($1.number ?? "") ?? Int.max, $1.title) }
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        searchField
                        if query.isEmpty {
                            lists
                            practice(context.date)
                            reviewCard(context.date)
                        }
                        if geometry.size.width >= 1000 {
                            HStack(alignment: .top, spacing: 16) {
                                problemList(context.date)
                                if let p = store.leetcode.problem(selectedID) {
                                    LCProblemDetails(problem: p, reviewing: reviewing, onFocus: { start(p) }).frame(width: 340)
                                }
                            }
                        } else {
                            problemList(context.date)
                            if let p = store.leetcode.problem(selectedID) {
                                LCProblemDetails(problem: p, reviewing: reviewing, onFocus: { start(p) })
                            }
                        }
                        if let error = store.problem { Text(error).font(.caption).foregroundColor(Palette.orange) }
                    }
                    .padding(26)
                }
            }
        }
        .onAppear { topic = store.leetcode.topic; count = store.leetcode.targetCount }
        .sheet(item: $importRequest) { request in
            LCImportSheet(mode: request.mode, preset: request.preset, initialProblemNumber: request.number) { importedListID, ids in
                selectedID = ids.first
                listID = importedListID
                reviewing = false
                browsingTopic = false
                search = ""
            }.environmentObject(store)
        }
        .alert("Generate a new queue?", isPresented: $regenerate) {
            Button("Generate") { generate() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Today's displayed queue will be replaced. Your completed problems, attempts, notes and focus history are kept.")
        }
        .alert("A timer is already active", isPresented: $busy) {
            Button("Open Focus") { nav.page = .focus }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Finish the current session before starting another problem. Its existing association will be kept.") }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("LeetCode").font(.system(size: 28, weight: .bold)).foregroundColor(Palette.ink)
                Text("A little progress every day.").foregroundColor(Palette.inkSoft)
            }
            Spacer()
            Button("Import problem") { openSingleImport() }
                .buttonStyle(SecondaryButtonStyle())
            Button("Import list") { importRequest = LCImportSheet.Request(mode: .common) }
                .buttonStyle(PrimaryButtonStyle(compact: true))
            MoreMenu()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(Palette.inkSoft)
            TextField("Search by problem number or title", text: $search)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search problems")
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundColor(Palette.muted).help("Clear search")
            }
        }.padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.stroke))
    }

    private var lists: some View {
        CardBox(spacing: 12) {
            HStack {
                Text("My Lists / Common Lists").font(.headline)
                Spacer()
                Menu("View all lists") {
                    ForEach(store.leetcode.lists) { list in
                        Button(list.name) { showList(list) }
                    }
                }.disabled(store.leetcode.lists.isEmpty)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                ForEach(LCCatalog.lists) { common in
                    let added = store.leetcode.lists.first { $0.id == common.id }
                    Button {
                        if let added = added { showList(added) }
                        else { importRequest = LCImportSheet.Request(mode: .common, preset: common) }
                    } label: {
                        listLabel(common.name, ids: added?.problemIDs ?? common.problemIDs, added: added != nil)
                    }.buttonStyle(.plain)
                }
                ForEach(Array(store.leetcode.lists.filter { list in !LCCatalog.lists.contains { $0.id == list.id } }.prefix(2))) { list in
                    Button { showList(list) } label: { listLabel(list.name, ids: list.problemIDs, added: true) }.buttonStyle(.plain)
                }
            }
        }.foregroundColor(Palette.ink)
    }

    private func listLabel(_ name: String, ids: [String], added: Bool) -> some View {
        let solved = ids.filter { store.leetcode.progressFor($0).outcome.solved }.count
        return VStack(alignment: .leading, spacing: 10) {
            Label(name, systemImage: added ? "books.vertical" : "plus.circle").font(.system(size: 14, weight: .semibold))
            Text(added ? "\(solved) / \(ids.count) completed" : "Add \(ids.count) problems").font(.caption).foregroundColor(Palette.inkSoft)
            ProgressBar(value: added && !ids.isEmpty ? Double(solved) / Double(ids.count) : 0, height: 4)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.stroke))
    }

    private func practice(_ now: Date) -> some View {
        CardBox(spacing: 12) {
            Text("Today's Practice").font(.headline)
            HStack(spacing: 16) {
                Picker("Topic", selection: $topic) {
                    Text("Any topic").tag("Any topic")
                    ForEach(store.leetcode.topics, id: \.self) { Text($0).tag($0) }
                }.frame(maxWidth: 340)
                Picker("Problems", selection: $count) {
                    ForEach([2, 3, 5, 8], id: \.self) { Text(String($0)).tag($0) }
                }.frame(width: 130)
                Spacer(minLength: 0)
                Button("View topic problems") {
                    search = ""; browsingTopic = true; reviewing = false; listID = nil; selectedID = nil
                }.buttonStyle(SecondaryButtonStyle())
                Button("Generate today's problems") {
                    if store.leetcode.queues[PlanLogic.key(now)] != nil { regenerate = true } else { generate() }
                }.buttonStyle(PrimaryButtonStyle(compact: true)).disabled(store.leetcode.lists.isEmpty)
            }
            if store.leetcode.lists.isEmpty {
                Text("Import a list or a single problem to get started.").font(.caption).foregroundColor(Palette.inkSoft)
            }
        }.foregroundColor(Palette.ink)
    }

    private func reviewCard(_ now: Date) -> some View {
        let due = store.leetcode.due(on: now)
        return CardBox(padding: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath").foregroundColor(Palette.accentText)
                Text(due.isEmpty ? "You're all caught up." : "\(due.count) problems due today").font(.system(size: 14, weight: .medium))
                Spacer()
                Button("Review") { search = ""; browsingTopic = false; reviewing = true; listID = nil; selectedID = due.first?.id }
                    .buttonStyle(SecondaryButtonStyle()).disabled(due.isEmpty)
            }
        }.foregroundColor(Palette.ink)
    }

    private func problemList(_ now: Date) -> some View {
        let queue = store.leetcode.queues[PlanLogic.key(now)]
        let selectedList = store.leetcode.lists.first { $0.id == listID }
        let topicProblems = store.leetcode.problems.filter { topic == "Any topic" || $0.topics.contains(topic) }
            .sorted { (Int($0.number ?? "") ?? Int.max, $0.title) < (Int($1.number ?? "") ?? Int.max, $1.title) }
        let ids = !query.isEmpty ? searchResults.map(\.id) : (browsingTopic ? topicProblems.map(\.id)
            : (reviewing ? store.leetcode.due(on: now).map(\.id) : selectedList?.problemIDs ?? queue?.problemIDs ?? []))
        return CardBox(spacing: 12) {
            HStack {
                Text(!query.isEmpty ? "Search results" : (browsingTopic ? (topic == "Any topic" ? "All Problems" : topic) : (reviewing ? "Due for review" : selectedList?.name ?? "Today's Problems"))).font(.headline)
                Spacer()
                if reviewing || listID != nil || browsingTopic || !query.isEmpty {
                    Button("Today's Problems") { search = ""; browsingTopic = false; reviewing = false; listID = nil }.buttonStyle(.link)
                }
            }
            if browsingTopic || !query.isEmpty {
                Text("\(ids.count) matching problems · all local lists").font(.caption).foregroundColor(Palette.inkSoft)
            }
            if query.isEmpty && !browsingTopic && !reviewing && selectedList == nil, let queue = queue {
                Text("\(ids.count) / \(queue.targetCount) problems · \(queue.topic)")
                    .font(.caption).foregroundColor(Palette.inkSoft)
                if ids.count < queue.targetCount {
                    Text("Add more using search or browse by topic, or generate a new queue.")
                        .font(.caption).foregroundColor(Palette.inkSoft)
                }
            }
            if ids.isEmpty {
                if !query.isEmpty {
                    Text("No matching problem in your local library.").foregroundColor(Palette.inkSoft)
                    Button("Import this problem") { openSingleImport(number: Int(query).map(String.init) ?? "") }
                        .buttonStyle(SecondaryButtonStyle())
                } else {
                    Text(browsingTopic ? "No local problems have this topic yet." : (reviewing ? "You're all caught up." : "Search for a problem, browse a topic, or generate today's practice."))
                        .foregroundColor(Palette.inkSoft).padding(.vertical, 20)
                }
            }
            ForEach(ids, id: \.self) { id in
                if let p = store.leetcode.problem(id) { problemRow(p) }
            }
        }.foregroundColor(Palette.ink)
    }

    private func problemRow(_ p: LCProblem) -> some View {
        HStack(spacing: 12) {
            Button { selectedID = p.id } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(p.displayTitle).font(.system(size: 14, weight: .semibold)).multilineTextAlignment(.leading)
                    Text(([p.difficulty.rawValue] + p.topics + [store.leetcode.progressFor(p.id).outcome.status]).joined(separator: " · "))
                        .font(.caption).foregroundColor(Palette.inkSoft).multilineTextAlignment(.leading)
                    Text(store.leetcode.lists.filter { $0.problemIDs.contains(p.id) }.map(\.name).joined(separator: ", "))
                        .font(.caption2).foregroundColor(Palette.muted).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            let addedToday = store.leetcode.queues[PlanLogic.key(Date())]?.problemIDs.contains(p.id) == true
            if !query.isEmpty || browsingTopic || listID != nil {
                Button(addedToday ? "Added to today" : "Do today") { store.addProblemToToday(p.id) }
                    .buttonStyle(SmallButtonStyle()).disabled(addedToday)
            }
            Button {
                store.setProblemCompleted(p.id, completed: !store.leetcode.progressFor(p.id).outcome.solved)
            } label: {
                Label(store.leetcode.progressFor(p.id).outcome.solved ? "Completed" : "Mark complete",
                      systemImage: store.leetcode.progressFor(p.id).outcome.solved ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(SecondaryButtonStyle())
            .help(store.leetcode.progressFor(p.id).outcome.solved ? "Mark as not completed" : "Mark as completed")
        }.padding(13)
            .background(RoundedRectangle(cornerRadius: 12).fill(selectedID == p.id ? Palette.blushLight : Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selectedID == p.id ? Palette.red : Palette.stroke))
    }

    private func openSingleImport(number: String = "") {
        importRequest = LCImportSheet.Request(mode: .single, number: number)
    }
    private func showList(_ list: LCList) {
        search = ""; browsingTopic = false; listID = list.id; reviewing = false; selectedID = list.problemIDs.first
    }
    private func generate() {
        store.generateProblems(topic: topic, count: count)
        search = ""; browsingTopic = false; reviewing = false; listID = nil
        selectedID = store.leetcode.queues[PlanLogic.key(Date())]?.problemIDs.first
    }
    private func start(_ p: LCProblem) {
        selectedID = p.id
        if engine.startProblem(p) { nav.page = .focus } else { busy = true }
    }
}

struct LCProblemDetails: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var engine: Engine
    let problem: LCProblem
    let reviewing: Bool
    let onFocus: () -> Void

    var body: some View {
        let progress = store.leetcode.progressFor(problem.id)
        CardBox(spacing: 14) {
            HStack(alignment: .top) {
                Text(problem.displayTitle).font(.headline)
                Spacer()
                Link(destination: problem.url) { Image(systemName: "arrow.up.right.square") }.help("Open LeetCode")
            }
            Text(([problem.difficulty.rawValue] + problem.topics).joined(separator: " · "))
                .font(.caption).foregroundColor(Palette.inkSoft)
            Text(progress.outcome.status).font(.caption).foregroundColor(Palette.accentText)
            Text("Quick notes").font(.subheadline.bold())
            TextEditor(text: Binding(get: { store.leetcode.progressFor(problem.id).notes }, set: { store.setProblemNotes(problem.id, $0) }))
                .font(.system(size: 13)).scrollContentBackground(.hidden)
                .padding(8).frame(height: 140)
                .background(RoundedRectangle(cornerRadius: 10).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.stroke))
                .accessibilityLabel("Quick notes")
            Text("Notes save automatically.").font(.caption2).foregroundColor(Palette.muted)
            if reviewing && store.leetcode.due().contains(where: { $0.id == problem.id }) {
                HStack {
                    Button("Again") { store.reviewProblem(problem.id, remembered: false) }.buttonStyle(SecondaryButtonStyle())
                    Button("Remembered") { store.reviewProblem(problem.id, remembered: true) }.buttonStyle(PrimaryButtonStyle(compact: true))
                }
            }
            if let next = progress.nextReviewDate {
                Text("Next review: \(Fmt.dayLong.string(from: next))").font(.caption).foregroundColor(Palette.inkSoft)
            }
            HStack {
                Menu("Record result") {
                    ForEach(LCOutcome.allCases.filter { $0 != .skipped }) { outcome in
                        Button(outcome.title) { store.recordProblemResult(problem.id, outcome: outcome) }
                    }
                }
                Spacer()
                Button("Start Focus", action: onFocus).buttonStyle(PrimaryButtonStyle(compact: true))
            }
            Text("Record a solve without a timer, or start a focus session.").font(.caption2).foregroundColor(Palette.muted)
            let attempts = store.leetcode.attempts.filter { $0.problemID == problem.id }.sorted { $0.timestamp > $1.timestamp }
            let seconds = store.merged(with: engine.liveRecord).filter { $0.problemID == problem.id && $0.phase == .focus && $0.countsInStats }.reduce(0) { $0 + $1.activeSeconds }
            Text("\(attempts.count) attempts · \(Fmt.hm(seconds)) focus").font(.caption).foregroundColor(Palette.inkSoft)
            ForEach(Array(attempts.prefix(3))) { a in
                Text("\(Fmt.dayShort.string(from: a.timestamp)) · \(a.completionUndone == true ? "Completion undone" : (a.outcome == .skipped ? "Skipped result" : a.outcome.title))")
                    .font(.caption2).foregroundColor(Palette.muted)
            }
        }.foregroundColor(Palette.ink)
    }
}

struct LCResultSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var engine: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Did you solve it?").font(.title2.bold())
            if let id = engine.pendingProblemSessionID,
               let record = store.records.first(where: { $0.id == id }),
               let p = store.leetcode.problem(record.problemID) {
                Text(p.displayTitle).foregroundColor(Palette.inkSoft)
            }
            Text("Your focus time is already saved. Notes are optional.").font(.caption).foregroundColor(Palette.inkSoft)
            HStack(spacing: 12) {
                ForEach(LCOutcome.allCases) { outcome in
                    Button(outcome.title) { engine.answerProblem(outcome) }.buttonStyle(SecondaryButtonStyle())
                }
            }
        }.padding(28).foregroundColor(Palette.ink).background(Palette.canvas)
            .interactiveDismissDisabled()
    }
}
