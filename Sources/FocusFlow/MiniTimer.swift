import SwiftUI
import AppKit

final class MiniPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The floating, always-on-top pill timer.
@MainActor
final class MiniTimerController {
    static let shared = MiniTimerController()
    private var panel: MiniPanel?

    func setVisible(_ visible: Bool) {
        if visible { show() } else { panel?.orderOut(nil) }
    }

    private func show() {
        if panel == nil {
            let size = NSSize(width: 428, height: 144)
            let p = MiniPanel(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
            p.isFloatingPanel = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.isMovableByWindowBackground = true
            p.hidesOnDeactivate = false
            p.appearance = NSAppearance(named: .aqua)
            let host = NSHostingView(rootView: MiniTimerView()
                .environmentObject(AppModel.engine)
                .environmentObject(AppModel.store))
            host.frame = NSRect(origin: .zero, size: size)
            p.contentView = host
            if let screen = NSScreen.main?.visibleFrame {
                p.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 12, y: screen.maxY - size.height - 8))
            }
            panel = p
        }
        panel?.orderFrontRegardless()
    }
}

/// Lets you drag the borderless panel from anywhere that isn't a button.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct MiniTimerView: View {
    @EnvironmentObject var engine: Engine

    private var subtitle: String {
        switch engine.phase {
        case .focus:
            if engine.state == .finished { return "Time's up · still counting" }
            return engine.intention.isEmpty ? "Focus" : engine.intention
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var body: some View {
        HStack(spacing: 18) {
            Button {
                engine.toggle()
            } label: {
                ZStack {
                    Circle().stroke(Palette.track, lineWidth: 7)
                    Circle()
                        .trim(from: engine.state == .finished ? 0 : CGFloat(engine.progress), to: 1)
                        .stroke(Palette.redGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if engine.state != .running {
                        Image(systemName: engine.state == .finished ? "plus" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Palette.red)
                    }
                }
                .frame(width: 56, height: 56)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(engine.state == .running ? "Pause" : (engine.state == .finished ? "Add time" : "Start"))

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.state == .finished ? "+" + Fmt.clock(engine.overtime) : Fmt.clock(engine.remaining))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(engine.state == .finished ? Palette.red : Palette.ink)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Palette.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Rectangle().fill(Palette.stroke).frame(width: 1, height: 48)
            Button {
                AppModel.showMain()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Palette.red)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Palette.shadow, radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .help("Open FocusFlow")
        }
        .padding(.leading, 22)
        .padding(.trailing, 18)
        .frame(width: 380, height: 96)
        .background(WindowDragArea())
        .background(
            Capsule()
                .fill(Palette.card)
                .shadow(color: Color(hex: 0x8A5A4A, opacity: 0.22), radius: 16, y: 8)
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.8)))
        .padding(24)
        .contextMenu {
            Button(engine.state == .running ? "Pause" : "Start / Resume") { engine.toggle() }
            Button("Open FocusFlow") { AppModel.showMain() }
            Divider()
            Button("Hide Mini Timer") { UserDefaults.standard.set(false, forKey: Pref.miniTimer) }
        }
        .preferredColorScheme(.light)
    }
}
