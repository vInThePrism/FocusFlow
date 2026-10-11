import SwiftUI

/// "Session Complete · Extend Flow"
struct CompleteView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("🎉")
                .font(.system(size: 36))
                .padding(.top, 18)
            Text("Session Complete")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Palette.ink)
                .padding(.top, 2)
            Text("Great focus! The clock keeps running until you choose what's next.")
                .font(.system(size: 15))
                .foregroundColor(Palette.inkSoft)
                .padding(.top, 6)

            ZStack {
                Confetti(radius: 150)
                TimerDial(size: 240, lineWidth: 16, showsHalo: true)
                QuickExtendChips()
                    .offset(x: 222, y: 6)
            }
            .frame(height: 300)

            NextStepCard()
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
    }
}

struct Confetti: View {
    var radius: CGFloat
    private static let colors: [Color] = [Palette.red, Palette.orange, Palette.coral, Palette.gold, Palette.salmon]

    var body: some View {
        ZStack {
            ForEach(0..<36, id: \.self) { i in
                piece(i)
            }
        }
        .allowsHitTesting(false)
    }

    private func piece(_ i: Int) -> some View {
        let angle = Double(i) * 137.5
        let rad = angle * .pi / 180
        let dist = radius + CGFloat((i * 37) % 64)
        return Capsule()
            .fill(Confetti.colors[i % Confetti.colors.count])
            .frame(width: i % 3 == 0 ? 4 : 3, height: CGFloat(8 + (i * 13) % 12))
            .rotationEffect(.degrees(angle + 90))
            .offset(x: CGFloat(cos(rad)) * dist, y: CGFloat(sin(rad)) * dist * 0.92)
            .opacity(i % 4 == 0 ? 0.5 : 0.9)
    }
}

struct QuickExtendChips: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            chip(15, fill: AnyShapeStyle(Palette.redGradient), text: .white)
                .rotationEffect(.degrees(-8))
            chip(10, fill: AnyShapeStyle(Palette.blush), text: Palette.red)
                .rotationEffect(.degrees(-4))
            chip(5, fill: AnyShapeStyle(Palette.blushLight), text: Palette.red)
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "arrow.turn.left.up")
                    .font(.system(size: 16))
                    .foregroundColor(Palette.red)
                    .padding(.leading, 30)
                Text("Adds time from\nright now —\nrepeat as needed.")
                    .font(.system(size: 12).italic())
                    .foregroundColor(Palette.inkSoft)
            }
            .padding(.top, 2)
        }
        .disabled(!engine.canExtend)
        .opacity(engine.canExtend ? 1 : 0.5)
    }

    private func chip(_ minutes: Int, fill: AnyShapeStyle, text: Color) -> some View {
        Button {
            engine.extend(minutes: minutes)
        } label: {
            Text("+\(minutes) min")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Capsule().fill(fill))
                .shadow(color: Palette.red.opacity(0.18), radius: 5, y: 3)
        }
        .buttonStyle(PressStyle())
    }
}

struct NextStepCard: View {
    @EnvironmentObject var engine: Engine

    var body: some View {
        let step = engine.extendStep
        let now = Int(engine.activeSeconds)
        VStack(spacing: 14) {
            VStack(spacing: 5) {
                Text("Need a little more time?")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Palette.ink)
                Text("Time past 00:00 keeps counting as focus. +\(step) min starts from where you are now.")
                    .font(.system(size: 13))
                    .foregroundColor(Palette.inkSoft)
            }
            HStack(alignment: .top, spacing: 14) {
                ActionTile(primary: true, icon: "plus.circle", title: "+\(step) min",
                           caption: "Keep going\n(\(step) more from now)", enabled: engine.canExtend) {
                    engine.extend()
                }
                ActionTile(icon: "cup.and.saucer", title: "Start break", caption: "Take a refreshing\nbreak") {
                    engine.startBreak(nil)
                }
                ActionTile(icon: "checkmark.circle", title: "Finish session", caption: "Save \(Int(engine.activeSeconds / 60)) min and stop") {
                    engine.finishSession()
                }
            }
            Rectangle().fill(Palette.stroke).frame(height: 1)
            VStack(alignment: .leading, spacing: 8) {
                Text("Total focus time if you extend now")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.inkSoft)
                HStack(spacing: 0) {
                    PreviewRing(seconds: now, label: "Now", chips: 0, step: step)
                    arrow
                    PreviewRing(seconds: now + step * 60, label: "After 1 extension", chips: 1, step: step)
                    arrow
                    PreviewRing(seconds: now + step * 120, label: "After 2 extensions", chips: 2, step: step)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 14))
            .foregroundColor(Palette.muted)
            .frame(maxWidth: .infinity)
    }
}

struct ActionTile: View {
    var primary = false
    let icon: String
    let title: String
    let caption: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(primary ? .white : Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(primary ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Color.white)))
                .overlay(Capsule().strokeBorder(primary ? Color.clear : Palette.stroke))
                .shadow(color: primary ? Palette.red.opacity(0.3) : Palette.shadow, radius: 8, y: 4)
                .contentShape(Capsule())
            }
            .buttonStyle(PressStyle())
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
            Text(caption)
                .font(.system(size: 12))
                .foregroundColor(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PreviewRing: View {
    let seconds: Int
    let label: String
    let chips: Int
    let step: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(chips == 0 ? Palette.track : Palette.red, lineWidth: 3)
                Text(Fmt.clock(TimeInterval(seconds)))
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(Palette.ink)
            }
            .frame(width: 64, height: 64)
            .overlay(alignment: .top) {
                if chips > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<chips, id: \.self) { _ in
                            Text(chips == 1 ? "+\(step) min" : "+\(step)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Palette.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Palette.blush))
                        }
                    }
                    .fixedSize()
                    .offset(y: -16)
                }
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Palette.inkSoft)
        }
    }
}
