import SwiftUI

enum ApplicationSheet: Identifiable {
    case detail(UUID), edit(JobApplication), count(Date), goal
    var id: String {
        switch self { case .detail(let id): return "detail-\(id)"; case .edit(let a): return "edit-\(a.id)"; case .count(let day): return "count-\(ApplicationDay.key(day))"; case .goal: return "goal" }
    }
}

struct ApplicationsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @State private var search = ""
    @State private var filter: ApplicationStageKind?
    @State private var sheet: ApplicationSheet?

    private var matches: [JobApplication] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.applications.applications.filter {
            (filter == nil || $0.currentKind == filter) && (query.isEmpty || $0.company.localizedCaseInsensitiveContains(query) || $0.role.localizedCaseInsensitiveContains(query))
        }.sorted {
            if $0.appliedOn != $1.appliedOn { return $0.appliedOn > $1.appliedOn }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Applications").font(.system(size: 30, weight: .bold))
                        Text("One step closer, every day.").foregroundColor(Palette.inkSoft)
                    }
                    Spacer()
                    if store.applications.countOnlyMode != true {
                        Button("Add application") { sheet = .edit(JobApplication(company: "", role: "", appliedOn: ApplicationDay.key(Date()))) }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                if let problem = store.problem {
                    Text(problem).font(.caption).foregroundColor(Palette.accentText).textSelection(.enabled)
                }
                Picker("Recording mode", selection: Binding(get: { store.applications.countOnlyMode == true }, set: { store.setApplicationCountOnlyMode($0) })) {
                    Text("Daily count only").tag(true)
                    Text("Application details").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                ApplicationGoalCard(edit: { sheet = .goal }, editCount: { sheet = .count(Date()) })
                if store.applications.countOnlyMode != true {
                CardBox {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(Palette.muted)
                        TextField("Search company or role", text: $search).textFieldStyle(.plain)
                            .accessibilityLabel("Search applications")
                        if !search.isEmpty {
                            Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.plain).accessibilityLabel("Clear search")
                        }
                        Picker("Status", selection: $filter) {
                            Text("All stages").tag(Optional<ApplicationStageKind>.none)
                            ForEach(ApplicationStageKind.allCases) { Text($0.rawValue).tag(Optional($0)) }
                        }.frame(width: 190)
                    }
                }
                CardBox {
                    Text("\(matches.count) applications").font(.headline)
                    if matches.isEmpty {
                        Text(store.applications.applications.isEmpty ? "Record your first application with Add application." : "No matching applications.")
                            .foregroundColor(Palette.muted)
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(matches) { application in
                            Button { sheet = .detail(application.id) } label: {
                                InnerBox {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(application.company).font(.headline)
                                            Text(application.role).foregroundColor(Palette.inkSoft).lineLimit(1)
                                            Text("Applied \(application.appliedOn)").font(.caption).foregroundColor(Palette.muted)
                                        }
                                        Spacer()
                                        Text(application.currentLabel).font(.subheadline.weight(.semibold)).foregroundColor(Palette.accentText)
                                    }
                                    if let next = store.deadlines.first(where: { $0.applicationLink?.applicationID == application.id && !$0.done }) {
                                        Text("\(next.title) · \(Fmt.dayLong.string(from: next.date))\(next.hasTime ? " · " + Fmt.time.string(from: next.date) : "")\(applicationTaskOverdue(next) ? " · Overdue" : "")")
                                            .font(.caption).foregroundColor(Palette.inkSoft).lineLimit(2)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
                }
            }.padding(24).foregroundColor(Palette.ink)
        }
        .sheet(item: $sheet) { request in
            switch request {
            case .detail(let id): ApplicationDetail(applicationID: id)
            case .edit(let application): ApplicationEditor(application: application)
            case .count(let day): ApplicationCountEditor(day: day)
            case .goal: ApplicationGoalEditor()
            }
        }
        .onAppear { openRequestedApplication() }
        .onChange(of: nav.applicationID) { _ in openRequestedApplication() }
    }

    private func openRequestedApplication() {
        guard let id = nav.applicationID else { return }
        nav.applicationID = nil
        if store.applications.application(id) != nil {
            store.setApplicationCountOnlyMode(false)
            sheet = .detail(id)
        }
    }
}

struct ApplicationGoalCard: View {
    @EnvironmentObject var store: Store
    var edit: () -> Void
    var editCount: () -> Void
    var body: some View {
        let count = store.applications.total(on: Date())
        let target = store.applications.goal(on: Date())
        let fraction = target.map { min(1, Double(count) / Double($0)) } ?? 0
        CardBox(padding: 26, spacing: 18) {
            HStack {
                Label("Today's applications", systemImage: "briefcase").font(.headline)
                Spacer()
                Button(target == nil ? "Set daily goal" : "Edit goal", action: edit).buttonStyle(SmallButtonStyle())
            }
            HStack(spacing: 32) {
                ApplicationProgressRing(count: count, target: target)
                VStack(alignment: .leading, spacing: 12) {
                    Text(target == nil ? "Every application counts." : fraction >= 1 ? "Today's goal, fulfilled." : "A little closer with every send.")
                        .font(.system(size: 24, weight: .bold))
                    Text(target.map { count >= $0 ? "You reached your daily goal." : "\($0 - count) more to reach your goal." } ?? "Set a daily goal to see your progress.")
                        .foregroundColor(Palette.inkSoft)
                    if store.applications.countOnlyMode == true {
                        Text("Just the daily total. No company or role needed.")
                            .font(.subheadline).foregroundColor(Palette.muted)
                        HStack(spacing: 10) {
                            Button("+1") { store.incrementDailyApplicationCount(1) }.buttonStyle(PrimaryButtonStyle())
                                .accessibilityLabel("Add one application today").disabled(count == Int.max)
                            Button("+5") { store.incrementDailyApplicationCount(5) }.buttonStyle(SecondaryButtonStyle())
                                .accessibilityLabel("Add five applications today").disabled(count > Int.max - 5)
                            Button("Edit count", action: editCount).buttonStyle(SmallButtonStyle())
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ApplicationProgressRing: View {
    var count: Int
    var target: Int?
    private var fraction: Double { target.map { min(1, Double(count) / Double($0)) } ?? 0 }
    var body: some View {
        ZStack {
            Circle().stroke(Palette.barTrack, lineWidth: 12)
            Circle().trim(from: 0, to: fraction)
                .stroke(Palette.barGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(Palette.blush)
                    .overlay {
                        Image(systemName: "heart.fill").foregroundStyle(Palette.redGradient)
                            .mask(alignment: .bottom) { Rectangle().frame(height: 34 * fraction) }
                    }
                    .font(.system(size: 34))
                Text("\(count)").font(.system(size: 40, weight: .bold, design: .rounded)).minimumScaleFactor(0.4).lineLimit(1)
                Text(target.map { "of \($0) sent" } ?? "sent today").font(.caption).foregroundColor(Palette.inkSoft)
                if target != nil { Text("\(Int(fraction * 100))%").font(.caption.bold()).foregroundColor(Palette.accentText) }
            }.padding(20)
        }
        .frame(width: 190, height: 190)
        .animation(.easeInOut(duration: 0.35), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(target.map { "\(count) of \($0) applications sent, \(Int(fraction * 100)) percent of goal" } ?? "\(count) applications sent today")
    }
}

struct ApplicationCountEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let day: Date
    @State private var value = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily application count").font(.title2.bold())
            Text(Fmt.dayLong.string(from: day)).foregroundColor(Palette.inkSoft)
            FormField(label: "Total sent this day") { TextField("0", text: $value).textFieldStyle(.plain) }
            Text("Includes any applications already recorded with details.").font(.caption).foregroundColor(Palette.muted)
            if let error = error { Text(error).font(.caption).foregroundColor(Palette.accentText) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Save") {
                    guard let count = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)), count >= 0 else {
                        error = "Enter a non-negative whole number."; return
                    }
                    error = store.setDailyApplicationCount(count, on: day)
                    if error == nil { dismiss() }
                }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }.padding(22).frame(width: 460).foregroundColor(Palette.ink).background(Palette.card)
            .preferredColorScheme(ColorTheme.current.scheme)
            .onAppear { value = String(store.applications.total(on: day)) }
    }
}

func applicationTaskOverdue(_ task: Deadline) -> Bool {
    !task.done && (task.hasTime ? task.date < Date() : Calendar.current.startOfDay(for: task.date) < Calendar.current.startOfDay(for: Date()))
}

struct ApplicationTasksCard: View {
    @EnvironmentObject var store: Store
    let day: Date
    @State private var editing: DeadlineSheet?
    var body: some View {
        let tasks = store.deadlines.filter { $0.applicationLink != nil && Calendar.current.isDate($0.date, inSameDayAs: day) }
        CardBox {
            Label("Application tasks · \(Fmt.dayLong.string(from: day))", systemImage: "briefcase").font(.headline)
            if tasks.isEmpty { Text("No application tasks this day.").foregroundColor(Palette.muted) }
            ForEach(tasks) { task in
                DeadlineRow(deadline: task) { editing = DeadlineSheet(deadline: task, isNew: false) }
            }
        }
        .sheet(item: $editing) { ApplicationTaskEditor(deadline: $0.deadline, isNew: false) }
    }
}

struct ApplicationDayCard: View {
    @State private var editingCount = false
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    let day: Date
    var body: some View {
        let sent = store.applications.sent(on: day)
        let count = store.applications.total(on: day)
        CardBox {
            HStack {
                Label("Applications (\(count))", systemImage: "briefcase").font(.headline)
                Spacer()
                if Calendar.current.startOfDay(for: day) <= Calendar.current.startOfDay(for: Date()) {
                    Button("Edit count") { editingCount = true }.buttonStyle(SmallButtonStyle())
                }
            }
            if let target = store.applications.goal(on: day) {
                Text("\(count) / \(target) daily goal").font(.caption).foregroundColor(Palette.inkSoft)
                ProgressBar(value: Double(count) / Double(target))
            }
            if count == 0 { Text("No applications sent this day.").font(.subheadline).foregroundColor(Palette.muted) }
            if count > sent.count {
                Text("\(count - sent.count) recorded without details").font(.caption).foregroundColor(Palette.inkSoft)
            }
            ForEach(sent) { application in
                Button { nav.showApplication(application.id) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(application.company).font(.subheadline.bold())
                        Text(application.role).font(.caption).foregroundColor(Palette.inkSoft)
                    }
                }.buttonStyle(.plain)
            }
        }.foregroundColor(Palette.ink)
        .sheet(isPresented: $editingCount) { ApplicationCountEditor(day: day) }
    }
}

struct ApplicationStatsCard: View {
    @EnvironmentObject var store: Store
    let scope: StatsScope
    let anchor: Date
    private var interval: DateInterval { Calendar.current.dateInterval(of: scope.component, for: anchor)! }
    private var buckets: [(date: Date, count: Int)] {
        let cal = Calendar.current
        let unit: Calendar.Component = scope == .year ? .month : .day
        var date = interval.start
        var result: [(Date, Int)] = []
        while date < interval.end {
            guard let next = cal.date(byAdding: unit, value: 1, to: date) else { break }
            result.append((date, store.applications.total(in: DateInterval(start: date, end: next))))
            date = next
        }
        return result
    }
    var body: some View {
        let sent = store.applications.sent(in: interval)
        let count = store.applications.total(in: interval)
        let summary = store.applications.goalSummary(in: interval)
        CardBox {
            Label("Applications", systemImage: "briefcase").font(.headline)
            Text("\(count) sent").font(.system(size: 30, weight: .bold)).foregroundColor(Palette.accentText)
            if scope == .day {
                if let goal = store.applications.goal(on: anchor) { Text("\(count) / \(goal) daily goal").foregroundColor(Palette.inkSoft) }
                else { Text("Daily goal not set").foregroundColor(Palette.muted) }
            } else {
                Text(summary.days == 0 ? "Goal days: —" : "\(summary.met) / \(summary.days) completed days reached their goal")
                    .foregroundColor(Palette.inkSoft)
                if interval.start <= Date() && Date() < interval.end, let target = store.applications.goal(on: Date()) {
                    Text("Today in progress: \(store.applications.total(on: Date())) / \(target)").font(.caption).foregroundColor(Palette.inkSoft)
                }
                trend
            }
            if count > sent.count {
                Text("\(count - sent.count) recorded without details").font(.caption).foregroundColor(Palette.inkSoft)
            }
            if store.applications.countOnlyMode != true {
            Text("Current stages · detailed records sent in this period").font(.subheadline.weight(.semibold))
            if sent.isEmpty { Text("No detailed records in this period.").font(.caption).foregroundColor(Palette.muted) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(ApplicationStageKind.allCases) { kind in
                    let count = sent.filter { $0.currentKind == kind }.count
                    if count > 0 { Text("\(kind.rawValue) · \(count)").font(.subheadline).foregroundColor(Palette.inkSoft) }
                }
            }
            }
        }.foregroundColor(Palette.ink)
    }
    private var trend: some View {
        let values = buckets
        let peak = max(1, values.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 6) {
            Text(scope == .year ? "Sent each month" : "Sent each day").font(.caption).foregroundColor(Palette.inkSoft)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(values, id: \.date) { value in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(value.count == 0 ? Palette.barTrack : Palette.accentText)
                            .frame(height: value.count == 0 ? 2 : max(4, 65 * Double(value.count) / Double(peak)))
                        Text("\(Calendar.current.component(scope == .year ? .month : .day, from: value.date))")
                            .font(.system(size: 8)).foregroundColor(Palette.muted)
                    }.frame(maxWidth: .infinity)
                        .help("\(Fmt.dayLong.string(from: value.date)): \(value.count) sent")
                }
            }.frame(height: 85, alignment: .bottom)
        }
    }
}
