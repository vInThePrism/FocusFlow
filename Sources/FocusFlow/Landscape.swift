import SwiftUI

/// A filled ridge line through normalized points (x, y in 0…1, y from the top).
struct Ridge: Shape {
    var points: [CGPoint]
    var smooth = true

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard !points.isEmpty else { return p }
        let pts = points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: pts[0])
        if smooth {
            for i in 1..<pts.count {
                let a = pts[i - 1], b = pts[i]
                p.addQuadCurve(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), control: a)
            }
            p.addLine(to: pts[pts.count - 1])
        } else {
            for pt in pts.dropFirst() { p.addLine(to: pt) }
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct PineTree: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for i in 0..<3 {
            let t = CGFloat(i) / 3
            let top = r.minY + r.height * t * 0.5
            let bottom = r.minY + r.height * (0.42 + t * 0.4)
            let half = r.width * (0.26 + t * 0.24)
            p.move(to: CGPoint(x: r.midX, y: top))
            p.addLine(to: CGPoint(x: r.midX + half, y: bottom))
            p.addLine(to: CGPoint(x: r.midX - half, y: bottom))
            p.closeSubpath()
        }
        p.addRect(CGRect(x: r.midX - r.width * 0.07, y: r.minY + r.height * 0.8, width: r.width * 0.14, height: r.height * 0.2))
        return p
    }
}

private struct TreeSpot {
    let x: CGFloat
    let base: CGFloat
    let height: CGFloat
}

/// Soft peach mountains with a few pines, used in the sidebar and on cards.
struct LandscapeView: View {
    enum Variant { case sidebar, card, corner }
    var variant: Variant

    private var far: [CGPoint] {
        switch variant {
        case .sidebar:
            return [CGPoint(x: 0, y: 0.34), CGPoint(x: 0.16, y: 0.2), CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.48, y: 0.12),
                    CGPoint(x: 0.64, y: 0.27), CGPoint(x: 0.82, y: 0.17), CGPoint(x: 1, y: 0.3)]
        case .card:
            return [CGPoint(x: 0, y: 0.55), CGPoint(x: 0.2, y: 0.38), CGPoint(x: 0.38, y: 0.5), CGPoint(x: 0.58, y: 0.22),
                    CGPoint(x: 0.74, y: 0.4), CGPoint(x: 0.88, y: 0.28), CGPoint(x: 1, y: 0.42)]
        case .corner:
            return [CGPoint(x: 0, y: 0.75), CGPoint(x: 0.3, y: 0.45), CGPoint(x: 0.5, y: 0.55), CGPoint(x: 0.72, y: 0.25),
                    CGPoint(x: 0.88, y: 0.4), CGPoint(x: 1, y: 0.3)]
        }
    }

    private var mid: [CGPoint] {
        switch variant {
        case .sidebar:
            return [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.22, y: 0.4), CGPoint(x: 0.48, y: 0.5), CGPoint(x: 0.74, y: 0.42), CGPoint(x: 1, y: 0.52)]
        case .card:
            return [CGPoint(x: 0, y: 0.75), CGPoint(x: 0.3, y: 0.6), CGPoint(x: 0.6, y: 0.68), CGPoint(x: 0.85, y: 0.5), CGPoint(x: 1, y: 0.58)]
        case .corner:
            return [CGPoint(x: 0, y: 0.95), CGPoint(x: 0.35, y: 0.7), CGPoint(x: 0.7, y: 0.62), CGPoint(x: 1, y: 0.5)]
        }
    }

    private var near: [CGPoint] {
        switch variant {
        case .sidebar:
            return [CGPoint(x: 0, y: 0.7), CGPoint(x: 0.35, y: 0.62), CGPoint(x: 0.7, y: 0.7), CGPoint(x: 1, y: 0.64)]
        case .card:
            return [CGPoint(x: 0, y: 0.9), CGPoint(x: 0.4, y: 0.82), CGPoint(x: 0.75, y: 0.88), CGPoint(x: 1, y: 0.8)]
        case .corner:
            return [CGPoint(x: 0, y: 1.0), CGPoint(x: 0.5, y: 0.9), CGPoint(x: 1, y: 0.82)]
        }
    }

    private var trees: [TreeSpot] {
        switch variant {
        case .sidebar:
            return [TreeSpot(x: 0.08, base: 0.52, height: 0.13), TreeSpot(x: 0.14, base: 0.5, height: 0.17),
                    TreeSpot(x: 0.2, base: 0.49, height: 0.11), TreeSpot(x: 0.62, base: 0.5, height: 0.12),
                    TreeSpot(x: 0.68, base: 0.49, height: 0.16), TreeSpot(x: 0.74, base: 0.5, height: 0.1),
                    TreeSpot(x: 0.86, base: 0.53, height: 0.12)]
        case .card:
            return [TreeSpot(x: 0.84, base: 0.62, height: 0.3), TreeSpot(x: 0.89, base: 0.6, height: 0.4),
                    TreeSpot(x: 0.94, base: 0.62, height: 0.28)]
        case .corner:
            return [TreeSpot(x: 0.8, base: 0.66, height: 0.3), TreeSpot(x: 0.86, base: 0.64, height: 0.4),
                    TreeSpot(x: 0.92, base: 0.62, height: 0.32)]
        }
    }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                Ridge(points: far, smooth: false)
                    .fill(LinearGradient(colors: [Palette.landFar.0, Palette.landFar.1],
                                         startPoint: .top, endPoint: .bottom))
                Ridge(points: mid)
                    .fill(LinearGradient(colors: [Palette.landMid.0, Palette.landMid.1],
                                         startPoint: .top, endPoint: .bottom))
                ForEach(trees.indices, id: \.self) { i in
                    let t = trees[i]
                    let h = t.height * g.size.height
                    PineTree()
                        .fill(Palette.pine.opacity(0.78))
                        .frame(width: h * 0.55, height: h)
                        .position(x: t.x * g.size.width, y: t.base * g.size.height - h / 2 + h * 0.08)
                }
                Ridge(points: near)
                    .fill(LinearGradient(colors: [Palette.landNear.0, Palette.landNear.1],
                                         startPoint: .top, endPoint: .bottom))
            }
        }
        .allowsHitTesting(false)
    }
}
