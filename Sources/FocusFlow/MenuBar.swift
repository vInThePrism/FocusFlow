import SwiftUI
import AppKit

enum MenuIcon {
    /// The FocusFlow ring as a template image so it follows the menu bar color.
    static let image: NSImage = {
        let img = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { _ in
            let path = NSBezierPath()
            path.appendArc(withCenter: NSPoint(x: 8, y: 8), radius: 5.6, startAngle: 112, endAngle: 432, clockwise: false)
            path.lineWidth = 2.4
            path.lineCapStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        img.isTemplate = true
        return img
    }()
}

struct MenuBarLabel: View {
    @ObservedObject var engine: Engine
    @AppStorage(Pref.menuBarTime) private var showTime = true
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuIcon.image)
            if showTime && engine.state != .idle {
                Text(engine.state == .finished ? "Done" : Fmt.clock(engine.remaining))
                    .monospacedDigit()
            }
        }
        .onAppear {
            AppModel.openMain = { openWindow(id: "main") }
        }
    }
}

struct MenuBarPopover: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var store: Store
    @AppStorage(Pref.miniTimer) private var mini = false

    private var finished: Bool { engine.phase == .focus && engine.state == .finished }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if finished {
                completeBody
            } else {
                normalBody
            }
            Rectangle().fill(Palette.stroke).frame(height: 1)
            footer
        }
        .padding(18)
        .frame(width: 330)
        .background(Palette.card)
        .preferredColorScheme(.light)
    }

    // MARK: Normal

    private var normalBody: some View {
        let today = TodaySummary(all: store.merged(with: engine.liveRecord))
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(Palette.red).frame(width: 9, height: 9)
                Text(engine.phase == .focus ? "Focus" : engine.phase.title)
                    .font(.system(size: 14))
                    .foregroundColor(Palette.inkSoft)
                Spacer()
                Text(Fmt.clock(engine.remaining))
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(Palette.ink)
            }
            Text(headline)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Palette.ink)
                .lineLimit(1)
            ProgressBar(value: engine.progress, height: 9)

            HStack(spacing: 14) {
                Button {
                    engine.toggle()
                } label: {
                    Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: engine.state == .running ? 0 : 2)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Palette.redGradient))
                        .shadow(color: Palette.red.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(PressStyle())
                Button {
                    engine.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Palette.ink)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().strokeBorder(Palette.stroke))
                }
                .buttonStyle(PressStyle())
                Spacer()
                if engine.phase == .focus {
                    Button {
                        engine.extend()
                    } label: {
                        Text("+\(engine.extendStep) min")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Palette.ink)
                            .frame(width: 96, height: 48)
                            .background(Capsule().fill(Palette.blushLight))
                            .overlay(Capsule().strokeBorder(Palette.stroke))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(!engine.canExtend)
                    .opacity(engine.canExtend ? 1 : 0.5)
                } else {
                    Button {
                        engine.skipBreak()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Palette.ink)
                            .frame(width: 96, height: 48)
                            .background(Capsule().fill(Palette.blushLight))
                            .overlay(Capsule().strokeBorder(Palette.stroke))
                    }
                    .buttonStyle(PressStyle())
                }
            }

            Rectangle().fill(Palette.stroke).frame(height: 1)

            HStack {
                Text("Today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text("\(today.completed) / \(engine.dailyGoal) sessions")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.inkSoft)
            }
            ProgressBar(value: Double(today.completed) / Double(engine.dailyGoal), height: 9)

            VStack(spacing: 0) {
                MenuRow(icon: "cup.and.saucer", title: "Take a short break",
                        trailing: "\(Pref.int(Pref.shortBreakMinutes)) min") {
                    engine.startBreak(.shortBreak)
                }
                Rectangle().fill(Palette.stroke).frame(height: 1).padding(.horizontal, 10)
                MenuRow(icon: "tree", iconTint: Palette.tree, title: "Start a long break",
                        trailing: "\(Pref.int(Pref.longBreakMinutes)) min") {
                    engine.startBreak(.longBreak)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.stroke))
        }
    }

    private var headline: String {
        switch engine.phase {
        case .focus: return engine.intention.isEmpty ? "Ready to focus" : engine.intention
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    // MARK: Complete

    private var completeBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Palette.red).frame(width: 9, height: 9)
                Text("Session Complete")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text("00:00")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(Palette.ink)
            }
            .padding(.bottom, 4)
            MenuRow(icon: "plus.circle", title: "+\(engine.extendStep) min", highlighted: true) {
                engine.extend()
            }
            .disabled(!engine.canExtend)
            MenuRow(icon: "cup.and.saucer", title: "Start break") {
                engine.startBreak(nil)
            }
            MenuRow(icon: "checkmark.circle", title: "Finish session") {
                engine.finishSession()
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Open FocusFlow") { AppModel.showMain() }
            Button(mini ? "Hide mini timer" : "Mini timer") { mini.toggle() }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundColor(Palette.inkSoft)
    }
}

struct MenuRow: View {
    let icon: String
    var iconTint: Color = Palette.inkSoft
    let title: String
    var trailing: String? = nil
    var highlighted = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(highlighted ? .white : iconTint)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(highlighted ? .white : Palette.ink)
                Spacer()
                if let t = trailing {
                    Text(t)
                        .font(.system(size: 12))
                        .foregroundColor(highlighted ? .white.opacity(0.85) : Palette.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(highlighted ? AnyShapeStyle(Palette.redGradient)
                          : AnyShapeStyle(hovering ? Palette.blushLight : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
