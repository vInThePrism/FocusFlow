import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

enum Page: String, CaseIterable, Identifiable {
    case focus = "Focus", plan = "Plan", calendar = "Calendar", stats = "Stats", history = "History", settings = "Settings"

    var id: String { rawValue }

    func icon(selected: Bool) -> String {
        switch self {
        case .focus: return "clock"
        case .plan: return "checklist"
        case .calendar: return "calendar"
        case .stats: return selected ? "chart.bar.fill" : "chart.bar"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
final class Nav: ObservableObject {
    @Published var page: Page = .focus
}

@MainActor
enum AppModel {
    static let store = Store()
    static let engine = Engine(store: store)
    static let nav = Nav()
    static var openMain: (@MainActor () -> Void)?

    static func showMain() {
        NSApp.activate(ignoringOtherApps: true)
        if let open = openMain {
            open()
        } else {
            NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.shared.setup()
        _ = AppModel.engine
        syncMiniTimer()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncMiniTimer() }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: Notifier.openRequested)
            .receive(on: RunLoop.main)
            .sink { _ in AppModel.showMain() }
            .store(in: &bag)
    }

    private func syncMiniTimer() {
        MiniTimerController.shared.setVisible(Pref.bool(Pref.miniTimer))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { AppModel.showMain() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.engine.saveOnQuit()
    }
}

@main
struct FocusFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Pref.register()
    }

    var body: some Scene {
        Window("FocusFlow", id: "main") {
            RootView()
                .environmentObject(AppModel.engine)
                .environmentObject(AppModel.store)
                .environmentObject(AppModel.nav)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1260, height: 830)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(AppModel.engine)
                .environmentObject(AppModel.store)
                .environmentObject(AppModel.nav)
        } label: {
            MenuBarLabel(engine: AppModel.engine)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Main window

struct RootView: View {
    @EnvironmentObject var nav: Nav
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 228)
            ZStack {
                Palette.canvas
                switch nav.page {
                case .focus: FocusScreen()
                case .plan: PlanScreen()
                case .calendar: CalendarScreen()
                case .stats: StatsScreen()
                case .history: HistoryScreen()
                case .settings: SettingsScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1160, minHeight: 800)
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .onAppear {
            AppModel.openMain = { openWindow(id: "main") }
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var nav: Nav
    @EnvironmentObject var engine: Engine

    private var quote: String {
        if nav.page == .settings { return "“Better focus,\na brighter you.”" }
        if nav.page == .plan { return "“Plans turn\nintentions into\nbrighter days.”" }
        if nav.page == .history { return "“Every focused\nmoment moves\nyou forward.”" }
        if nav.page == .focus && engine.state == .finished { return "“Momentum\ntoday creates\na brighter tomorrow.”" }
        return "“A calmer mind\nbuilds a brighter day.”"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 56)
            HStack(spacing: 12) {
                LogoMark(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FocusFlow")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Palette.ink)
                    Text("Do more, calmly.")
                        .font(.system(size: 12))
                        .foregroundColor(Palette.inkSoft)
                }
            }
            .padding(.horizontal, 24)

            VStack(spacing: 6) {
                ForEach(Page.allCases) { page in
                    navItem(page)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 34)

            Spacer(minLength: 20)

            ZStack(alignment: .bottomLeading) {
                LandscapeView(variant: .sidebar)
                    .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .center))
                VStack(alignment: .leading, spacing: 14) {
                    Text(quote)
                        .font(.system(size: 14, design: .serif).italic())
                        .foregroundColor(Palette.inkSoft)
                        .lineSpacing(3)
                    Rectangle().fill(Palette.muted.opacity(0.5)).frame(width: 30, height: 1)
                }
                .padding(.leading, 28)
                .padding(.bottom, 36)
            }
            .frame(height: 250)
        }
        .frame(maxHeight: .infinity)
        .background(LinearGradient(colors: [Palette.sidebarTop, Palette.sidebarBottom], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.stroke).frame(width: 1)
        }
    }

    private func navItem(_ page: Page) -> some View {
        let on = nav.page == page
        return Button {
            nav.page = page
        } label: {
            HStack(spacing: 14) {
                Image(systemName: page.icon(selected: on))
                    .font(.system(size: 17))
                    .frame(width: 22)
                Text(page.rawValue)
                    .font(.system(size: 15, weight: on ? .medium : .regular))
                Spacer()
            }
            .foregroundColor(on ? Palette.red : Palette.inkSoft)
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Palette.blush : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - "…" menu shared by pages

struct MoreMenu: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: Store
    @AppStorage(Pref.miniTimer) private var mini = false

    var body: some View {
        Menu {
            Toggle("Floating Mini Timer", isOn: $mini)
            Button("Reset Pomodoro Cycle") { engine.resetCycle() }
            Divider()
            Button("Export Data (JSON)…") { DataActions.exportJSON(store) }
            Button("Export Data (CSV)…") { DataActions.exportCSV(store) }
            Button("Show Data in Finder") { DataActions.reveal(store) }
        } label: {
            DotsMenuLabel()
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - File actions

@MainActor
enum DataActions {
    static func reveal(_ store: Store) {
        if FileManager.default.fileExists(atPath: store.fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
        } else {
            NSWorkspace.shared.open(store.folderURL)
        }
    }

    static func exportJSON(_ store: Store) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FocusFlow-\(Fmt.fileStamp.string(from: Date())).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try store.exportJSON(to: url) } catch { info("Export failed", error.localizedDescription) }
    }

    static func exportCSV(_ store: Store) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "FocusFlow-\(Fmt.fileStamp.string(from: Date())).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try store.exportCSV(to: url) } catch { info("Export failed", error.localizedDescription) }
    }

    static func importFile(_ store: Store) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.backupsURL
        panel.message = "Choose a FocusFlow export or a file from Backups. Sessions you already have are kept; missing ones are added."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let added = try store.importFile(url)
            info("Import finished", added == 1 ? "1 session was added." : "\(added) sessions were added.")
        } catch {
            info("Import failed", error.localizedDescription)
        }
    }

    static func chooseFolder(_ store: Store) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use This Folder"
        panel.message = "FocusFlow will copy your sessions here and keep saving to this folder. The current file is left in place."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.moveData(to: url)
    }

    static func info(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
