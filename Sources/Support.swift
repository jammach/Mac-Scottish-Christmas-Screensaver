import CoreGraphics
import Foundation

typealias F = CGFloat

// MARK: - Deterministic randomness (the scene is a pure function of time, so nothing may use a global RNG)

struct RNG {
    var s: UInt64
    init(_ seed: Int) { s = UInt64(truncatingIfNeeded: seed) &* 0x9E3779B97F4A7C15 &+ 0x1234567 }
    mutating func u() -> F {
        s = s &+ 0x9E3779B97F4A7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return F(z >> 11) / F(UInt64(1) << 53)
    }
    mutating func r(_ a: F, _ b: F) -> F { a + (b - a) * u() }
    mutating func i(_ n: Int) -> Int { min(n - 1, Int(u() * F(n))) }
    mutating func pick<T>(_ a: [T]) -> T { a[i(a.count)] }
    mutating func chance(_ p: F) -> Bool { u() < p }
}

func hashF(_ a: Int, _ b: Int = 0) -> F {
    var x = UInt64(truncatingIfNeeded: a) &* 0x9E3779B97F4A7C15 &+ UInt64(truncatingIfNeeded: b) &* 0xC2B2AE3D27D4EB4F
    x = (x ^ (x >> 33)) &* 0xff51afd7ed558ccd
    x = (x ^ (x >> 33)) &* 0xc4ceb9fe1a85ec53
    x ^= x >> 33
    return F(x >> 11) / F(UInt64(1) << 53)
}

func lerp(_ a: F, _ b: F, _ t: F) -> F { a + (b - a) * t }
func clamp(_ x: F, _ a: F = 0, _ b: F = 1) -> F { min(max(x, a), b) }
func smooth(_ e0: F, _ e1: F, _ x: F) -> F { let t = clamp((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t) }
func twinkle(_ t: Double, _ phase: F, _ rate: F = 2.0) -> F {
    if let b = Bake.current { return b.twinkleValue }
    return pow(max(0, F(sin(t * Double(rate) + Double(phase)))), 6)
}

// MARK: - Colour

struct RGB {
    var r: F, g: F, b: F
    init(_ r: F, _ g: F, _ b: F) { self.r = r; self.g = g; self.b = b }
    init(_ hex: UInt32) {
        r = F((hex >> 16) & 255) / 255; g = F((hex >> 8) & 255) / 255; b = F(hex & 255) / 255
    }
    func cg(_ a: F = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    func mix(_ o: RGB, _ t: F) -> RGB { RGB(lerp(r, o.r, t), lerp(g, o.g, t), lerp(b, o.b, t)) }
    func lighter(_ t: F) -> RGB { mix(RGB(1, 1, 1), t) }
    func darker(_ t: F) -> RGB { mix(RGB(0, 0, 0), t) }
}

enum Pal {
    static let snow = RGB(0xF7FAFF), snowMid = RGB(0xDDE7FF), snowShade = RGB(0xAEBDF4), snowDeep = RGB(0x8392DC)
    static let window = RGB(0xFFD66B), windowHot = RGB(0xFF9F43), warm = RGB(0xFFC15E)
    static let brick = RGB(0xC4553C), brickDark = RGB(0x8F3828), cream = RGB(0xF2DFB6), stone = RGB(0x9CA3BD), stoneDark = RGB(0x6B7295)
    static let slate = RGB(0x5C62A8), slateDark = RGB(0x3C4180), tile = RGB(0xB8503A), tileDark = RGB(0x8A3426)
    static let spruce = RGB(0x1F7A5C), spruceLight = RGB(0x32A070), spruceDark = RGB(0x145040)
    static let bark = RGB(0x4B3428), barkLight = RGB(0x7A5440), gold = RGB(0xFFC93C), silver = RGB(0xDDE6F2)
    static let haze = RGB(0x5560C0), ice = RGB(0xCFEFFF), iceEdge = RGB(0x8EC9F2)
    static let presentPapers: [RGB] = [RGB(0xE63946), RGB(0x2BB35A), RGB(0x3A86FF), RGB(0x9B5DE5), RGB(0xFF7EB6), RGB(0xFF9F1C), RGB(0x17C3B2), RGB(0xFFD23F)]
}

// MARK: - Drawing primitives (y points down; the caller flips the context)

extension CGContext {
    func circle(_ x: F, _ y: F, _ r: F, _ c: CGColor) {
        setFillColor(c); fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
    func ellipse(_ x: F, _ y: F, _ rx: F, _ ry: F, _ c: CGColor) {
        setFillColor(c); fillEllipse(in: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry))
    }
    func rrect(_ r: CGRect, _ rad: F, _ c: CGColor) {
        guard r.width > 0, r.height > 0 else { return }
        setFillColor(c)
        addPath(CGPath(roundedRect: r, cornerWidth: min(rad, r.width / 2), cornerHeight: min(rad, r.height / 2), transform: nil))
        fillPath()
    }
    func poly(_ pts: [CGPoint], _ c: CGColor) {
        guard pts.count > 2 else { return }
        setFillColor(c); move(to: pts[0]); for p in pts.dropFirst() { addLine(to: p) }; closePath(); fillPath()
    }
    func seg(_ a: CGPoint, _ b: CGPoint, _ w: F, _ c: CGColor) {
        setStrokeColor(c); setLineWidth(w); setLineCap(.round)
        move(to: a); addLine(to: b); strokePath()
    }
    func curve(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, _ w: F, _ c: CGColor) {
        setStrokeColor(c); setLineWidth(w); setLineCap(.round)
        move(to: a); addCurve(to: b, control1: c1, control2: c2); strokePath()
    }
    func vgrad(_ rect: CGRect, _ stops: [(RGB, F)], alpha: F = 1) {
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: stops.map { $0.0.cg(alpha) } as CFArray, locations: stops.map { $0.1 })!
        saveGState(); clip(to: rect)
        drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.minX, y: rect.maxY), options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        restoreGState()
    }
    /// Soft additive glow (lights, windows, magic).
    func glow(_ x: F, _ y: F, _ r: F, _ c: RGB, _ a: F) {
        guard a > 0.004, r > 1 else { return }
        Sprites.draw(self, Sprites.glowImage(c), x, y, r, a)
    }
    /// Four-point twinkle star. While baking, it is recorded so it can twinkle at run time instead of being painted in.
    func sparkle(_ x: F, _ y: F, _ r: F, _ c: RGB = Pal.snow, _ a: F = 1) {
        guard r > 0.6, a > 0.02 else { return }
        if let b = Bake.current, b.record {
            let d = b.design(self, x, y)
            let h = hashF(Int(d.point.x * 7 + b.originX * 3), Int(d.point.y * 5))
            b.emitters.append(Emitter(kind: .sparkle, x: d.point.x + b.originX, y: d.point.y, r: r * d.scale, c: c, a: a, phase: h * 6.283, rate: 1.2 + 1.6 * hashF(Int(d.point.x + b.originX), Int(d.point.y) + 3), base: 0, seed: 0, sc: d.scale))
            return
        }
        Sprites.draw(self, Sprites.starImage(c), x, y, r * 1.5, a)
    }
    /// A string-light bulb glow that gently twinkles (recorded while baking).
    func bulbGlow(_ x: F, _ y: F, _ r: F, _ c: RGB, _ aMax: F, phase: F, rate: F, base: F, t: Double) {
        if let b = Bake.current, b.record {
            let d = b.design(self, x, y)
            b.emitters.append(Emitter(kind: .glow, x: d.point.x + b.originX, y: d.point.y, r: r * d.scale, c: c, a: aMax, phase: phase, rate: rate, base: base, seed: 0, sc: d.scale))
            return
        }
        glow(x, y, r, c, aMax * (base + (1 - base) * twinkle(t, phase, rate)))
    }
}

// MARK: - Baking support: things that move or twinkle are recorded while the scenery is cached, then drawn live

struct Emitter {
    enum Kind: UInt8 { case sparkle, glow, smoke }
    var kind: Kind
    var x: F          // layer-space x (world x for the front layer); y is in design units
    var y: F
    var r: F          // size (for smoke: strength)
    var c: RGB
    var a: F
    var phase: F
    var rate: F
    var base: F
    var seed: Int
    var sc: F = 1     // size of the drawing it came from (distant things are drawn smaller)
}

final class BakeState {
    var emitters: [Emitter] = []
    var originX: F = 0
    var record = true
    var twinkleValue: F = 1
    var baseInverse = CGAffineTransform.identity   // device pixels back to design units, as set up at the start of the bake

    /// Where a point drawn in the current (possibly scaled and shifted) coordinates really lands in the tile, and how much it is scaled.
    func design(_ c: CGContext, _ x: F, _ y: F) -> (point: CGPoint, scale: F) {
        let m = c.ctm.concatenating(baseInverse)
        return (CGPoint(x: x, y: y).applying(m), (m.a * m.a + m.b * m.b).squareRoot())
    }
}

enum Bake {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var activeCount = 0
    /// The bake in progress on this thread, if any (a cheap global check first, so live drawing pays almost nothing).
    static var current: BakeState? {
        guard activeCount > 0 else { return nil }
        return Thread.current.threadDictionary["bake"] as? BakeState
    }
    static func begin(_ s: BakeState) {
        lock.lock(); activeCount += 1; lock.unlock()
        Thread.current.threadDictionary["bake"] = s
    }
    static func end() {
        Thread.current.threadDictionary.removeObject(forKey: "bake")
        lock.lock(); activeCount -= 1; lock.unlock()
    }
}

/// Pre-rendered glow and star images, one per colour, drawn with additive blending. Far cheaper than building gradients every time.
enum Sprites {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var stars: [UInt32: CGImage] = [:]
    nonisolated(unsafe) private static var glows: [UInt32: CGImage] = [:]

    private static func key(_ c: RGB) -> UInt32 {
        func q(_ v: F) -> UInt32 { UInt32(clamp(v) * 31 + 0.5) }
        return q(c.r) << 10 | q(c.g) << 5 | q(c.b)
    }
    /// The colour space pictures are drawn in. The live saver sets this to the display's own, so nothing needs converting on the way to the screen.
    nonisolated(unsafe) static var space = CGColorSpace(name: CGColorSpace.sRGB)!
    static func use(space s: CGColorSpace) {
        lock.lock(); space = s; stars.removeAll(); glows.removeAll(); lock.unlock()
    }
    private static func canvas(_ n: Int) -> CGContext {
        CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    }
    private static func radial(_ ctx: CGContext, _ c: RGB, _ peak: F, _ r: F) {
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c.cg(peak), c.cg(peak * 0.35), c.cg(0)] as CFArray, locations: [0, 0.35, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: r, y: r), startRadius: 0, endCenter: CGPoint(x: r, y: r), endRadius: r, options: [])
    }

    static func glowImage(_ c: RGB) -> CGImage {
        let k = key(c)
        lock.lock(); defer { lock.unlock() }
        if let i = glows[k] { return i }
        let ctx = canvas(128)
        radial(ctx, c, 1, 64)
        let img = ctx.makeImage()!
        glows[k] = img
        return img
    }

    /// A unit star: points reach 1/1.5 of the half-size, with a soft halo out to the edge.
    static func starImage(_ c: RGB) -> CGImage {
        let k = key(c)
        lock.lock(); defer { lock.unlock() }
        if let i = stars[k] { return i }
        let ctx = canvas(128)
        radial(ctx, c, 0.5, 64)
        let h: F = 64, r = h / 1.5, kk = r * 0.16
        let p = CGMutablePath()
        p.move(to: CGPoint(x: h, y: h - r))
        p.addQuadCurve(to: CGPoint(x: h + r, y: h), control: CGPoint(x: h + kk, y: h - kk))
        p.addQuadCurve(to: CGPoint(x: h, y: h + r), control: CGPoint(x: h + kk, y: h + kk))
        p.addQuadCurve(to: CGPoint(x: h - r, y: h), control: CGPoint(x: h - kk, y: h + kk))
        p.addQuadCurve(to: CGPoint(x: h, y: h - r), control: CGPoint(x: h - kk, y: h - kk))
        ctx.setFillColor(c.cg(1)); ctx.addPath(p); ctx.fillPath()
        let img = ctx.makeImage()!
        stars[k] = img
        return img
    }

    /// Both sprites are symmetrical, so the flipped coordinate system used for drawing does not matter.
    static func draw(_ ctx: CGContext, _ img: CGImage, _ x: F, _ y: F, _ half: F, _ alpha: F) {
        ctx.saveGState()
        ctx.setBlendMode(.plusLighter); ctx.setAlpha(min(alpha, 1))
        ctx.draw(img, in: CGRect(x: x - half, y: y - half, width: 2 * half, height: 2 * half))
        ctx.restoreGState()
    }
}

// MARK: - Shared decorations

/// Soft snow mounds along a line (roof edges, branches, walls).
func snowMounds(_ c: CGContext, from a: CGPoint, to b: CGPoint, thick: F, seed: Int, shade: Bool = true, lift: F = 0) {
    var rng = RNG(seed)
    let len = hypot(b.x - a.x, b.y - a.y)
    let n = max(2, Int(len / (thick * 0.9)))
    // a continuous soft bank under the lumps so it reads as drifted snow, not beads
    if shade { c.seg(CGPoint(x: a.x, y: a.y - lift + thick * 0.3), CGPoint(x: b.x, y: b.y - lift + thick * 0.3), thick * 1.4, Pal.snowShade.cg()) }
    c.seg(CGPoint(x: a.x, y: a.y - lift), CGPoint(x: b.x, y: b.y - lift), thick * 1.4, Pal.snow.cg())
    for k in 0...n {
        let s = F(k) / F(n)
        let x = lerp(a.x, b.x, s), y = lerp(a.y, b.y, s) - lift
        let r = thick * rng.r(0.75, 1.1)
        if shade { c.circle(x, y + thick * 0.28, r, Pal.snowShade.cg()) }
        c.circle(x, y, r, Pal.snow.cg())
    }
}

/// Hanging icicles with a glint on some tips.
func icicles(_ c: CGContext, y: F, from x0: F, to x1: F, seed: Int, t: Double, maxLen: F = 40, spacing: F = 15) {
    var rng = RNG(seed)
    var x = x0
    while x < x1 {
        let len = rng.r(10, maxLen) * (rng.chance(0.25) ? 1.5 : 1)
        let w = rng.r(5, 9)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x - w / 2, y: y)); p.addLine(to: CGPoint(x: x + w / 2, y: y))
        p.addQuadCurve(to: CGPoint(x: x + 0.5, y: y + len), control: CGPoint(x: x + w * 0.25, y: y + len * 0.6))
        p.addQuadCurve(to: CGPoint(x: x - w / 2, y: y), control: CGPoint(x: x - w * 0.3, y: y + len * 0.55))
        c.setFillColor(Pal.ice.cg(0.92)); c.addPath(p); c.fillPath()
        c.seg(CGPoint(x: x - w * 0.18, y: y + 2), CGPoint(x: x - w * 0.05, y: y + len * 0.7), 1.4, RGB(0xFFFFFF).cg(0.9))
        c.setStrokeColor(Pal.iceEdge.cg(0.7)); c.setLineWidth(1); c.addPath(p); c.strokePath()
        let ph = rng.r(0, 6.28)
        let tw = twinkle(t, ph, 1.7)
        if tw > 0.05 { c.sparkle(x, y + len, 7 + 7 * tw, Pal.snow, tw) }
        x += spacing * rng.r(0.7, 1.4)
    }
}

/// Scatter of twinkling glints across a snowy area (world-anchored via the cell hash).
func glitter(_ c: CGContext, x0: F, x1: F, yTop: (F) -> F, depth: F, t: Double, cell: F = 46, seed: Int = 7) {
    var cx = (x0 / cell).rounded(.down) * cell
    while cx < x1 {
        let id = Int(cx / cell)
        for k in 0..<2 {
            let ph = hashF(id, seed + k * 31) * 6.28
            let tw = twinkle(t, ph, 1.4 + hashF(id, 5 + k) * 1.6)
            if tw > 0.08 {
                let x = cx + hashF(id, 11 + k) * cell
                let y = yTop(x) + 8 + hashF(id, 17 + k) * depth
                c.sparkle(x, y, (5 + 9 * hashF(id, 23 + k)) * (0.5 + tw), id % 3 == 0 ? RGB(0xFFF1B8) : Pal.snow, tw)
            }
        }
        cx += cell
    }
}
