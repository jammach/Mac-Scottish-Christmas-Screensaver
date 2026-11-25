import CoreGraphics
import Foundation

// MARK: - Trees (typical UK species, drawn storybook-style with deep snow)

enum TreeKind: Int { case spruce, pine, oak, birch, beech, holly, rowan }

struct Tree {
    var kind: TreeKind
    var topY: F      // top of the crown on screen
    var h: F         // crown height
    var w: F         // crown width
    var seed: Int
    var decorated = false
    var base: F = 1100   // where the trunk meets the ground
}

func drawTree(_ c: CGContext, _ tr: Tree, x: F, t: Double) {
    switch tr.kind {
    case .spruce: drawSpruce(c, tr, x, t)
    case .pine: drawPine(c, tr, x, t)
    case .oak: drawBare(c, tr, x, t, trunk: Pal.bark, thick: 1.0, berries: false)
    case .rowan: drawBare(c, tr, x, t, trunk: RGB(0x6B5648), thick: 0.7, berries: true)
    case .birch: drawBirch(c, tr, x, t)
    case .beech: drawBeech(c, tr, x, t)
    case .holly: drawHolly(c, tr, x, t)
    }
}

private func drawSpruce(_ c: CGContext, _ tr: Tree, _ x: F, _ t: Double) {
    let n = 5
    let tierH = tr.h * 0.38
    let step = (tr.h - tierH) / F(n - 1)
    c.rrect(CGRect(x: x - 9, y: tr.topY + tr.h - 10, width: 18, height: tr.base - tr.topY - tr.h), 4, Pal.bark.cg())
    for i in stride(from: n - 1, through: 0, by: -1) {
        let yTop = tr.topY + F(i) * step, yBot = yTop + tierH
        let hw = tr.w / 2 * (0.34 + 0.66 * F(i) / F(n - 1))
        let m = max(3, Int(hw * 2 / 26))
        let bump = hw * 2 / F(m)
        let body = Pal.spruce.mix(Pal.spruceLight, 0.15 * F(i % 2))
        c.poly([CGPoint(x: x, y: yTop), CGPoint(x: x + hw, y: yBot), CGPoint(x: x - hw, y: yBot)], body.cg())
        for k in 0..<m { c.circle(x - hw + (F(k) + 0.5) * bump, yBot, bump * 0.56, body.cg()) }
        c.poly([CGPoint(x: x, y: yTop), CGPoint(x: x, y: yBot + bump * 0.4), CGPoint(x: x - hw, y: yBot + 2)], Pal.spruceDark.cg(0.42))
        let thick = 8 + F(i) * 1.6
        snowMounds(c, from: CGPoint(x: x, y: yTop + 4), to: CGPoint(x: x + hw - 10, y: yBot - 12), thick: thick, seed: tr.seed + i * 3)
        snowMounds(c, from: CGPoint(x: x, y: yTop + 4), to: CGPoint(x: x - hw + 10, y: yBot - 12), thick: thick, seed: tr.seed + i * 3 + 1)
        for k in stride(from: 0, to: m, by: 2) { c.circle(x - hw + (F(k) + 0.5) * bump, yBot - 2, 7, Pal.snow.cg()) }
        if i >= n - 2 { icicles(c, y: yBot + 3, from: x - hw + 14, to: x + hw - 14, seed: tr.seed + 50 + i, t: t, maxLen: 24, spacing: 24) }
        if tr.decorated {
            let cols = [RGB(0xFF4D6D), RGB(0xFFD23F), RGB(0x4CC9F0), RGB(0xB5E48C)]
            for k in 0..<m {
                let bx = x - hw + (F(k) + 0.5) * bump, by = yBot - 4
                let col = cols[(k + i) % 4]
                c.circle(bx, by, 4.5, col.cg()); c.bulbGlow(bx, by, 22, col, 0.55, phase: F(k * 2 + i), rate: 2.2, base: 0.55, t: t)
            }
        }
    }
    if tr.decorated { c.sparkle(x, tr.topY - 2, 26 + 6 * twinkle(t, F(tr.seed), 1.6), Pal.gold, 1); c.circle(x, tr.topY + 2, 5, Pal.gold.cg()) }
}

private func drawPine(_ c: CGContext, _ tr: Tree, _ x: F, _ t: Double) {
    var rng = RNG(tr.seed)
    let crownBase = tr.topY + tr.h * 0.42
    let trunkTop = tr.topY + tr.h * 0.12
    c.poly([CGPoint(x: x - 15, y: tr.base), CGPoint(x: x - 9, y: trunkTop), CGPoint(x: x + 9, y: trunkTop), CGPoint(x: x + 15, y: tr.base)], RGB(0x7B4A35).cg())
    c.poly([CGPoint(x: x - 11, y: crownBase + tr.h * 0.5), CGPoint(x: x - 8, y: trunkTop), CGPoint(x: x + 8, y: trunkTop), CGPoint(x: x + 11, y: crownBase + tr.h * 0.5)], RGB(0xD2792E).cg())
    c.poly([CGPoint(x: x + 2, y: crownBase + tr.h * 0.5), CGPoint(x: x + 2, y: trunkTop), CGPoint(x: x + 8, y: trunkTop), CGPoint(x: x + 11, y: crownBase + tr.h * 0.5)], RGB(0xB5601F).cg(0.7))
    let clumps: [(F, F, F)] = [(0, 0, 0.30), (-0.36, 0.22, 0.24), (0.34, 0.16, 0.25), (-0.12, 0.42, 0.2), (0.2, 0.46, 0.19)]
    for (k, cl) in clumps.enumerated() {
        let cx = x + cl.0 * tr.w, cy = tr.topY + cl.1 * tr.h + tr.h * 0.12, r = cl.2 * tr.w
        c.seg(CGPoint(x: x, y: min(crownBase + tr.h * 0.35, cy + r * 0.8)), CGPoint(x: cx, y: cy + r * 0.2), 7, RGB(0x8A4F35).cg())
        for j in 0..<7 {
            let a = rng.r(0, 6.28), d = rng.r(0, r * 0.7)
            c.ellipse(cx + cos(a) * d, cy + sin(a) * d * 0.5, r * 0.5, r * 0.34, RGB(0x2D7A66).mix(RGB(0x1B5A4E), CGFloat(j % 3) / 3).cg())
        }
        c.ellipse(cx, cy + r * 0.28, r * 0.9, r * 0.3, RGB(0x1B5A4E).cg(0.5))
        for j in 0..<6 {
            let a = F(j) / 5 * 3.0 - 1.5
            c.circle(cx + a * r * 0.55, cy - r * 0.22 - abs(a) * 3, r * 0.34, Pal.snow.cg())
        }
        c.ellipse(cx, cy - r * 0.05, r * 0.95, r * 0.2, Pal.snowShade.cg(0.55))
        if k % 2 == 0 { icicles(c, y: cy + r * 0.34, from: cx - r * 0.7, to: cx + r * 0.7, seed: tr.seed + k, t: t, maxLen: 20, spacing: 20) }
        let tw = twinkle(t, F(tr.seed + k * 5), 1.5)
        if tw > 0.1 { c.sparkle(cx + r * 0.2, cy - r * 0.4, 9 + 8 * tw, Pal.snow, tw) }
    }
}

/// Bare branching tree (oak, rowan) with snow along the boughs.
private func drawBare(_ c: CGContext, _ tr: Tree, _ x: F, _ t: Double, trunk: RGB, thick: F, berries: Bool) {
    var rng = RNG(tr.seed)
    let trunkTop = tr.topY + tr.h * 0.58
    let bw = 38 * thick
    c.poly([CGPoint(x: x - bw * 0.62, y: tr.base), CGPoint(x: x - bw * 0.3, y: trunkTop + 20), CGPoint(x: x + bw * 0.3, y: trunkTop + 20), CGPoint(x: x + bw * 0.62, y: tr.base)], trunk.cg())
    var robin: CGPoint? = nil
    func branch(_ x1: F, _ y1: F, _ ang: F, _ len: F, _ wid: F, _ depth: Int) {
        let x2 = x1 + cos(ang) * len, y2 = y1 + sin(ang) * len
        c.seg(CGPoint(x: x1, y: y1), CGPoint(x: x2, y: y2), wid, trunk.mix(RGB(0x2C1E18), CGFloat(5 - depth) * 0.06).cg())
        if sin(ang) < -0.15 && depth >= 1 {
            c.seg(CGPoint(x: x1, y: y1 - wid * 0.55), CGPoint(x: x2, y: y2 - wid * 0.55), max(2.5, wid * 0.62), Pal.snow.cg())
        }
        if depth > 0 {
            let kids = depth >= 4 ? 3 : (rng.chance(0.35) ? 3 : 2)
            for k in 0..<kids {
                let spread = kids == 3 ? (F(k) - 1) * 0.62 : (k == 0 ? -0.5 : 0.5)
                branch(x2, y2, ang + spread + rng.r(-0.2, 0.2), len * rng.r(0.7, 0.8), max(1.8, wid * 0.66), depth - 1)
            }
        } else {
            if berries {
                for j in 0..<5 {
                    let bx = x2 + rng.r(-9, 9), by = y2 + rng.r(-3, 9)
                    c.circle(bx, by, 4.4, RGB(0xF0522E).cg()); c.circle(bx - 1.2, by - 1.4, 1.5, RGB(0xFFB199).cg())
                    _ = j
                }
            }
            c.circle(x2, y2 - 2, 3.4, Pal.snow.cg())
        }
        if depth == 3 && robin == nil && rng.chance(0.4) { robin = CGPoint(x: x2, y: y2) }
    }
    let limbLen = tr.h * 0.3
    for (k, a) in [-1.0, -0.38, 0.38, 1.0].enumerated() {
        branch(x + F(a) * bw * 0.18, trunkTop + 24, -.pi / 2 + F(a) * 0.62, limbLen * rng.r(0.85, 1.1), bw * 0.34, 4 + (k == 1 || k == 2 ? 1 : 0))
    }
    c.circle(x, trunkTop + 8, bw * 0.36, trunk.cg())
    c.circle(x, trunkTop + 2, bw * 0.3, Pal.snow.cg())
    if tr.seed % 3 == 0, let r = robin { drawRobin(c, r.x, r.y - 2, t) }
}

func drawRobin(_ c: CGContext, _ x: F, _ y: F, _ t: Double) {
    let bob = F(sin(t * 3.1)) * 1.2
    c.seg(CGPoint(x: x - 8, y: y - 7 + bob), CGPoint(x: x - 20, y: y - 3 + bob), 4, RGB(0x6B4A36).cg())
    c.circle(x, y - 10 + bob, 10, RGB(0x7A573E).cg())
    c.circle(x + 3, y - 7 + bob, 8, RGB(0xFF6A3D).cg())
    c.circle(x + 5, y - 19 + bob, 7, RGB(0x7A573E).cg())
    c.circle(x + 8, y - 17 + bob, 5, RGB(0xFF6A3D).cg())
    c.poly([CGPoint(x: x + 11, y: y - 20 + bob), CGPoint(x: x + 18, y: y - 18 + bob), CGPoint(x: x + 11, y: y - 16 + bob)], RGB(0xFFC15E).cg())
    c.circle(x + 7, y - 21 + bob, 1.8, RGB(0x1B1B2F).cg())
    c.seg(CGPoint(x: x - 1, y: y - 1 + bob), CGPoint(x: x - 1, y: y + 4), 1.6, RGB(0x6B4A36).cg())
}

private func drawBirch(_ c: CGContext, _ tr: Tree, _ x: F, _ t: Double) {
    var rng = RNG(tr.seed)
    let trunkTop = tr.topY + tr.h * 0.5
    c.poly([CGPoint(x: x - 11, y: tr.base), CGPoint(x: x - 6, y: trunkTop), CGPoint(x: x + 6, y: trunkTop), CGPoint(x: x + 11, y: tr.base)], RGB(0xF4F6FF).cg())
    c.poly([CGPoint(x: x + 3, y: tr.base), CGPoint(x: x + 2, y: trunkTop), CGPoint(x: x + 6, y: trunkTop), CGPoint(x: x + 11, y: tr.base)], RGB(0xC9C4EA).cg(0.8))
    var y = trunkTop + 20
    while y < 1060 { c.rrect(CGRect(x: x - 9 + rng.r(0, 8), y: y, width: rng.r(5, 10), height: 2.6), 1.3, RGB(0x2B2B46).cg(0.85)); y += rng.r(18, 40) }
    func twig(_ x1: F, _ y1: F, _ ang: F, _ len: F, _ wid: F, _ depth: Int) {
        let x2 = x1 + cos(ang) * len, y2 = y1 + sin(ang) * len
        let col = wid > 4.2 ? RGB(0xF0F2FF) : RGB(0x9A7FA8)
        c.curve(CGPoint(x: x1, y: y1), CGPoint(x: x1 + (x2 - x1) * 0.5, y: y1 + (y2 - y1) * 0.3), CGPoint(x: x2, y: y2 - 4), CGPoint(x: x2, y: y2 + (depth == 0 ? 20 : 0)), wid, col.cg())
        if depth > 0 {
            for k in 0..<2 { twig(x2, y2, ang + (k == 0 ? -0.55 : 0.55) + rng.r(-0.25, 0.25), len * rng.r(0.68, 0.8), max(1.4, wid * 0.66), depth - 1) }
        } else {
            c.circle(x2, y2 + 4, 3, Pal.snow.cg(0.95))
        }
    }
    for a in [-0.8, -0.3, 0.2, 0.7] { twig(x + F(a) * 4, trunkTop + 30 - F(abs(a)) * 20, -.pi / 2 + F(a) * 0.55, tr.h * 0.3, 7, 4) }
    for k in 0..<4 { c.circle(x + rng.r(-tr.w * 0.3, tr.w * 0.3), tr.topY + rng.r(0, tr.h * 0.3), 5, Pal.snow.cg(0.9)); _ = k }
}

private func drawBeech(_ c: CGContext, _ tr: Tree, _ x: F, _ t: Double) {
    var rng = RNG(tr.seed)
    let cy = tr.topY + tr.h * 0.42
    c.poly([CGPoint(x: x - 14, y: tr.base), CGPoint(x: x - 8, y: cy + tr.h * 0.2), CGPoint(x: x + 8, y: cy + tr.h * 0.2), CGPoint(x: x + 14, y: tr.base)], RGB(0x8E8AA6).cg())
    let cols = [RGB(0xB5612B), RGB(0xD58A3A), RGB(0xA14C23), RGB(0xC9722F)]
    var tops: [(F, F, F)] = []
    for k in 0..<16 {
        let a = rng.r(0, 6.28), d = sqrt(rng.u())
        let cx = x + cos(a) * d * tr.w * 0.38, cyy = cy + sin(a) * d * tr.h * 0.36
        let r = rng.r(0.16, 0.26) * tr.w
        c.circle(cx, cyy, r, cols[k % 4].cg()); c.circle(cx + r * 0.22, cyy + r * 0.3, r * 0.78, RGB(0x6E3418).cg(0.28)); c.circle(cx - r * 0.28, cyy - r * 0.3, r * 0.42, RGB(0xF2B35E).cg(0.45)); tops.append((cx, cyy, r))
    }
    for (cx, cyy, r) in tops where cyy < cy + tr.h * 0.05 {
        c.circle(cx, cyy - r * 0.55, r * 0.62, Pal.snow.cg())
        c.circle(cx + r * 0.3, cyy - r * 0.35, r * 0.4, Pal.snowMid.cg())
    }
    for _ in 0..<26 { c.ellipse(x + rng.r(-tr.w * 0.4, tr.w * 0.4), cy + rng.r(-tr.h * 0.36, tr.h * 0.4), 3.2, 1.8, RGB(0xF0A94A).cg(0.8)) }
    let tw = twinkle(t, F(tr.seed), 1.3)
    if tw > 0.1 { c.sparkle(x + rng.r(-30, 30), tr.topY + tr.h * 0.12, 11 + 8 * tw, Pal.snow, tw) }
}

private func drawHolly(_ c: CGContext, _ tr: Tree, _ x: F, _ t: Double) {
    var rng = RNG(tr.seed)
    let cy = tr.topY + tr.h * 0.5
    c.poly([CGPoint(x: x - 10, y: tr.base), CGPoint(x: x - 6, y: cy + tr.h * 0.3), CGPoint(x: x + 6, y: cy + tr.h * 0.3), CGPoint(x: x + 10, y: tr.base)], Pal.bark.cg())
    for k in 0..<13 {
        let a = rng.r(0, 6.28), d = sqrt(rng.u())
        let cx = x + cos(a) * d * tr.w * 0.36, cyy = cy + sin(a) * d * tr.h * 0.4
        let r = rng.r(0.15, 0.22) * tr.w
        var pts: [CGPoint] = []
        for j in 0..<14 { let aa = F(j) / 14 * 6.283; let rr = j % 2 == 0 ? r : r * 0.72; pts.append(CGPoint(x: cx + cos(aa) * rr, y: cyy + sin(aa) * rr * 0.9)) }
        c.poly(pts, (k % 3 == 0 ? RGB(0x2E8A4E) : RGB(0x1B6B3C)).cg())
        c.circle(cx - r * 0.25, cyy - r * 0.28, r * 0.28, RGB(0x6CC78A).cg(0.55))
        if cyy < cy { c.circle(cx, cyy - r * 0.62, r * 0.55, Pal.snow.cg()) }
    }
    for _ in 0..<16 {
        let bx = x + rng.r(-tr.w * 0.34, tr.w * 0.34), by = cy + rng.r(-tr.h * 0.3, tr.h * 0.34)
        c.circle(bx, by, 5, RGB(0xE63946).cg()); c.circle(bx - 1.4, by - 1.6, 1.7, RGB(0xFFC2C8).cg())
    }
}

// MARK: - Small snowy things

func drawSheep(_ c: CGContext, x: F, y: F, s: F, t: Double, seed: Int) {
    c.saveGState(); c.translateBy(x: x, y: y); c.scaleBy(x: s, y: s)
    let graze = max(0, F(sin(t * 0.9 + F(seed)))) * 8
    for lx in [-22.0, -10.0, 14.0, 26.0] { c.seg(CGPoint(x: lx, y: -16), CGPoint(x: lx, y: -2), 5, RGB(0x3B3550).cg()) }
    c.ellipse(0, -36, 42, 27, Pal.snowShade.cg())
    for (cx, cy, r) in [(-26.0, -40.0, 17.0), (-10, -52, 19), (12, -53, 19), (28, -42, 17), (0, -34, 22), (-20, -28, 15), (22, -28, 15)] {
        c.circle(cx, cy, r, RGB(0xF4F1FF).cg())
    }
    for (cx, cy, r) in [(-10.0, -60.0, 11.0), (12, -61, 11), (-24, -50, 9)] { c.circle(cx, cy, r, Pal.snow.cg()) }
    let hx: F = 42, hy: F = -34 + graze
    c.seg(CGPoint(x: 30, y: -38), CGPoint(x: hx, y: hy), 12, RGB(0x4A4560).cg())
    c.ellipse(hx + 4, hy + 2, 11, 13, RGB(0x4A4560).cg())
    c.ellipse(hx - 6, hy - 6, 9, 4.5, RGB(0x3B3550).cg())
    c.circle(hx + 7, hy - 2, 2.4, RGB(0xFFFFFF).cg()); c.circle(hx + 7.5, hy - 2, 1.1, RGB(0x111122).cg())
    c.circle(hx, hy - 14, 6, Pal.snow.cg())
    c.restoreGState()
}

func drawSnowman(_ c: CGContext, x: F, y: F, s: F, t: Double) {
    c.saveGState(); c.translateBy(x: x, y: y); c.scaleBy(x: s, y: s)
    c.ellipse(0, 2, 56, 11, Pal.snowShade.cg(0.5))
    for (cy, r) in [(-44.0, 46.0), (-110, 34), (-160, 25)] {
        c.circle(0, cy, r, Pal.snow.cg()); c.circle(r * 0.22, cy + r * 0.12, r * 0.82, Pal.snowMid.cg(0.55))
    }
    c.seg(CGPoint(x: -30, y: -112), CGPoint(x: -78, y: -140 + F(sin(t * 1.4)) * 4), 5, Pal.bark.cg())
    c.seg(CGPoint(x: 30, y: -112), CGPoint(x: 76, y: -136), 5, Pal.bark.cg())
    c.rrect(CGRect(x: -22, y: -140, width: 44, height: 12), 5, RGB(0xE63946).cg())
    let fl = F(sin(t * 2.6)) * 5
    c.poly([CGPoint(x: 8, y: -132), CGPoint(x: 26 + fl, y: -118), CGPoint(x: 20 + fl, y: -102), CGPoint(x: 4, y: -126)], RGB(0xE63946).cg())
    c.seg(CGPoint(x: 14, y: -128), CGPoint(x: 22 + fl, y: -112), 5, Pal.gold.cg())
    for dy in [-118.0, -102, -86] { c.circle(0, dy, 3.2, RGB(0x23233F).cg()) }
    c.circle(-9, -166, 3.4, RGB(0x23233F).cg()); c.circle(9, -166, 3.4, RGB(0x23233F).cg())
    c.poly([CGPoint(x: 0, y: -160), CGPoint(x: 26, y: -154), CGPoint(x: 0, y: -151)], RGB(0xFF8A1F).cg())
    for k in 0..<5 { let a = F(k) / 4 * 1.8 + 0.7; c.circle(cos(a) * 11, -150 + sin(a) * 7, 1.8, RGB(0x23233F).cg()) }
    c.ellipse(0, -182, 26, 7, RGB(0x2B2B4F).cg()); c.rrect(CGRect(x: -16, y: -212, width: 32, height: 30), 4, RGB(0x2B2B4F).cg())
    c.rrect(CGRect(x: -16, y: -194, width: 32, height: 6), 2, RGB(0xE63946).cg())
    c.circle(0, -216, 6, Pal.snow.cg())
    c.restoreGState()
}

func drawFence(_ c: CGContext, x: F, y: F, len: F, t: Double, seed: Int) {
    var px = x
    while px <= x + len + 1 {
        c.rrect(CGRect(x: px - 6, y: y - 56, width: 12, height: 60), 4, RGB(0x6B4A3A).cg())
        c.circle(px, y - 58, 9, Pal.snow.cg()); c.circle(px + 3, y - 54, 6, Pal.snowShade.cg(0.6))
        px += 64
    }
    for ry in [y - 44, y - 22] {
        c.rrect(CGRect(x: x - 4, y: ry, width: len + 8, height: 8), 3, RGB(0x7C5A48).cg())
        c.rrect(CGRect(x: x - 4, y: ry - 5, width: len + 8, height: 7), 3.5, Pal.snow.cg())
        icicles(c, y: ry + 8, from: x + 6, to: x + len - 6, seed: seed + Int(ry), t: t, maxLen: 24, spacing: 16)
    }
}

func drawWall(_ c: CGContext, x: F, y: F, len: F, t: Double, seed: Int) {
    var rng = RNG(seed)
    c.rrect(CGRect(x: x, y: y - 50, width: len, height: 54), 6, Pal.stoneDark.cg())
    for row in 0..<3 {
        var sx = x + (row % 2 == 0 ? 0 : -16)
        let sy = y - 50 + F(row) * 17
        while sx < x + len {
            let w = rng.r(26, 48)
            let l = max(sx, x), r = min(sx + w - 3, x + len)
            if r > l { c.rrect(CGRect(x: l, y: sy + 1, width: r - l, height: 15), 6, Pal.stone.mix(RGB(0x7E86A6), rng.u()).cg()) }
            sx += w
        }
    }
    snowMounds(c, from: CGPoint(x: x + 6, y: y - 52), to: CGPoint(x: x + len - 6, y: y - 52), thick: 13, seed: seed + 1)
    icicles(c, y: y - 36, from: x + 10, to: x + len - 10, seed: seed + 2, t: t, maxLen: 20, spacing: 22)
}

func drawHedge(_ c: CGContext, x: F, y: F, len: F, t: Double, seed: Int) {
    var rng = RNG(seed)
    var px = x
    while px < x + len {
        let r = rng.r(20, 30)
        c.circle(px, y - 24 - rng.r(0, 14), r, (rng.chance(0.5) ? RGB(0x1D5B3E) : RGB(0x2A7650)).cg()); px += r * 0.8
    }
    c.rrect(CGRect(x: x - 10, y: y - 30, width: len + 20, height: 34), 14, RGB(0x1D5B3E).cg())
    px = x
    while px < x + len {
        c.circle(px, y - 52 - rng.r(0, 8), rng.r(10, 16), Pal.snow.cg())
        if rng.chance(0.5) { c.circle(px + rng.r(-10, 10), y - 34, 3.8, RGB(0xE63946).cg()) }
        px += rng.r(18, 28)
    }
}

func drawGate(_ c: CGContext, x: F, y: F, t: Double, seed: Int) {
    for gx in [x, x + 110] {
        c.rrect(CGRect(x: gx - 8, y: y - 92, width: 16, height: 96), 4, RGB(0x6B4A3A).cg())
        c.circle(gx, y - 94, 11, Pal.snow.cg())
    }
    for i in 0..<5 {
        let by = y - 80 + F(i) * 16
        c.rrect(CGRect(x: x + 6, y: by, width: 98, height: 7), 3, RGB(0x8A6450).cg())
        c.rrect(CGRect(x: x + 6, y: by - 4, width: 98, height: 5), 2.5, Pal.snow.cg())
    }
    c.seg(CGPoint(x: x + 8, y: y - 12), CGPoint(x: x + 102, y: y - 78), 6, RGB(0x8A6450).cg())
    icicles(c, y: y - 6, from: x + 14, to: x + 100, seed: seed, t: t, maxLen: 26, spacing: 15)
}

func drawLamp(_ c: CGContext, x: F, y: F, t: Double) {
    c.rrect(CGRect(x: x - 5, y: y - 190, width: 10, height: 194), 3, RGB(0x2D3556).cg())
    c.rrect(CGRect(x: x - 14, y: y - 12, width: 28, height: 16), 5, RGB(0x2D3556).cg())
    c.glow(x, y - 214, 150, Pal.warm, 0.8)
    c.rrect(CGRect(x: x - 15, y: y - 236, width: 30, height: 40), 7, Pal.window.cg())
    c.rrect(CGRect(x: x - 15, y: y - 236, width: 30, height: 40), 7, RGB(0xFFFFFF).cg(0.15))
    c.seg(CGPoint(x: x, y: y - 236), CGPoint(x: x, y: y - 196), 3, RGB(0x2D3556).cg())
    c.poly([CGPoint(x: x - 22, y: y - 236), CGPoint(x: x, y: y - 258), CGPoint(x: x + 22, y: y - 236)], RGB(0x2D3556).cg())
    snowMounds(c, from: CGPoint(x: x - 14, y: y - 244), to: CGPoint(x: x + 8, y: y - 254), thick: 8, seed: Int(x))
    c.circle(x, y - 261, 6, Pal.snow.cg())
    c.sparkle(x, y - 214, 20 + 10 * twinkle(t, x, 1.1), Pal.window, 0.9)
}

func drawPond(_ c: CGContext, x: F, y: F, w: F, t: Double) {
    c.ellipse(x, y, w / 2 + 14, 24, Pal.snow.cg())
    c.ellipse(x, y + 2, w / 2, 17, RGB(0xA9D8FF).cg())
    c.ellipse(x - w * 0.08, y - 1, w * 0.36, 10, RGB(0xCDEBFF).cg(0.8))
    c.seg(CGPoint(x: x - w * 0.3, y: y - 4), CGPoint(x: x - w * 0.12, y: y - 6), 2.5, RGB(0xFFFFFF).cg(0.9))
    c.seg(CGPoint(x: x + w * 0.05, y: y + 5), CGPoint(x: x + w * 0.24, y: y + 3), 2, RGB(0xFFFFFF).cg(0.8))
    for k in 0..<5 {
        let tw = twinkle(t, F(k) * 1.7 + x, 1.6)
        c.sparkle(x - w * 0.3 + F(k) * w * 0.15, y + F(k % 2) * 6 - 2, 8 + 9 * tw, Pal.snow, 0.35 + tw)
    }
}

// MARK: - Distant tiny trees for the far forest line

func drawFarTree(_ c: CGContext, x: F, base: F, h: F, col: CGColor, snow: CGColor) {
    let w = h * 0.42
    c.poly([CGPoint(x: x, y: base - h), CGPoint(x: x + w, y: base), CGPoint(x: x - w, y: base)], col)
    c.poly([CGPoint(x: x, y: base - h), CGPoint(x: x + w * 0.5, y: base - h * 0.5), CGPoint(x: x - w * 0.5, y: base - h * 0.5)], snow)
}
