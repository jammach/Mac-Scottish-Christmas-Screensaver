import CoreGraphics
import Foundation

struct Chimney {
    var dx: F            // offset from the house centre
    var w: F
    var topY: F          // top of the stack (under the cap)
    var pots: Int
    var smoke: Bool
    var aerial: Bool
    var rimY: F { topY - 36 }
    func potDX(_ i: Int) -> F { pots == 1 ? 0 : (F(i) / F(pots - 1) - 0.5) * (w - 30) }
}

struct House {
    var w: F
    var eaveY: F
    var roofH: F
    var baseY: F
    var wall: RGB
    var roof: RGB
    var stone: Bool
    var chimneys: [Chimney]
    var lights: Bool
    var attic: Bool
    var seed: Int
    var apexY: F { eaveY - roofH }
    func roofY(at dx: F) -> F { apexY + min(1, abs(dx) / (w / 2 + 16)) * roofH }
}

// MARK: - Windows, doors, aerials, smoke

func drawWindow(_ c: CGContext, _ r: CGRect, style: Int, t: Double, seed: Int) {
    c.glow(r.midX, r.midY, r.width * 1.9, Pal.warm, 0.5)
    c.rrect(r.insetBy(dx: -5, dy: -5), 7, RGB(0xF3E7C9).cg())
    c.saveGState()
    c.addPath(CGPath(roundedRect: r, cornerWidth: 5, cornerHeight: 5, transform: nil)); c.clip()
    c.vgrad(r, [(Pal.window.lighter(0.25), 0), (Pal.window, 0.45), (Pal.windowHot, 1)])
    switch style {
    case 1: // a decorated Christmas tree in the window
        let cx = r.midX, bot = r.maxY - 3
        let th = r.height * 0.86, tw = r.width * 0.5
        c.poly([CGPoint(x: cx, y: bot - th), CGPoint(x: cx + tw, y: bot), CGPoint(x: cx - tw, y: bot)], RGB(0x1F7A5C).cg())
        let cols = [RGB(0xFF4D6D), RGB(0x4CC9F0), RGB(0xFFD23F), RGB(0xB5E48C)]
        for k in 0..<7 {
            let fy = F(k) / 6, bx = cx + (hashF(seed, k) - 0.5) * tw * fy * 1.5, by = bot - th * 0.12 - fy * th * 0.7
            c.circle(bx, by, 2.6, cols[k % 4].cg()); c.glow(bx, by, 11, cols[k % 4], 0.6 * (0.5 + 0.5 * twinkle(t, F(k + seed), 2.4)))
        }
        c.sparkle(cx, bot - th, 8, Pal.gold, 1)
    case 2: // curtains
        let col = RGB(0xC0392B)
        c.poly([CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.minX + r.width * 0.32, y: r.minY), CGPoint(x: r.minX + r.width * 0.2, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)], col.cg())
        c.poly([CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX - r.width * 0.32, y: r.minY), CGPoint(x: r.maxX - r.width * 0.2, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)], col.cg())
    case 3: // sleepy cat on the sill
        let cx = r.midX, by = r.maxY
        c.ellipse(cx, by - 9, 14, 10, RGB(0x2A2342).cg()); c.circle(cx + 12, by - 17, 7.5, RGB(0x2A2342).cg())
        c.poly([CGPoint(x: cx + 6, y: by - 22), CGPoint(x: cx + 8, y: by - 30), CGPoint(x: cx + 12, y: by - 23)], RGB(0x2A2342).cg())
        c.poly([CGPoint(x: cx + 13, y: by - 23), CGPoint(x: cx + 17, y: by - 29), CGPoint(x: cx + 18, y: by - 20)], RGB(0x2A2342).cg())
    default: break
    }
    c.restoreGState()
    c.setStrokeColor(RGB(0x5A3B2E).cg()); c.setLineWidth(4)
    c.move(to: CGPoint(x: r.midX, y: r.minY)); c.addLine(to: CGPoint(x: r.midX, y: r.maxY))
    c.move(to: CGPoint(x: r.minX, y: r.midY)); c.addLine(to: CGPoint(x: r.maxX, y: r.midY)); c.strokePath()
    c.rrect(CGRect(x: r.minX - 9, y: r.maxY + 2, width: r.width + 18, height: 8), 4, RGB(0xE9D9B5).cg())
    snowMounds(c, from: CGPoint(x: r.minX - 4, y: r.maxY + 1), to: CGPoint(x: r.maxX + 4, y: r.maxY + 1), thick: 6.5, seed: seed + 3, shade: false)
}

func drawDoor(_ c: CGContext, x: F, top: F, bottom: F, t: Double, seed: Int) {
    let cols = [RGB(0xC0392B), RGB(0x1F7A5C), RGB(0x2E5BBA), RGB(0x7A3FA0)]
    let col = cols[seed % 4]
    let r = CGRect(x: x - 29, y: top, width: 58, height: bottom - top)
    c.glow(x, top + 10, 90, Pal.warm, 0.45)
    c.rrect(r.insetBy(dx: -5, dy: -5), 24, RGB(0xF3E7C9).cg())
    c.rrect(r, 24, col.cg())
    c.rrect(CGRect(x: x - 20, y: top + 8, width: 40, height: 26), 14, Pal.window.cg())
    c.rrect(CGRect(x: x - 20, y: top + 44, width: 17, height: 30), 4, col.darker(0.18).cg())
    c.rrect(CGRect(x: x + 3, y: top + 44, width: 17, height: 30), 4, col.darker(0.18).cg())
    c.circle(x + 20, top + 78, 3.5, Pal.gold.cg())
    c.setStrokeColor(RGB(0x2E9B58).cg()); c.setLineWidth(8); c.strokeEllipse(in: CGRect(x: x - 15, y: top + 40, width: 30, height: 30))
    for k in 0..<6 { let a = F(k) * 1.05; c.circle(x + cos(a) * 15, top + 55 + sin(a) * 15, 2.6, RGB(0xE63946).cg()) }
    c.poly([CGPoint(x: x - 2, y: top + 72), CGPoint(x: x - 10, y: top + 84), CGPoint(x: x - 3, y: top + 80)], RGB(0xE63946).cg())
    c.poly([CGPoint(x: x + 2, y: top + 72), CGPoint(x: x + 10, y: top + 84), CGPoint(x: x + 3, y: top + 80)], RGB(0xE63946).cg())
    c.rrect(CGRect(x: x - 36, y: bottom - 6, width: 72, height: 12), 6, Pal.snow.cg())
}

func drawAerial(_ c: CGContext, x: F, y: F, t: Double, seed: Int) {
    let top = y - 112
    let metal = RGB(0xB7BFDA), metalDark = RGB(0x7C86B0)
    c.seg(CGPoint(x: x, y: y), CGPoint(x: x, y: top), 4.5, metalDark.cg())
    c.seg(CGPoint(x: x - 1.2, y: y), CGPoint(x: x - 1.2, y: top), 1.6, metal.cg())
    for (dy, len) in [(0.0, 58.0), (15, 50), (30, 43), (45, 36), (60, 29)] as [(F, F)] {
        c.seg(CGPoint(x: x - len / 2, y: top + dy), CGPoint(x: x + len / 2, y: top + dy), 3.4, metal.cg())
        c.seg(CGPoint(x: x - len / 2 + 4, y: top + dy - 3), CGPoint(x: x + len / 2 - 4, y: top + dy - 3), 3, Pal.snow.cg())
    }
    c.rrect(CGRect(x: x - 5, y: top + 20, width: 10, height: 12), 3, metalDark.cg())
    let tw = twinkle(t, F(seed), 1.2)
    c.sparkle(x, top - 8, 7 + 10 * tw, Pal.snow, 0.3 + tw)
}

func drawSmoke(_ c: CGContext, x: F, y: F, t: Double, seed: Int, strength: F = 1) {
    for k in 0..<7 {
        let age = (t * 0.22 + F(k) / 7 + hashF(seed, 3) * 3).truncatingRemainder(dividingBy: 1)
        let px = x + age * 70 + F(sin(age * 7 + F(seed))) * 8
        let py = y - age * 150
        let r = 9 + age * 30
        c.circle(px, py, r, RGB(0xE4DFFA).cg((1 - age) * 0.5 * strength))
        c.circle(px - r * 0.2, py - r * 0.2, r * 0.6, RGB(0xFFFFFF).cg((1 - age) * 0.25 * strength))
    }
}

func drawChimney(_ c: CGContext, _ ch: Chimney, house h: House, hx: F, t: Double, entering: F = 0) {
    let x = hx + ch.dx
    let base = h.roofY(at: ch.dx) + 34
    let brick = h.stone ? Pal.stone : Pal.brick
    let r = CGRect(x: x - ch.w / 2, y: ch.topY, width: ch.w, height: base - ch.topY)
    c.rrect(r, 3, brick.cg())
    c.poly([CGPoint(x: x + ch.w * 0.15, y: ch.topY), CGPoint(x: x + ch.w / 2, y: ch.topY), CGPoint(x: x + ch.w / 2, y: base), CGPoint(x: x + ch.w * 0.15, y: base)], brick.darker(0.22).cg())
    c.setStrokeColor(brick.darker(0.3).cg(0.5)); c.setLineWidth(1.6)
    var y = ch.topY + 12
    while y < base { c.move(to: CGPoint(x: x - ch.w / 2, y: y)); c.addLine(to: CGPoint(x: x + ch.w / 2, y: y)); y += 13 }
    c.strokePath()
    c.rrect(CGRect(x: x - ch.w / 2 - 6, y: ch.topY - 12, width: ch.w + 12, height: 15), 4, Pal.stone.lighter(0.15).cg())
    snowMounds(c, from: CGPoint(x: x - ch.w / 2 - 2, y: ch.topY - 14), to: CGPoint(x: x + ch.w / 2 + 2, y: ch.topY - 14), thick: 8.5, seed: h.seed + Int(ch.dx))
    for i in 0..<ch.pots {
        let px = x + ch.potDX(i)
        let top = ch.topY - 38
        c.poly([CGPoint(x: px - 10, y: ch.topY - 11), CGPoint(x: px - 13, y: top + 6), CGPoint(x: px + 13, y: top + 6), CGPoint(x: px + 10, y: ch.topY - 11)], RGB(0xD9743C).cg())
        c.poly([CGPoint(x: px + 3, y: ch.topY - 11), CGPoint(x: px + 4, y: top + 6), CGPoint(x: px + 13, y: top + 6), CGPoint(x: px + 10, y: ch.topY - 11)], RGB(0xB85A2B).cg())
        c.rrect(CGRect(x: px - 15, y: top, width: 30, height: 9), 4, RGB(0xE88A4E).cg())
        c.ellipse(px, top + 1, 12, 3.6, RGB(0x2A1B22).cg())
    }
    c.circle(x - ch.w / 2 - 3, h.roofY(at: ch.dx) + 6, 13, Pal.snow.cg()); c.circle(x + ch.w / 2 + 3, h.roofY(at: ch.dx) + 6, 13, Pal.snow.cg())
    c.circle(x - ch.w / 2 + 8, h.roofY(at: ch.dx) - 1, 10, Pal.snowShade.cg(0.5))
    if ch.aerial { drawAerial(c, x: x - ch.w * 0.2, y: ch.topY - 12, t: t, seed: h.seed + Int(ch.dx)) }
    if ch.smoke { drawSmoke(c, x: x + ch.potDX(0), y: ch.topY - 44, t: t, seed: h.seed + Int(ch.dx)) }
}

// MARK: - Houses

func drawHouse(_ c: CGContext, _ h: House, x: F, t: Double) {
    let hw = h.w / 2
    let apexY = h.apexY
    // walls
    let wallRect = CGRect(x: x - hw, y: h.eaveY, width: h.w, height: h.baseY - h.eaveY + 40)
    c.vgrad(wallRect, [(h.wall.lighter(0.08), 0), (h.wall.darker(0.3), 1)])
    var rng = RNG(h.seed)
    if h.stone {
        for row in 0..<Int((h.baseY - h.eaveY) / 22) {
            var sx = x - hw - (row % 2 == 0 ? 0 : 14)
            while sx < x + hw {
                let w = rng.r(24, 46)
                let l = max(sx, x - hw), r = min(sx + w - 3, x + hw)
                if r > l { c.rrect(CGRect(x: l, y: h.eaveY + F(row) * 22 + 2, width: r - l, height: 18), 7, h.wall.mix(RGB(0x5F6690), rng.r(0, 0.45)).cg(0.9)) }
                sx += w
            }
        }
    } else {
        c.setStrokeColor(h.wall.darker(0.4).cg(0.22)); c.setLineWidth(1.5)
        var y = h.eaveY + 14
        while y < h.baseY { c.move(to: CGPoint(x: x - hw, y: y)); c.addLine(to: CGPoint(x: x + hw, y: y)); y += 14 }
        c.strokePath()
    }
    // windows and door
    let n = max(1, Int(h.w / 105))
    let gap = h.w / F(n)
    for k in 0..<n {
        let wx = x - hw + gap * (F(k) + 0.5)
        drawWindow(c, CGRect(x: wx - 25, y: h.eaveY + 50, width: 50, height: 74), style: (h.seed + k) % 4, t: t, seed: h.seed + k * 7)
    }
    if h.baseY - h.eaveY > 190 {
        let doorIdx = n / 2
        for k in 0..<n {
            let wx = x - hw + gap * (F(k) + 0.5)
            if k == doorIdx && n % 2 == 1 { drawDoor(c, x: wx, top: h.eaveY + 190, bottom: h.baseY + 4, t: t, seed: h.seed) }
            else { drawWindow(c, CGRect(x: wx - 25, y: h.eaveY + 196, width: 50, height: 72), style: (h.seed + k + 1) % 4, t: t, seed: h.seed + k * 11) }
        }
    }
    // roof
    let L = CGPoint(x: x - hw - 18, y: h.eaveY), R = CGPoint(x: x + hw + 18, y: h.eaveY), A = CGPoint(x: x, y: apexY)
    c.saveGState()
    c.move(to: L); c.addLine(to: A); c.addLine(to: R); c.closePath(); c.clip()
    c.vgrad(CGRect(x: L.x, y: apexY, width: R.x - L.x, height: h.roofH), [(h.roof.lighter(0.16), 0), (h.roof, 1)])
    c.setStrokeColor(h.roof.darker(0.35).cg(0.55)); c.setLineWidth(2.2)
    var ry = apexY + 16
    var row = 0
    while ry < h.eaveY {
        var rx = L.x - (row % 2 == 0 ? 0 : 10)
        while rx < R.x + 10 { c.move(to: CGPoint(x: rx, y: ry)); c.addArc(center: CGPoint(x: rx + 10, y: ry), radius: 10, startAngle: .pi, endAngle: 0, clockwise: true); rx += 20 }
        ry += 15; row += 1
    }
    c.strokePath()
    c.restoreGState()
    c.rrect(CGRect(x: L.x - 2, y: h.eaveY - 4, width: R.x - L.x + 4, height: 10), 4, RGB(0xF3E7C9).cg())
    c.seg(L, A, 7, RGB(0xF3E7C9).cg()); c.seg(A, R, 7, RGB(0xF3E7C9).cg())
    if h.attic {
        let cy = apexY + h.roofH * 0.6
        c.glow(x, cy, 70, Pal.warm, 0.55)
        c.circle(x, cy, 23, RGB(0xF3E7C9).cg()); c.circle(x, cy, 17, Pal.window.cg())
        c.seg(CGPoint(x: x - 17, y: cy), CGPoint(x: x + 17, y: cy), 3, RGB(0x5A3B2E).cg()); c.seg(CGPoint(x: x, y: cy - 17), CGPoint(x: x, y: cy + 17), 3, RGB(0x5A3B2E).cg())
        c.circle(x, cy + 24, 12, Pal.snow.cg())
    }
    // snow on the roof
    snowMounds(c, from: CGPoint(x: L.x + 4, y: L.y - 3), to: A, thick: 17, seed: h.seed + 1, lift: -6)
    snowMounds(c, from: CGPoint(x: R.x - 4, y: R.y - 3), to: A, thick: 17, seed: h.seed + 2, lift: -6)
    c.circle(x, apexY - 6, 19, Pal.snow.cg()); c.circle(x - 6, apexY - 9, 11, Pal.snowMid.cg())
    // eave: fairy lights and icicles
    icicles(c, y: h.eaveY + 6, from: L.x + 8, to: R.x - 8, seed: h.seed + 9, t: t, maxLen: 44, spacing: 14)
    if h.lights {
        let cols = [RGB(0xFF4D6D), RGB(0xFFD23F), RGB(0x4CC9F0), RGB(0x8AFF80), RGB(0xFF9F1C)]
        let sw = 5
        for s in 0..<sw {
            let x0 = L.x + (R.x - L.x) * F(s) / F(sw), x1 = L.x + (R.x - L.x) * F(s + 1) / F(sw)
            c.setStrokeColor(RGB(0x23233F).cg(0.8)); c.setLineWidth(1.6)
            c.move(to: CGPoint(x: x0, y: h.eaveY + 6)); c.addQuadCurve(to: CGPoint(x: x1, y: h.eaveY + 6), control: CGPoint(x: (x0 + x1) / 2, y: h.eaveY + 36)); c.strokePath()
            for b in 1...3 {
                let u = F(b) / 4
                let bx = lerp(x0, x1, u), by = h.eaveY + 6 + 4 * u * (1 - u) * 15 * 2 * 0.5 + (u * (1 - u)) * 60 * 0.5
                let col = cols[(s * 3 + b + h.seed) % 5]
                let tw = 0.45 + 0.55 * twinkle(t, F(s * 3 + b + h.seed), 2.0 + hashF(h.seed, s + b))
                c.circle(bx, by + 4, 4.2, col.cg()); c.glow(bx, by + 4, 26, col, 0.7 * tw)
            }
        }
    }
    for ch in h.chimneys { drawChimney(c, ch, house: h, hx: x, t: t) }
    glitter(c, x0: x - hw, x1: x + hw, yTop: { px in apexY + abs(px - x) / hw * h.roofH * 0.9 }, depth: 30, t: t, cell: 52, seed: h.seed)
}

// MARK: - Church (distant) and barn

func drawChurch(_ c: CGContext, x: F, base: F, t: Double) {
    let stone = RGB(0x9AA2CC), shade = RGB(0x7C86B4)
    c.rrect(CGRect(x: x - 40, y: base - 330, width: 80, height: 340), 3, stone.cg())
    c.rrect(CGRect(x: x + 10, y: base - 330, width: 30, height: 340), 3, shade.cg(0.7))
    c.rrect(CGRect(x: x + 30, y: base - 170, width: 190, height: 180), 3, stone.cg())
    c.poly([CGPoint(x: x + 20, y: base - 170), CGPoint(x: x + 125, y: base - 250), CGPoint(x: x + 230, y: base - 170)], RGB(0x5C62A8).cg())
    snowMounds(c, from: CGPoint(x: x + 24, y: base - 172), to: CGPoint(x: x + 125, y: base - 250), thick: 11, seed: 3, lift: -4)
    snowMounds(c, from: CGPoint(x: x + 226, y: base - 172), to: CGPoint(x: x + 125, y: base - 250), thick: 11, seed: 4, lift: -4)
    c.poly([CGPoint(x: x - 48, y: base - 330), CGPoint(x: x, y: base - 500), CGPoint(x: x + 48, y: base - 330)], RGB(0x5C62A8).cg())
    snowMounds(c, from: CGPoint(x: x - 44, y: base - 334), to: CGPoint(x: x, y: base - 496), thick: 10, seed: 5, lift: -3)
    snowMounds(c, from: CGPoint(x: x + 44, y: base - 334), to: CGPoint(x: x, y: base - 496), thick: 10, seed: 6, lift: -3)
    c.seg(CGPoint(x: x, y: base - 500), CGPoint(x: x, y: base - 540), 3, Pal.gold.cg())
    c.seg(CGPoint(x: x - 9, y: base - 524), CGPoint(x: x + 9, y: base - 524), 3, Pal.gold.cg())
    c.sparkle(x, base - 530, 14 + 6 * twinkle(t, 1, 1.3), Pal.gold, 1)
    c.circle(x, base - 280, 22, RGB(0xF3E7C9).cg()); c.circle(x, base - 280, 17, Pal.window.cg())
    c.seg(CGPoint(x: x, y: base - 280), CGPoint(x: x, y: base - 294), 2.4, RGB(0x3A2A44).cg()); c.seg(CGPoint(x: x, y: base - 280), CGPoint(x: x + 9, y: base - 276), 2.4, RGB(0x3A2A44).cg())
    for wx in [x, x + 66, x + 125, x + 184] as [F] {
        let top = wx == x ? base - 230 : base - 130
        c.glow(wx, top + 30, 60, Pal.warm, 0.5)
        c.poly([CGPoint(x: wx - 13, y: top + 60), CGPoint(x: wx - 13, y: top + 14), CGPoint(x: wx, y: top - 6), CGPoint(x: wx + 13, y: top + 14), CGPoint(x: wx + 13, y: top + 60)], Pal.window.cg())
        c.seg(CGPoint(x: wx, y: top), CGPoint(x: wx, y: top + 60), 2.4, RGB(0x5A3B2E).cg())
    }
}

func drawBarn(_ c: CGContext, x: F, base: F, t: Double) {
    let red = RGB(0xC0392B)
    c.rrect(CGRect(x: x - 120, y: base - 150, width: 240, height: 156), 3, red.cg())
    c.poly([CGPoint(x: x - 132, y: base - 148), CGPoint(x: x - 92, y: base - 215), CGPoint(x: x + 92, y: base - 215), CGPoint(x: x + 132, y: base - 148)], RGB(0x4A4F94).cg())
    snowMounds(c, from: CGPoint(x: x - 128, y: base - 150), to: CGPoint(x: x - 92, y: base - 215), thick: 14, seed: 11, lift: -4)
    snowMounds(c, from: CGPoint(x: x - 92, y: base - 218), to: CGPoint(x: x + 92, y: base - 218), thick: 14, seed: 12)
    snowMounds(c, from: CGPoint(x: x + 128, y: base - 150), to: CGPoint(x: x + 92, y: base - 215), thick: 14, seed: 13, lift: -4)
    c.glow(x, base - 175, 60, Pal.warm, 0.5)
    c.rrect(CGRect(x: x - 20, y: base - 195, width: 40, height: 32), 5, Pal.window.cg())
    c.rrect(CGRect(x: x - 45, y: base - 94, width: 90, height: 100), 3, RGB(0x8E2B20).cg())
    c.setStrokeColor(RGB(0xF3E7C9).cg()); c.setLineWidth(5)
    c.move(to: CGPoint(x: x - 45, y: base - 94)); c.addLine(to: CGPoint(x: x + 45, y: base + 6)); c.move(to: CGPoint(x: x + 45, y: base - 94)); c.addLine(to: CGPoint(x: x - 45, y: base + 6)); c.strokePath()
    c.setLineWidth(5); c.stroke(CGRect(x: x - 45, y: base - 94, width: 90, height: 100))
    icicles(c, y: base - 146, from: x - 124, to: x + 124, seed: 21, t: t, maxLen: 30, spacing: 17)
}
