import CoreGraphics
import Foundation

// MARK: - Presents

func drawPresent(_ c: CGContext, x: F, y: F, size s: F, angle: F, paper: RGB, ribbon: RGB, pattern: Int, t: Double, seed: Int) {
    c.saveGState()
    c.translateBy(x: x, y: y); c.rotate(by: angle)
    let w = s, h = s * 0.82
    c.glow(0, 0, s * 1.7, paper.lighter(0.45), 0.4)
    let body = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
    c.rrect(body, 5, paper.cg())
    c.saveGState()
    c.addPath(CGPath(roundedRect: body, cornerWidth: 5, cornerHeight: 5, transform: nil)); c.clip()
    c.poly([CGPoint(x: -w / 2, y: h / 2), CGPoint(x: w / 2, y: -h / 2), CGPoint(x: w / 2, y: h / 2)], paper.darker(0.16).cg(0.55))
    switch pattern {
    case 1:
        var py = -h / 2 + 6
        var row = 0
        while py < h / 2 { var px = -w / 2 + (row % 2 == 0 ? 5 : 11); while px < w / 2 { c.circle(px, py, 2.6, paper.lighter(0.65).cg(0.8)); px += 12 }; py += 11; row += 1 }
    case 2:
        c.setStrokeColor(paper.lighter(0.55).cg(0.7)); c.setLineWidth(s * 0.07)
        var d = -w
        while d < w * 2 { c.move(to: CGPoint(x: -w / 2 + d, y: -h / 2)); c.addLine(to: CGPoint(x: -w / 2 + d - h, y: h / 2)); d += s * 0.24 }
        c.strokePath()
    case 3:
        for k in 0..<5 { c.sparkle(-w / 2 + hashF(seed, k) * w, -h / 2 + hashF(seed, k + 9) * h, 5, RGB(0xFFFFFF), 0.9) }
    default:
        c.poly([CGPoint(x: -w / 2, y: -h / 2), CGPoint(x: w * 0.1, y: -h / 2), CGPoint(x: -w / 2, y: h * 0.1)], paper.lighter(0.4).cg(0.5))
    }
    c.restoreGState()
    c.rrect(CGRect(x: -w / 2 - 3, y: -h / 2 - 3, width: w + 6, height: h * 0.24), 4, paper.lighter(0.1).cg())
    c.rrect(CGRect(x: -w * 0.09, y: -h / 2 - 3, width: w * 0.18, height: h + 3), 1, ribbon.cg())
    c.rrect(CGRect(x: -w / 2 - 3, y: -h * 0.08, width: w + 6, height: h * 0.18), 1, ribbon.cg())
    c.rrect(CGRect(x: -w * 0.045, y: -h / 2 - 3, width: w * 0.04, height: h + 3), 1, ribbon.lighter(0.55).cg(0.9))
    for sx in [-1.0, 1.0] as [F] {
        c.saveGState(); c.translateBy(x: sx * s * 0.2, y: -h / 2 - s * 0.14); c.rotate(by: sx * 0.55)
        c.ellipse(0, 0, s * 0.22, s * 0.12, ribbon.cg())
        c.ellipse(0, 0, s * 0.13, s * 0.06, ribbon.darker(0.25).cg())
        c.restoreGState()
    }
    c.circle(0, -h / 2 - s * 0.07, s * 0.085, ribbon.lighter(0.15).cg())
    let tw = twinkle(t, F(seed), 3.0)
    c.sparkle(w * 0.46, -h * 0.5, 7 + 9 * tw, RGB(0xFFF4B8), 0.5 + tw)
    c.sparkle(-w * 0.5, h * 0.32, 5 + 6 * twinkle(t, F(seed) + 2, 3.4), Pal.snow, 0.5 + tw)
    c.restoreGState()
}

// MARK: - Reindeer

func drawReindeer(_ c: CGContext, x: F, y: F, s: F, phase: F, rudolph: Bool, t: Double) {
    let ph = F(t) * 9 + phase
    c.saveGState(); c.translateBy(x: x, y: y + F(sin(Double(ph) * 0.5)) * 4); c.scaleBy(x: s, y: s)
    let fur = RGB(0xA0602F), furDark = RGB(0x7A4421), belly = RGB(0xE0B07C)

    func leg(_ hx: F, _ hy: F, _ p: F, _ col: RGB) {
        let aU = 0.75 * F(sin(Double(p)))
        let aL = aU - 0.35 - 0.8 * max(0, F(sin(Double(p) + 1.3)))
        let k = CGPoint(x: hx + F(sin(Double(aU))) * 27, y: hy + F(cos(Double(aU))) * 27)
        let f = CGPoint(x: k.x + F(sin(Double(aL))) * 25, y: k.y + F(cos(Double(aL))) * 25)
        c.seg(CGPoint(x: hx, y: hy), k, 10, col.cg()); c.seg(k, f, 8, col.cg())
        c.circle(f.x, f.y, 5, RGB(0x2B1F2E).cg())
    }
    leg(30, 12, ph + 0.8, furDark); leg(-30, 12, ph + 2.6, furDark)
    c.ellipse(-46, -9, 9, 7, RGB(0xFFFFFF).cg())
    c.ellipse(0, 0, 47, 24, fur.cg())
    c.ellipse(0, 11, 35, 11, belly.cg())
    c.circle(33, -6, 13, RGB(0xF6E7D0).cg())
    leg(30, 14, ph, fur); leg(-30, 14, ph + 1.8, fur)
    c.seg(CGPoint(x: 30, y: -12), CGPoint(x: 58, y: -42), 24, fur.cg())
    c.seg(CGPoint(x: 14, y: -17), CGPoint(x: 46, y: -22), 5, RGB(0xD62839).cg())
    c.circle(40, -19, 5.5, Pal.gold.cg()); c.circle(40, -14, 2, RGB(0x8A5F10).cg())
    // antlers
    let sway = F(sin(Double(ph) * 0.5)) * 2
    for (dx, col) in [(-5.0, RGB(0xCBA56B)), (6.0, RGB(0xE8C98F))] as [(F, RGB)] {
        let bx: F = 62 + dx, by: F = -56
        c.curve(CGPoint(x: bx, y: by), CGPoint(x: bx - 4, y: by - 22), CGPoint(x: bx - 14, y: by - 34 + sway), CGPoint(x: bx - 8, y: by - 52 + sway), 5, col.cg())
        c.seg(CGPoint(x: bx - 8, y: by - 30 + sway), CGPoint(x: bx + 8, y: by - 40 + sway), 4, col.cg())
        c.seg(CGPoint(x: bx - 10, y: by - 42 + sway), CGPoint(x: bx - 26, y: by - 48 + sway), 4, col.cg())
        c.seg(CGPoint(x: bx - 6, y: by - 20), CGPoint(x: bx + 10, y: by - 24), 3.5, col.cg())
    }
    c.saveGState(); c.translateBy(x: 68, y: -48); c.rotate(by: -0.3)
    c.ellipse(0, 0, 21, 13, fur.cg())
    c.ellipse(-8, -12, 6, 10, furDark.cg())
    c.ellipse(18, 3, 12, 9.5, RGB(0xE8C096).cg())
    c.circle(4, -3, 4.8, RGB(0xFFFFFF).cg()); c.circle(5.2, -3, 2.4, RGB(0x1B1530).cg()); c.circle(5.8, -4, 0.9, RGB(0xFFFFFF).cg())
    if rudolph {
        c.glow(27, 4, 78, RGB(0xFF3B30), 0.95)
        c.circle(27, 4, 7.4, RGB(0xFF3B30).cg()); c.circle(25, 2, 2.4, RGB(0xFFC2BC).cg())
    } else {
        c.circle(27, 4, 4.6, RGB(0x2B1F2E).cg())
    }
    c.restoreGState()
    c.restoreGState()
}

// MARK: - Santa's sleigh and team (sleigh centre at x, y; the team flies to the right)

func drawSantaTeam(_ c: CGContext, x: F, y: F, tilt: F, s: F, t: Double) {
    c.saveGState(); c.translateBy(x: x, y: y); c.rotate(by: tilt); c.scaleBy(x: s, y: s)
    let n = 4
    var collars: [CGPoint] = []
    for i in 0..<n { collars.append(CGPoint(x: 190 + F(i) * 118 + 38, y: -14 - F(i) * 8 + F(sin(t * 4.5 + Double(i))) * 2)) }
    // reins and traces
    var prev = CGPoint(x: 52, y: -66)
    c.setStrokeColor(Pal.gold.cg(0.95)); c.setLineWidth(2.6)
    for (i, p) in collars.enumerated() {
        c.move(to: prev); c.addQuadCurve(to: CGPoint(x: p.x, y: p.y), control: CGPoint(x: (prev.x + p.x) / 2, y: (prev.y + p.y) / 2 + 12 + F(sin(t * 3 + Double(i))) * 3)); c.strokePath()
        prev = p
    }
    for i in stride(from: n - 1, through: 0, by: -1) {
        drawReindeer(c, x: 190 + F(i) * 118, y: -F(i) * 8 + 6, s: 0.9, phase: F(i) * 1.7, rudolph: i == n - 1, t: t)
    }
    for (i, p) in collars.enumerated() where i < n { c.sparkle(p.x + 4, p.y + 8, 7 + 5 * twinkle(t, F(i) * 1.9, 3.5), Pal.gold, 0.9) }
    // runners
    c.curve(CGPoint(x: -98, y: 8), CGPoint(x: -40, y: 18), CGPoint(x: 50, y: 18), CGPoint(x: 100, y: 8), 7, Pal.gold.cg())
    c.curve(CGPoint(x: 100, y: 8), CGPoint(x: 130, y: 2), CGPoint(x: 134, y: -22), CGPoint(x: 116, y: -34), 7, Pal.gold.cg())
    c.seg(CGPoint(x: -60, y: 12), CGPoint(x: -56, y: -6), 5, Pal.gold.cg()); c.seg(CGPoint(x: 52, y: 14), CGPoint(x: 48, y: -6), 5, Pal.gold.cg())
    // presents in the sack
    let sack = RGB(0x8B5E3C)
    c.ellipse(-70, -70, 40, 34, sack.cg())
    for (k, (px, py, ps)) in [(-86.0, -98.0, 26.0), (-60, -104, 24), (-98, -78, 22), (-70, -86, 28)].enumerated() {
        drawPresent(c, x: px, y: py, size: ps, angle: F(k) * 0.25 - 0.3, paper: Pal.presentPapers[(k * 3 + 1) % 8], ribbon: k % 2 == 0 ? Pal.gold : Pal.silver, pattern: k % 4, t: t, seed: k + 3)
    }
    // sleigh body
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -100, y: -80))
    p.addCurve(to: CGPoint(x: -72, y: -4), control1: CGPoint(x: -108, y: -42), control2: CGPoint(x: -98, y: -14))
    p.addLine(to: CGPoint(x: 68, y: -2))
    p.addCurve(to: CGPoint(x: 118, y: -62), control1: CGPoint(x: 104, y: -2), control2: CGPoint(x: 126, y: -30))
    p.addCurve(to: CGPoint(x: 96, y: -62), control1: CGPoint(x: 116, y: -78), control2: CGPoint(x: 98, y: -76))
    p.addCurve(to: CGPoint(x: 70, y: -34), control1: CGPoint(x: 94, y: -48), control2: CGPoint(x: 86, y: -36))
    p.addLine(to: CGPoint(x: -64, y: -34)); p.addLine(to: CGPoint(x: -82, y: -80)); p.closeSubpath()
    c.setFillColor(RGB(0xD62839).cg()); c.addPath(p); c.fillPath()
    c.saveGState(); c.addPath(p); c.clip()
    c.vgrad(CGRect(x: -110, y: -34, width: 240, height: 40), [(RGB(0xA4161A), 0), (RGB(0xD62839), 1)], alpha: 0.7)
    c.restoreGState()
    c.setStrokeColor(Pal.gold.cg()); c.setLineWidth(5); c.setLineCap(.round); c.setLineJoin(.round); c.addPath(p); c.strokePath()
    c.seg(CGPoint(x: -88, y: -22), CGPoint(x: 80, y: -20), 3.5, Pal.gold.cg())
    c.circle(104, -58, 6, Pal.gold.lighter(0.3).cg())
    // Santa
    let t4 = F(sin(t * 4))
    c.rrect(CGRect(x: -36, y: -112, width: 50, height: 64), 18, RGB(0xE63946).cg())
    c.rrect(CGRect(x: -36, y: -78, width: 50, height: 9), 3, RGB(0x23233F).cg()); c.rrect(CGRect(x: -15, y: -80, width: 11, height: 13), 2, Pal.gold.cg())
    c.rrect(CGRect(x: -38, y: -52, width: 54, height: 10), 5, RGB(0xFFFFFF).cg())
    c.seg(CGPoint(x: 4, y: -100), CGPoint(x: 50, y: -64), 11, RGB(0xE63946).cg()); c.circle(52, -62, 7, RGB(0xFFFFFF).cg())
    let hand = CGPoint(x: 8 + F(cos(-0.95 + 0.5 * Double(t4))) * 36, y: -102 + F(sin(-0.95 + 0.5 * Double(t4))) * 36)
    c.seg(CGPoint(x: 6, y: -102), hand, 11, RGB(0xE63946).cg()); c.circle(hand.x, hand.y, 7.5, RGB(0xFFFFFF).cg())
    c.circle(-9, -128, 17, RGB(0xFFD2B0).cg())
    c.circle(-2, -126, 4, RGB(0xFF9AA2).cg(0.9)); c.circle(-3, -134, 2.1, RGB(0x1B1530).cg()); c.circle(7, -134, 2.1, RGB(0x1B1530).cg())
    c.circle(-3, -116, 16, RGB(0xFFFFFF).cg()); c.ellipse(-3, -108, 14, 12, RGB(0xFFFFFF).cg()); c.ellipse(-3, -123, 12, 5, RGB(0xF4F4FF).cg())
    c.circle(-3, -126, 4.2, RGB(0xFFB3A7).cg())
    c.poly([CGPoint(x: -29, y: -138), CGPoint(x: 14, y: -140), CGPoint(x: -14, y: -176), CGPoint(x: -48, y: -150 + t4 * 3)], RGB(0xE63946).cg())
    c.ellipse(-8, -139, 24, 7.5, RGB(0xFFFFFF).cg())
    c.circle(-48, -150 + t4 * 3, 7.5, RGB(0xFFFFFF).cg())
    c.restoreGState()
}

// MARK: - Magic dust

func drawMagicDust(_ c: CGContext, t: Double, origin: (Double) -> CGPoint?, cam: (Double) -> F) {
    let life = 1.7
    for k in 0..<46 {
        let age = life * Double(k) / 46 + (t * 0.31).truncatingRemainder(dividingBy: life / 46)
        let te = t - age
        guard let o = origin(te) else { continue }
        let u = F(age / life)
        let jx = hashF(k, Int(te * 10)) - 0.5, jy = hashF(k + 99, Int(te * 10)) - 0.5
        let wx = o.x + cam(te) + jx * 26
        let sx = wx - cam(t)
        let sy = o.y + jy * 18 + u * u * 120
        let col = [RGB(0xFFE066), RGB(0xFFFFFF), RGB(0xFF9AD5), RGB(0x9AE6FF)][k % 4]
        c.sparkle(sx, sy, (4 + 8 * hashF(k, 5)) * (1 - u * 0.6), col, (1 - u) * 0.95)
    }
}
