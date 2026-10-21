import SwiftUI

struct ApplicationEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var application: JobApplication
    @State private var day = Date()
    @State private var error: String?
    @State private var duplicate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.applications.application(application.id) == nil ? "Add application" : "Edit application").font(.title2.bold())
            FormField(label: "Company") { TextField("Company", text: $application.company).textFieldStyle(.plain) }
            FormField(label: "Role") { TextField("Role", text: $application.role).textFieldStyle(.plain) }
            FormField(label: "Applied date") {
                DatePicker("", selection: $day, in: ...Date(), displayedComponents: .date).labelsHidden()
            }
            FormField(label: "Job link (optional)") { TextField("https://…", text: $application.url).textFieldStyle(.plain) }
            FormField(label: "Notes (optional)") { TextField("Notes", text: $application.notes).textFieldStyle(.plain) }
            if let error = error { Text(error).font(.caption).foregroundColor(Palette.accentText) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Save") { prepareSave() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }.padding(22).frame(width: 480).foregroundColor(Palette.ink).background(Palette.card)
            .preferredColorScheme(ColorTheme.current.scheme)
            .onAppear { day = ApplicationDay.date(application.appliedOn) ?? Date() }
            .alert("Possible duplicate", isPresented: $duplicate) {
                Button("Cancel", role: .cancel) { }
                Button("Save anyway") { save() }
            } message: { Text("An application for this company and role is already recorded on this date.") }
    }
    private func prepareSave() {
        let company = application.company.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = application.role.trimmingCharacters(in: .whitespacesAndNewlines)
        duplicate = store.applications.applications.contains {
            $0.id != application.id && $0.appliedOn == ApplicationDay.key(day) &&
            $0.company.caseInsensitiveCompare(company) == .orderedSame && $0.role.caseInsensitiveCompare(role) == .orderedSame
        }
        if !duplicate { save() }
    }
    private func save() {
        application.appliedOn = ApplicationDay.key(day)
        error = store.saveApplication(application)
        if error == nil { dismiss() }
    }
}

struct ApplicationGoalEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var target = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily application goal").font(.title2.bold())
            Text("Changes apply from today.").font(.subheadline).foregroundColor(Palette.inkSoft)
            FormField(label: "Applications per day") { TextField("Enter a positive number", text: $target).textFieldStyle(.plain) }
            if let error = error { Text(error).font(.caption).foregroundColor(Palette.accentText) }
            HStack {
                Button("Pause goal") { store.setApplicationGoal(nil); dismiss() }.buttonStyle(SmallButtonStyle())
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Save") {
                    guard let value = Int(target), value > 0 else { error = "Enter a positive whole number."; return }
                    store.setApplicationGoal(value)
                    dismiss()
                }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }.padding(22).frame(width: 460).foregroundColor(Palette.ink).background(Palette.card)
            .preferredColorScheme(ColorTheme.current.scheme)
            .onAppear { target = store.applications.goal(on: Date()).map(String.init) ?? "" }
    }
}

private enum ApplicationDetailSheet: Identifiable {
    case edit(JobApplication), stage(UUID, ApplicationStage), task(Deadline, Bool)
    var id: String {
        switch self {
        case .edit(let a): return "edit-\(a.id)"
        case .stage(_, let s): return "stage-\(s.id)"
        case .task(let t, _): return "task-\(t.id)"
        }
    }
}

struct ApplicationDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let applicationID: UUID
    @State private var sheet: ApplicationDetailSheet?
    @State private var deleting = false
    @State private var deleteStage: ApplicationStage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let application = store.applications.application(applicationID) {
                HStack {
                    Text(application.company).font(.title2.bold())
                    Spacer()
                    Button("Edit") { sheet = .edit(application) }.buttonStyle(SmallButtonStyle())
                    Button("Done") { dismiss() }.buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(application.role).font(.headline).textSelection(.enabled)
                        Text("Applied \(application.appliedOn) · \(application.currentLabel)").foregroundColor(Palette.inkSoft)
                        if let url = application.safeURL { Link("Open job posting", destination: url).foregroundColor(Palette.accentText) }
                        if !application.notes.isEmpty { Text(application.notes).textSelection(.enabled) }
                        CardBox {
                            HStack {
                                Text("Stage history").font(.headline)
                                Spacer()
                                Button("Add stage") { sheet = .stage(application.id, ApplicationStage(kind: .oa, occurredAt: Date())) }
                                    .buttonStyle(SmallButtonStyle())
                            }
                            ForEach(application.orderedStages) { stage in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(stage.label).font(.subheadline.bold())
                                        Spacer()
                                        Text(Fmt.dayLong.string(from: stage.occurredAt)).font(.caption).foregroundColor(Palette.inkSoft)
                                        if stage.kind != .applied {
                                            Button("Edit") { sheet = .stage(application.id, stage) }.buttonStyle(SmallButtonStyle())
                                            Button { deleteStage = stage } label: { Image(systemName: "trash") }
                                                .buttonStyle(.plain).accessibilityLabel("Delete stage")
                                        }
                                    }
                                    if !stage.notes.isEmpty { Text(stage.notes).font(.caption).foregroundColor(Palette.inkSoft) }
                                }
                            }
                        }
                        CardBox {
                            HStack {
                                Text("Application tasks").font(.headline)
                                Spacer()
                                Button("Add task") {
                                    sheet = .task(Deadline(date: Date(), hasTime: false, title: "\(application.company) · OA", kind: .exam,
                                                           applicationLink: ApplicationTaskLink(applicationID: application.id, kind: .oa)), true)
                                }.buttonStyle(SmallButtonStyle())
                            }
                            let tasks = store.deadlines.filter { $0.applicationLink?.applicationID == application.id }
                            if tasks.isEmpty { Text("Schedule an OA, interview or follow-up.").foregroundColor(Palette.muted) }
                            ForEach(tasks) { task in
                                HStack(alignment: .top) {
                                    Button { store.toggleDeadline(task.id) } label: {
                                        Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                                    }.buttonStyle(.plain).accessibilityLabel(task.done ? "Mark task incomplete" : "Complete task")
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(task.title).strikethrough(task.done).font(.subheadline.bold())
                                        Text("\(Fmt.dayLong.string(from: task.date))\(task.hasTime ? " · " + Fmt.time.string(from: task.date) : "")\(applicationTaskOverdue(task) ? " · Overdue" : "")")
                                            .font(.caption).foregroundColor(Palette.inkSoft)
                                        if !task.note.isEmpty { Text(task.note).font(.caption).foregroundColor(Palette.inkSoft) }
                                    }
                                    Spacer()
                                    Button("Edit") { sheet = .task(task, false) }.buttonStyle(SmallButtonStyle())
                                }.foregroundColor(task.done ? Palette.muted : Palette.ink)
                            }
                        }
                        Button("Delete application", role: .destructive) { deleting = true }.buttonStyle(.plain).foregroundColor(Palette.accentText)
                    }.padding(2)
                }
            } else {
                Text("Application no longer exists.")
                Button("Close") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            }
        }.padding(22).frame(width: 650, height: 680).foregroundColor(Palette.ink).background(Palette.card)
            .preferredColorScheme(ColorTheme.current.scheme)
            .sheet(item: $sheet) { request in
                switch request {
                case .edit(let a): ApplicationEditor(application: a)
                case .stage(let id, let stage): ApplicationStageEditor(applicationID: id, stage: stage)
                case .task(let task, let isNew): ApplicationTaskEditor(deadline: task, isNew: isNew)
                }
            }
            .alert("Delete application?", isPresented: $deleting) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { store.deleteApplication(applicationID); dismiss() }
            } message: { Text("This deletes the application, its stage history and its linked application tasks.") }
            .alert("Delete stage?", isPresented: Binding(get: { deleteStage != nil }, set: { if !$0 { deleteStage = nil } })) {
                Button("Cancel", role: .cancel) { deleteStage = nil }
                Button("Delete", role: .destructive) {
                    if let stage = deleteStage { store.deleteApplicationStage(stage.id, applicationID: applicationID) }
                    deleteStage = nil
                }
            } message: { Text("Linked tasks will be kept. The current stage will be recalculated.") }
    }
}

struct ApplicationStageEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let applicationID: UUID
    @State var stage: ApplicationStage
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Application stage").font(.title2.bold())
            Picker("Stage", selection: $stage.kind) {
                ForEach(ApplicationStageKind.allCases.filter { $0 != .applied }) { Text($0.rawValue).tag($0) }
            }
            FormField(label: stage.kind == .other ? "Stage name" : "Name / round (optional)") {
                TextField("e.g. Round 2", text: $stage.customLabel).textFieldStyle(.plain)
            }
            DatePicker("Occurred", selection: $stage.occurredAt, displayedComponents: [.date, .hourAndMinute])
            Text("Record stages that have happened. Schedule future events with Add task.").font(.caption).foregroundColor(Palette.inkSoft)
            FormField(label: "Notes (optional)") { TextField("Notes", text: $stage.notes).textFieldStyle(.plain) }
            if let error = error { Text(error).font(.caption).foregroundColor(Palette.accentText) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Save") {
                    error = store.saveApplicationStage(stage, applicationID: applicationID)
                    if error == nil { dismiss() }
                }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }.padding(22).frame(width: 490).foregroundColor(Palette.ink).background(Palette.card)
            .preferredColorScheme(ColorTheme.current.scheme)
    }
}

struct ApplicationTaskEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State var deadline: Deadline
    let isNew: Bool
    @State private var kind: ApplicationTaskKind = .oa
    @State private var stageID: UUID?
    @State private var day = Date()
    @State private var time = Date()
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "Add application task" : "Edit application task").font(.title2.bold())
            Picker("Task", selection: $kind) { ForEach(ApplicationTaskKind.allCases) { Text($0.rawValue).tag($0) } }
            FormField(label: "Title") { TextField("Title", text: $deadline.title).textFieldStyle(.plain) }
            if let link = deadline.applicationLink, let application = store.applications.application(link.applicationID) {
                Picker("Related stage", selection: $stageID) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(application.orderedStages) { Text("\($0.label) · \(Fmt.dayLong.string(from: $0.occurredAt))").tag(Optional($0.id)) }
                }
            }
            DatePicker("Date", selection: $day, displayedComponents: .date)
            Toggle("Include time", isOn: $deadline.hasTime)
            if deadline.hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
            FormField(label: "Notes (optional)") { TextField("Notes", text: $deadline.note).textFieldStyle(.plain) }
            if let error = error { Text(error).font(.caption).foregroundColor(Palette.accentText) }
            HStack {
                if !isNew { Button("Delete", role: .destructive) { store.deleteDeadline(deadline.id); dismiss() }.buttonStyle(SmallButtonStyle()) }
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Save") { save() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }.padding(22).frame(width: 490).foregroundColor(Palette.ink).background(Palette.card)
            .preferredColorScheme(ColorTheme.current.scheme)
            .onAppear {
                kind = deadline.applicationLink?.kind ?? .oa
                stageID = deadline.applicationLink?.stageID
                day = deadline.date
                time = deadline.date
            }
            .onChange(of: kind) { newKind in
                guard isNew, let link = deadline.applicationLink, let application = store.applications.application(link.applicationID) else { return }
                if ApplicationTaskKind.allCases.contains(where: { deadline.title == "\(application.company) · \($0.rawValue)" }) {
                    deadline.title = "\(application.company) · \(newKind.rawValue)"
                }
            }
    }
    private func save() {
        guard let link = deadline.applicationLink, store.applications.application(link.applicationID) != nil else { error = "Application no longer exists."; return }
        deadline.title = deadline.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !deadline.title.isEmpty else { error = "Enter a title."; return }
        deadline.date = deadline.hasTime ? combine(day: day, time: time) : Calendar.current.startOfDay(for: day)
        deadline.kind = kind.deadlineKind
        deadline.applicationLink = ApplicationTaskLink(applicationID: link.applicationID, stageID: stageID, kind: kind)
        store.saveDeadline(deadline)
        dismiss()
    }
}
