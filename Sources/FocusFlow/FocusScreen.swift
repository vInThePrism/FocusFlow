import SwiftUI

struct FocusScreen: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            CenterPanel()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            RightColumn()
                .frame(width: 330)
        }
        .padding(.top, 26)
        .padding(.leading, 18)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}

struct CenterPanel: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        Group {
            if engine.phase == .focus && engine.state == .finished {
                CompleteView()
            } else {
                RunningView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.stroke.opacity(0.8)))
        .shadow(color: Palette.shadow, radius: 12, y: 4)
    }
}

// MARK: - Running / idle

struct RunningView: View {
    var body: some View {
        VStack(spacing: 0) {
            PhaseTabs()
                .padding(.top, 24)
            Spacer(minLength: 16)
            IntentionHeader()
            Spacer(minLength: 18)
            TimerDial(size: 316)
            PomodoroDots()
                .padding(.top, 26)
            Spacer(minLength: 22)
            ControlsRow()
            Spacer(minLength: 26)
        }
        .padding(.horizontal, 20)
    }
}

struct PhaseTabs: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Phase.allCases) { p in
                tab(p)
            }
        }
        .padding(5)
        .background(Capsule().fill(Color(hex: 0xF5EAE4)))
    }

    private func tab(_ p: Phase) -> some View {
        let on = engine.phase == p
        return Button {
            engine.select(p)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: p.icon)
                    .font(.system(size: 15, weight: .medium))
                Text(p.title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(on ? .white : Palette.inkSoft)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(on ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Color.clear))
                    .shadow(color: on ? Palette.red.opacity(0.3) : .clear, radius: 6, y: 3)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct IntentionHeader: View {
    @EnvironmentObject var engine: Engine
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(engine.phase == .focus ? "Current intention" : "Time to recharge")
                .font(.system(size: 13))
                .foregroundColor(Palette.inkSoft)
            if engine.phase != .focus {
                Text(engine.phase == .shortBreak ? "Short break" : "Long break")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Palette.ink)
            } else if editing {
                TextField("What are you focusing on?", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Palette.ink)
                    .frame(maxWidth: 440)
                    .focused($fieldFocused)
                    .onSubmit { commit() }
                    .onExitCommand { editing = false }
                    .onAppear { fieldFocused = true }
                    .onChange(of: fieldFocused) { focused in
                        if !focused { commit() }
                    }
            } else {
                HStack(spacing: 10) {
                    Text(engine.intention.isEmpty ? "Add an intention" : engine.intention)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(engine.intention.isEmpty ? Palette.muted : Palette.ink)
                        .lineLimit(1)
                    Button {
                        beginEditing()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Palette.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .help("Edit intention")
                }
                .onTapGesture(count: 2) { beginEditing() }
            }
        }
        .frame(height: 64)
    }

    private func beginEditing() {
        draft = engine.intention
        editing = true
    }

    private func commit() {
        guard editing else { return }
        engine.intention = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        editing = false
    }
}

/// The big ring. The red arc is the time left; the knob marks where you are.
struct TimerDial: View {
    @EnvironmentObject var engine: Engine
    var size: CGFloat
    var lineWidth: CGFloat = 16
    var showsHalo = true

    private var finished: Bool { engine.state == .finished }
    private var from: CGFloat { finished ? 0 : CGFloat(engine.progress) }
    private var radius: CGFloat { (size - lineWidth) / 2 }

    var body: some View {
        ZStack {
            if showsHalo { halo }
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: size - lineWidth * 2, height: size - lineWidth * 2)
            Circle()
                .stroke(Palette.track, lineWidth: lineWidth)
                .frame(width: size - lineWidth, height: size - lineWidth)
            Circle()
                .trim(from: from, to: 1)
                .stroke(Palette.redGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size - lineWidth, height: size - lineWidth)
            ticks
            knob
            label
        }
        .frame(width: size, height: size)
        .animation(.linear(duration: 0.5), value: engine.progress)
    }

    private var halo: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.blush.opacity(0.55), Palette.blush.opacity(0)],
                                     center: .center, startRadius: size * 0.42, endRadius: size * 0.72))
                .frame(width: size * 1.5, height: size * 1.5)
            ForEach([1.16, 1.3, 1.44], id: \.self) { (s: Double) in
                Circle()
                    .stroke(Palette.red.opacity(0.07), lineWidth: 1)
                    .frame(width: size * CGFloat(s), height: size * CGFloat(s))
            }
        }
        .allowsHitTesting(false)
    }

    private var ticks: some View {
        ForEach(0..<4, id: \.self) { i in
            Capsule()
                .fill(Color(hex: 0xDCCBC4))
                .frame(width: 2, height: 9)
                .offset(y: -(radius - lineWidth - 8))
                .rotationEffect(.degrees(Double(i) * 90))
        }
    }

    private var knob: some View {
        let angle = Double(from) * 2 * .pi
        return Circle()
            .fill(Palette.coral)
            .frame(width: lineWidth + 10, height: lineWidth + 10)
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
            .shadow(color: Palette.red.opacity(0.3), radius: 4, y: 2)
            .offset(x: CGFloat(sin(angle)) * radius, y: -CGFloat(cos(angle)) * radius)
    }

    private var label: some View {
        VStack(spacing: 6) {
            Text(finished ? "00:00" : Fmt.clock(engine.remaining))
                .font(.system(size: size * 0.235, weight: .bold))
                .monospacedDigit()
                .tracking(-1)
                .foregroundColor(Palette.ink)
            Text(finished ? "Time's up! 🎉" : "of \(Int((engine.total / 60).rounded())) minutes")
                .font(.system(size: max(13, size * 0.06)))
                .foregroundColor(Palette.inkSoft)
            if engine.state == .paused {
                Text(engine.idlePaused ? "Paused while you were away" : "Paused")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Palette.blush))
            }
        }
    }
}

struct PomodoroDots: View {
    @EnvironmentObject var engine: Engine

    private var label: String {
        switch engine.phase {
        case .focus: return "Pomodoro \(engine.pomodoroIndex) of \(Pref.cycleLength)"
        case .shortBreak: return "Short break · \(engine.completedInCycle) of \(Pref.cycleLength) done"
        case .longBreak: return "Long break · cycle complete"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 13) {
                ForEach(0..<Pref.cycleLength, id: \.self) { i in
                    Circle()
                        .fill(i < engine.pomodoroIndex ? Palette.red : Color(hex: 0xEADCD6))
                        .frame(width: 13, height: 13)
                }
            }
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Palette.inkSoft)
        }
    }
}

struct ControlsRow: View {
    @EnvironmentObject var engine: Engine

    private var mainLabel: String {
        switch engine.state {
        case .idle: return "Start"
        case .running: return "Pause"
        case .paused: return "Resume"
        case .finished: return "Extend"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(spacing: 10) {
                Button {
                    engine.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Palette.ink)
                        .frame(width: 62, height: 62)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().strokeBorder(Palette.stroke))
                        .shadow(color: Palette.shadow, radius: 6, y: 3)
                }
                .buttonStyle(PressStyle())
                .help("Restart this timer (focused time is kept)")
                Text("Reset")
                    .font(.system(size: 14))
                    .foregroundColor(Palette.ink)
            }
            .padding(.top, 16)
            .frame(width: 112)

            VStack(spacing: 10) {
                Button {
                    engine.toggle()
                } label: {
                    Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: engine.state == .running ? 0 : 3)
                        .frame(width: 94, height: 94)
                        .background(Circle().fill(Palette.redGradient))
                        .shadow(color: Palette.red.opacity(0.35), radius: 14, y: 8)
                }
                .buttonStyle(PressStyle())
                Text(mainLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Palette.ink)
            }

            Group {
                if engine.phase == .focus {
                    ExtendCluster()
                } else {
                    Button {
                        engine.skipBreak()
                    } label: {
                        Text("Skip break")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Palette.red)
                            .frame(width: 112, height: 58)
                            .background(Capsule().fill(Palette.blush))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.top, 18)
            .frame(width: 112)
        }
    }
}

struct ExtendCluster: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        Button {
            engine.extend()
        } label: {
            Text("+\(engine.extendStep) min")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(Palette.red)
                .frame(width: 112, height: 58)
                .background(Capsule().fill(Palette.blush))
        }
        .buttonStyle(PressStyle())
        .disabled(!engine.canExtend)
        .opacity(engine.canExtend ? 1 : 0.5)
        .help("Add time (repeatable)")
        .overlay(alignment: .top) {
            tooltip
                .fixedSize()
                .offset(x: 74, y: -52)
        }
        .overlay(alignment: .topTrailing) {
            chips
                .fixedSize()
                .offset(x: 92, y: -8)
        }
    }

    private var tooltip: some View {
        VStack(spacing: 0) {
            Text("Add time (repeatable)")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0x8E7D78, opacity: 0.92)))
            Triangle()
                .fill(Color(hex: 0x8E7D78, opacity: 0.92))
                .frame(width: 12, height: 6)
                .offset(x: -40)
        }
    }

    @ViewBuilder private var chips: some View {
        if engine.extensions > 0 {
            HStack(spacing: 3) {
                ForEach(0..<min(engine.extensions, 3), id: \.self) { _ in
                    Text("+\(engine.extendStep)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Palette.inkSoft)
                        .frame(width: 28, height: 24)
                        .background(Circle().fill(Color(hex: 0xF4ECE8)))
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                }
                if engine.extensions > 3 {
                    Text("×\(engine.extensions)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Palette.inkSoft)
                }
            }
        }
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
