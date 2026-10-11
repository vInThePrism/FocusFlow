import SwiftUI
import AppKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Palette {
    static let red = Color(hex: 0xE5473E)
    static let redTop = Color(hex: 0xF26B60)
    static let redBottom = Color(hex: 0xDB3A32)
    static let coral = Color(hex: 0xF08A7C)
    static let salmon = Color(hex: 0xF4A595)
    static let peach = Color(hex: 0xF8CFC3)
    static let blush = Color(hex: 0xFBE0D8)
    static let blushLight = Color(hex: 0xFDF0EA)
    static let track = Color(hex: 0xF3E5DE)
    static let barTrack = Color(hex: 0xF6E3DC)
    static let canvas = Color(hex: 0xFAF4EF)
    static let panel = Color(hex: 0xFDF8F4)
    static let sidebarTop = Color(hex: 0xF8EFE9)
    static let sidebarBottom = Color(hex: 0xF4E4DB)
    static let card = Color(hex: 0xFFFCF9)
    static let stroke = Color(hex: 0xEFE3DB)
    static let ink = Color(hex: 0x2A1C19)
    static let inkSoft = Color(hex: 0x5C4A45)
    static let muted = Color(hex: 0x9C8781)
    static let green = Color(hex: 0x2E9E5B)
    static let orange = Color(hex: 0xF0832B)
    static let gold = Color(hex: 0xE8A33A)
    static let pine = Color(hex: 0x4E5A3C)
    static let tree = Color(hex: 0x3F8A55)
    static let shadow = Color(hex: 0xB98E80, opacity: 0.16)

    static let redGradient = LinearGradient(colors: [redTop, redBottom], startPoint: .top, endPoint: .bottom)
    static let barGradient = LinearGradient(colors: [Color(hex: 0xE3423A), Color(hex: 0xF07466)], startPoint: .leading, endPoint: .trailing)
}

enum Fmt {
    static let en = Locale(identifier: "en_US")

    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(ceil(t - 0.001)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    /// 4h 12m / 45m
    static func hm(_ seconds: Int) -> String {
        let total = max(0, seconds) / 60
        let h = total / 60, m = total % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// 72 min, or 2h 15m from two hours on
    static func minutes(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        return m < 120 ? "\(m) min" : hm(seconds)
    }

    private static func make(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = en
        f.dateFormat = pattern
        return f
    }

    static let dayShort = make("EEE, MMM d")
    static let dayLong = make("EEE, MMM d, yyyy")
    static let monthYear = make("MMM yyyy")
    static let monthLong = make("MMMM yyyy")
    static let year = make("yyyy")
    static let time = make("h:mm a")
    static let clockShort = make("h:mm")
    static let weekday = make("EEE")
    static let monthAbbr = make("MMM")
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func hourLabel(_ h: Int) -> String {
        let hh = ((h % 24) + 24) % 24
        let suffix = hh < 12 ? "AM" : "PM"
        let v = hh % 12 == 0 ? 12 : hh % 12
        return "\(v) \(suffix)"
    }

    static func hourRange(_ start: Int) -> String {
        let a = ((start % 24) + 24) % 24
        let b = (a + 2) % 24
        let sameHalf = (a < 12) == (b < 12) && b != 0
        let av = a % 12 == 0 ? 12 : a % 12
        if sameHalf { return "\(av) – \(hourLabel(b))" }
        return "\(hourLabel(a)) – \(hourLabel(b))"
    }
}

// MARK: - Building blocks

struct CardBox<Content: View>: View {
    var padding: CGFloat = 20
    var spacing: CGFloat = 14
    var stretch = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: stretch ? .infinity : nil, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
            .shadow(color: Palette.shadow, radius: 10, x: 0, y: 4)
    }
}

struct InnerBox<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.stroke, lineWidth: 1))
    }
}

struct IconBadge: View {
    let systemName: String
    var tint: Color = Palette.red
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(0.12)))
    }
}

struct ProgressBar: View {
    var value: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.barTrack)
                Capsule()
                    .fill(Palette.barGradient)
                    .frame(width: fillWidth(g.size.width))
            }
        }
        .frame(height: height)
    }

    private func fillWidth(_ w: CGFloat) -> CGFloat {
        let v = CGFloat(min(1, max(0, value)))
        if v <= 0 { return 0 }
        return max(height, w * v)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PillToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Color(hex: 0xE6D9D3)))
                    .frame(width: 46, height: 26)
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
            }
            .animation(.easeOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}

/// A number field with little up/down arrows, as in the Settings design.
struct ValueStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int = 1
    var suffix: String = ""
    var width: CGFloat = 110
    var onTouch: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text("\(value)\(suffix)")
                .font(.system(size: 13))
                .foregroundColor(Palette.ink)
                .monospacedDigit()
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                arrow("chevron.up", step)
                arrow("chevron.down", -step)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(width: width, height: 28)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.stroke))
    }

    private func arrow(_ name: String, _ delta: Int) -> some View {
        Button {
            value = min(range.upperBound, max(range.lowerBound, value + delta))
            onTouch?()
        } label: {
            Image(systemName: name)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Palette.muted)
                .frame(width: 18, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SmallButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(primary ? .white : Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(primary ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Color.white)))
            .overlay(Capsule().strokeBorder(primary ? Color.clear : Palette.stroke))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct LogoMark: View {
    var size: CGFloat = 34

    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.84)
            .stroke(
                LinearGradient(colors: [Palette.redTop, Palette.redBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                style: StrokeStyle(lineWidth: size * 0.17, lineCap: .round)
            )
            .rotationEffect(.degrees(-62))
            .frame(width: size, height: size)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 11, height: 11)
            Text(label).font(.system(size: 12)).foregroundColor(Palette.inkSoft)
        }
    }
}

struct DotsMenuLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Palette.ink)
            .frame(width: 30, height: 24)
            .contentShape(Rectangle())
    }
}
