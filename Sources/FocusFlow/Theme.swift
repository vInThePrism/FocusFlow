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

// MARK: - Color themes

enum ColorTheme: String, CaseIterable, Identifiable {
    case tomato, pink, purple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tomato: return "Tomato"
        case .pink: return "Pink"
        case .purple: return "Purple"
        }
    }

    var isDark: Bool { self == .purple }
    var scheme: ColorScheme { isDark ? .dark : .light }

    static var current: ColorTheme {
        ColorTheme(rawValue: UserDefaults.standard.string(forKey: Pref.colorTheme) ?? "") ?? .tomato
    }

    var colors: ThemeColors {
        switch self {
        case .tomato: return ThemeColors.tomato
        case .pink: return ThemeColors.pink
        case .purple: return ThemeColors.purple
        }
    }
}

/// Every color the UI uses, per theme. "red" means the theme's accent.
struct ThemeColors {
    var red: UInt32, redTop: UInt32, redBottom: UInt32, coral: UInt32, salmon: UInt32, peach: UInt32
    var blush: UInt32, blushLight: UInt32, track: UInt32, barTrack: UInt32, barEnd: UInt32
    var canvas: UInt32, panel: UInt32, sidebarTop: UInt32, sidebarBottom: UInt32, card: UInt32, surface: UInt32
    var stroke: UInt32, ink: UInt32, inkSoft: UInt32, muted: UInt32
    var shadow: UInt32, shadowOpacity: Double
    var chipOff: UInt32, tabTrack: UInt32, tick: UInt32, dotOff: UInt32, restFill: UInt32, dashed: UInt32
    var circleOff: UInt32, weekGhost: UInt32, timelineBg: UInt32, donutTrack: UInt32, outMonth: UInt32
    var typeTrack: UInt32, toggleOff: UInt32, manualFg: UInt32, manualBg: UInt32
    var heat: [UInt32]
    var landFar: (UInt32, UInt32), landMid: (UInt32, UInt32), landNear: (UInt32, UInt32), pine: UInt32
    var green: UInt32

    static let tomato = ThemeColors(
        red: 0xE5473E, redTop: 0xF26B60, redBottom: 0xDB3A32, coral: 0xF08A7C, salmon: 0xF4A595, peach: 0xF8CFC3,
        blush: 0xFBE0D8, blushLight: 0xFDF0EA, track: 0xF3E5DE, barTrack: 0xF6E3DC, barEnd: 0xF07466,
        canvas: 0xFAF4EF, panel: 0xFDF8F4, sidebarTop: 0xF8EFE9, sidebarBottom: 0xF4E4DB, card: 0xFFFCF9, surface: 0xFFFFFF,
        stroke: 0xEFE3DB, ink: 0x2A1C19, inkSoft: 0x5C4A45, muted: 0x9C8781,
        shadow: 0xB98E80, shadowOpacity: 0.16,
        chipOff: 0xF4ECE8, tabTrack: 0xF5EAE4, tick: 0xDCCBC4, dotOff: 0xEADCD6, restFill: 0xF1EBE8, dashed: 0xE2D3CC,
        circleOff: 0xC9B8B2, weekGhost: 0xF9E3DB, timelineBg: 0xFBF2ED, donutTrack: 0xF8E4DC, outMonth: 0xFBF7F5,
        typeTrack: 0xF6EAE4, toggleOff: 0xE6D9D3, manualFg: 0x4A6FA5, manualBg: 0xE4EBF6,
        heat: [0xF4E9E4, 0xF8CDC1, 0xF3A08F, 0xEA685B, 0xD93A31],
        landFar: (0xF0BBAA, 0xF7DCD2), landMid: (0xEDAE9C, 0xF5D3C7), landNear: (0xF8E5DC, 0xFCF3EE), pine: 0x4E5A3C,
        green: 0x2E9E5B)

    static let pink = ThemeColors(
        red: 0xEE4D86, redTop: 0xF76A9C, redBottom: 0xE5437C, coral: 0xF48AAE, salmon: 0xF6A3C0, peach: 0xF9CCDB,
        blush: 0xFCDDE8, blushLight: 0xFEF0F5, track: 0xF5E3EA, barTrack: 0xF7E1EA, barEnd: 0xF78BB1,
        canvas: 0xFBF3F6, panel: 0xFEF8FA, sidebarTop: 0xFAEFF4, sidebarBottom: 0xF6E1EA, card: 0xFFFBFC, surface: 0xFFFFFF,
        stroke: 0xF1E1E8, ink: 0x2B1A22, inkSoft: 0x5E4652, muted: 0xA08592,
        shadow: 0xC48AA0, shadowOpacity: 0.16,
        chipOff: 0xF6EBF0, tabTrack: 0xF7E8EE, tick: 0xE0C9D3, dotOff: 0xEEDCE4, restFill: 0xF3EAEE, dashed: 0xE6D0DA,
        circleOff: 0xCDB5C0, weekGhost: 0xFBE2EB, timelineBg: 0xFCF2F6, donutTrack: 0xF9E3EC, outMonth: 0xFCF8FA,
        typeTrack: 0xF8ECF1, toggleOff: 0xE8D8DF, manualFg: 0x5A6FB0, manualBg: 0xE6EAF7,
        heat: [0xF6EAF0, 0xF9CFDE, 0xF5A3C0, 0xEE6E9C, 0xE0437C],
        landFar: (0xF2B6CA, 0xF8DCE6), landMid: (0xEEA6C0, 0xF6D2DF), landNear: (0xF9E4EC, 0xFDF3F7), pine: 0x5A3B4C,
        green: 0x2E9E5B)

    static let purple = ThemeColors(
        red: 0x8E44FF, redTop: 0xA36BFF, redBottom: 0x7B33F0, coral: 0xB58CFF, salmon: 0x9C7AE0, peach: 0x5E4A8C,
        blush: 0x3E2C68, blushLight: 0x2D2348, track: 0x352B52, barTrack: 0x332A4E, barEnd: 0xB07DFF,
        canvas: 0x17122A, panel: 0x1D1733, sidebarTop: 0x1B1530, sidebarBottom: 0x241A40, card: 0x221B38, surface: 0x2A2244,
        stroke: 0x372D55, ink: 0xF3EFFF, inkSoft: 0xC5BBDF, muted: 0x8A80A6,
        shadow: 0x000000, shadowOpacity: 0.35,
        chipOff: 0x2E2648, tabTrack: 0x2A2244, tick: 0x51456F, dotOff: 0x3B3158, restFill: 0x2E2746, dashed: 0x4A3F6A,
        circleOff: 0x5C507E, weekGhost: 0x3A2F5A, timelineBg: 0x251E3D, donutTrack: 0x332A50, outMonth: 0x1E1834,
        typeTrack: 0x2E2648, toggleOff: 0x40365F, manualFg: 0xA9C1F0, manualBg: 0x2A3352,
        heat: [0x2C2446, 0x4A3780, 0x6A4CB8, 0x8A5CF0, 0xA77BFF],
        landFar: (0x6E54A8, 0x3A2C66), landMid: (0x4C3784, 0x2E2356), landNear: (0x241C40, 0x1C1632), pine: 0x120C24,
        green: 0x3CC27A)
}

/// Theme-aware colors. Views re-render on theme change because the roots are keyed by the theme.
enum Palette {
    private static var c: ThemeColors { ColorTheme.current.colors }

    static var red: Color { Color(hex: c.red) }
    static var redTop: Color { Color(hex: c.redTop) }
    /// Accent for text and icons: the accent itself in light themes, a lighter tint in dark ones.
    static var accentText: Color { ColorTheme.current.isDark ? Color(hex: c.coral) : Color(hex: c.red) }
    static var redBottom: Color { Color(hex: c.redBottom) }
    static var coral: Color { Color(hex: c.coral) }
    static var salmon: Color { Color(hex: c.salmon) }
    static var peach: Color { Color(hex: c.peach) }
    static var blush: Color { Color(hex: c.blush) }
    static var blushLight: Color { Color(hex: c.blushLight) }
    static var track: Color { Color(hex: c.track) }
    static var barTrack: Color { Color(hex: c.barTrack) }
    static var canvas: Color { Color(hex: c.canvas) }
    static var panel: Color { Color(hex: c.panel) }
    static var sidebarTop: Color { Color(hex: c.sidebarTop) }
    static var sidebarBottom: Color { Color(hex: c.sidebarBottom) }
    static var card: Color { Color(hex: c.card) }
    /// Inner fields and tiles (white in light themes).
    static var surface: Color { Color(hex: c.surface) }
    static var stroke: Color { Color(hex: c.stroke) }
    static var ink: Color { Color(hex: c.ink) }
    static var inkSoft: Color { Color(hex: c.inkSoft) }
    static var muted: Color { Color(hex: c.muted) }
    static var green: Color { Color(hex: c.green) }
    static let orange = Color(hex: 0xF0832B)
    static let gold = Color(hex: 0xE8A33A)
    static var pine: Color { Color(hex: c.pine) }
    static let tree = Color(hex: 0x3F8A55)
    static var shadow: Color { Color(hex: c.shadow, opacity: c.shadowOpacity) }
    static var panelShadow: Color { Color(hex: ColorTheme.current.isDark ? 0x000000 : 0x8A5A4A, opacity: ColorTheme.current.isDark ? 0.45 : 0.22) }

    static var chipOff: Color { Color(hex: c.chipOff) }
    static var tabTrack: Color { Color(hex: c.tabTrack) }
    static var tick: Color { Color(hex: c.tick) }
    static var dotOff: Color { Color(hex: c.dotOff) }
    static var restFill: Color { Color(hex: c.restFill) }
    static var dashed: Color { Color(hex: c.dashed) }
    static var circleOff: Color { Color(hex: c.circleOff) }
    static var weekGhost: Color { Color(hex: c.weekGhost) }
    static var timelineBg: Color { Color(hex: c.timelineBg) }
    static var donutTrack: Color { Color(hex: c.donutTrack) }
    static var outMonth: Color { Color(hex: c.outMonth) }
    static var typeTrack: Color { Color(hex: c.typeTrack) }
    static var toggleOff: Color { Color(hex: c.toggleOff) }
    static var manualFg: Color { Color(hex: c.manualFg) }
    static var manualBg: Color { Color(hex: c.manualBg) }
    static var heat: [Color] { c.heat.map { Color(hex: $0) } }

    static var landFar: (Color, Color) { (Color(hex: c.landFar.0, opacity: 0.7), Color(hex: c.landFar.1, opacity: 0.5)) }
    static var landMid: (Color, Color) { (Color(hex: c.landMid.0), Color(hex: c.landMid.1)) }
    static var landNear: (Color, Color) { (Color(hex: c.landNear.0), Color(hex: c.landNear.1)) }

    static var redGradient: LinearGradient {
        LinearGradient(colors: [redTop, redBottom], startPoint: .top, endPoint: .bottom)
    }
    static var barGradient: LinearGradient {
        LinearGradient(colors: [redBottom, Color(hex: c.barEnd)], startPoint: .leading, endPoint: .trailing)
    }
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
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
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
                    .fill(configuration.isOn ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.toggleOff))
                    .frame(width: 46, height: 26)
                Circle()
                    .fill(Color(hex: 0xFFFFFF))
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
    /// Custom label, e.g. minutes shown as "1h 30m".
    var format: ((Int) -> String)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(format?(value) ?? "\(value)\(suffix)")
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
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surface))
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
            .background(Capsule().fill(primary ? AnyShapeStyle(Palette.redGradient) : AnyShapeStyle(Palette.surface)))
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
