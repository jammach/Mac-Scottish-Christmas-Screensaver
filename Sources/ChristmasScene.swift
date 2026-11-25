import CoreGraphics
import Foundation

// MARK: - World description

enum Thing {
    case house(House)
    case tree(Tree)
    case sheep(F)
    case snowman
    case fence(F)
    case wall(F)
    case hedge(F)
    case gate
    case lamp
    case pond(F)
    case barn
}

struct Item {
    var wx: F          // world x of the item's reference point
    var ext: F         // half extent, for culling
    var thing: Thing
    var seed: Int
    var y: F? = nil     // fixed ground line (foreground band), otherwise follows the terrain
    var layer = 0       // 1 = foreground band, drawn last and a little bigger
}

enum MidKind { case house(House), tree(Tree), church }
struct MidItem { var mx: F; var kind: MidKind; var s: F }

struct Drop {
    var tDrop: Double, tLand: Double
    var wxPot: F, rimY: F
    var size: F, paper: RGB, ribbon: RGB, pattern: Int, seed: Int
}

// MARK: - Geography: where each biome sits along the flight (world x, foreground units)

enum Geo {
    static let b1: F = 3660, b2: F = 6360, b3: F = 9360, b4: F = 12060   // town | country | forest | village | town
    static let C: F = 16800          // length of one whole journey in world px (112 s at 150 px/s)
    static let origin: F = -560      // where each journey begins, relative to its start
    /// Position inside the current journey.
    static func local(_ x: F) -> F { x - ((x - origin) / C).rounded(.down) * C }
    static func weights(_ wxIn: F) -> (town: F, country: F, forest: F, village: F) {
        let wx = local(wxIn)
        let e: F = 230
        let s1 = smooth(b1 - e, b1 + e, wx), s2 = smooth(b2 - e, b2 + e, wx), s3 = smooth(b3 - e, b3 + e, wx), s4 = smooth(b4 - e, b4 + e, wx)
        return ((1 - s1) + s4, s1 * (1 - s2), s2 * (1 - s3), s3 * (1 - s4))
    }
    static func groundY(_ wx: F) -> F {
        let w = weights(wx)
        let town: F = 1054 + 5 * F(sin(Double(wx) / 40))
        let country: F = 872 + 64 * F(sin(Double(wx) / 260)) + 30 * F(sin(Double(wx) / 97 + 1))
        let village: F = 912 + 34 * F(sin(Double(wx) / 210 + 2)) + 16 * F(sin(Double(wx) / 83))
        return w.town * town + w.country * country + w.village * village + w.forest * 1200
    }
}

// MARK: - World builder

struct WorldBuilder {
    var rng: RNG
    init(seed: Int) { rng = RNG(seed) }
    var items: [Item] = []
    var mid: [MidItem] = []

    static let walls: [RGB] = [RGB(0xC4553C), RGB(0xE9CF9A), RGB(0x8FB69B), RGB(0xA08FD0), RGB(0xF0A58A), RGB(0x7FA7D9), RGB(0xE8B84F)]
    static let roofs: [RGB] = [RGB(0x5C62A8), RGB(0xB8503A), RGB(0x3F7F8C), RGB(0x7A4E9B), RGB(0x6B6FC4)]

    mutating func chimneys(_ w: F, _ roofH: F, apex: F, count: Int, wide: Bool) -> [Chimney] {
        var out: [Chimney] = []
        var used: [F] = []
        var aerialDone = false
        for k in 0..<count {
            var dx: F = 0
            for _ in 0..<8 {
                dx = wide ? (k == 0 ? -1 : 1) * w * rng.r(0.3, 0.38) : rng.r(-w * 0.3, w * 0.3)
                if used.allSatisfy({ abs($0 - dx) > 90 }) { break }
            }
            used.append(dx)
            let cw: F = wide ? rng.r(50, 62) : rng.r(38, 48)
            let roofAt = apex + min(1, abs(dx) / (w / 2 + 16)) * roofH
            let aerial = !aerialDone && rng.chance(wide ? 0.4 : 0.5)
            if aerial { aerialDone = true }
            out.append(Chimney(dx: dx, w: cw, topY: roofAt - rng.r(88, 125), pots: wide ? 2 + rng.i(2) : 1 + rng.i(3), smoke: rng.chance(0.65), aerial: aerial))
        }
        return out
    }

    @discardableResult
    mutating func terrace(_ x0: F, _ x1: F, lights: F, cottages: F) -> F {
        var x = x0
        var lastEnd = x0
        while x < x1 {
            let cottage = rng.chance(cottages)
            let w: F = cottage ? rng.r(350, 420) : rng.r(250, 335)
            let eave = rng.r(715, 790), roofH = cottage ? rng.r(120, 150) : rng.r(95, 135)
            let wall = cottage ? RGB(0x9A9FC8) : rng.pick(Self.walls)
            let ch = chimneys(w, roofH, apex: eave - roofH, count: cottage ? 2 : (rng.chance(0.35) ? 2 : 1), wide: cottage)
            let h = House(w: w, eaveY: eave, roofH: roofH, baseY: 1062, wall: wall, roof: rng.pick(Self.roofs), stone: cottage, chimneys: ch, lights: rng.chance(lights), attic: !cottage && rng.chance(0.55), seed: rng.i(100000))
            items.append(Item(wx: x + w / 2, ext: w / 2 + 60, thing: .house(h), seed: h.seed))
            lastEnd = x + w
            x += w + rng.r(-8, 22)
        }
        return lastEnd
    }

    mutating func village(_ x0: F, _ x1: F) {
        var x = x0
        while x < x1 {
            let w = rng.r(340, 420)
            let wx = x + w / 2
            let g = Geo.groundY(wx)
            let eave = g - rng.r(250, 290), roofH = rng.r(120, 150)
            let ch = chimneys(w, roofH, apex: eave - roofH, count: 2, wide: true)
            let h = House(w: w, eaveY: eave, roofH: roofH, baseY: g + 26, wall: rng.pick([RGB(0x9A9FC8), RGB(0xA8A4C0), RGB(0x8E98B8)]), roof: rng.pick([RGB(0x4A5090), RGB(0x58609C)]), stone: true, chimneys: ch, lights: rng.chance(0.7), attic: false, seed: rng.i(100000))
            items.append(Item(wx: wx, ext: w / 2 + 60, thing: .house(h), seed: h.seed))
            var gx = x + w + 20
            let gapEnd = x + w + rng.r(80, 190)
            while gx < gapEnd - 60 {
                let pick = rng.i(5)
                let gy = Geo.groundY(gx)
                if pick == 0 { items.append(Item(wx: gx + 40, ext: 80, thing: .wall(100), seed: rng.i(9999))) }
                else if pick == 1 { items.append(Item(wx: gx + 40, ext: 80, thing: .fence(120), seed: rng.i(9999))) }
                else if pick == 2 { items.append(Item(wx: gx + 30, ext: 120, thing: .tree(Tree(kind: .spruce, topY: gy - 300, h: 290, w: 190, seed: rng.i(9999), decorated: rng.chance(0.4), base: gy + 4)), seed: 1)) }
                else if pick == 3 { items.append(Item(wx: gx + 20, ext: 60, thing: .lamp, seed: 1)) }
                else { items.append(Item(wx: gx + 30, ext: 100, thing: .sheep(1), seed: rng.i(99))) }
                gx += rng.r(110, 160)
            }
            x = gapEnd
        }
    }

    mutating func country(_ x0: F, _ x1: F) {
        var x = x0
        var n = 0
        while x < x1 {
            n += 1
            let g = Geo.groundY(x)
            if n % 3 != 0, g < 1000 {
                items.append(Item(wx: x + rng.r(20, 90), ext: 120, thing: .tree(Tree(kind: rng.pick([.spruce, .spruce, .oak, .pine, .rowan]), topY: g - rng.r(200, 300), h: rng.r(190, 260), w: rng.r(150, 210), seed: rng.i(9999), decorated: rng.chance(0.2), base: g + 4)), seed: 1))
            }
            switch n % 9 {
            case 0:
                items.append(Item(wx: x, ext: 200, thing: .tree(Tree(kind: .oak, topY: g - 380, h: 330, w: 320, seed: rng.i(9999), base: g + 6)), seed: 1)); x += rng.r(230, 320)
            case 1:
                items.append(Item(wx: x + 60, ext: 110, thing: .hedge(220), seed: rng.i(9999))); x += 250
            case 2:
                let nS = 2 + rng.i(2)
                for k in 0..<nS { items.append(Item(wx: x + F(k) * 96, ext: 80, thing: .sheep(rng.r(0.9, 1.15)), seed: rng.i(99))) }
                x += F(nS) * 96 + 120
            case 3:
                let w = rng.r(360, 420), eave = Geo.groundY(x + w / 2) - 260, rh = rng.r(120, 140)
                let h = House(w: w, eaveY: eave, roofH: rh, baseY: Geo.groundY(x + w / 2) + 24, wall: RGB(0xE9CF9A), roof: RGB(0x5C62A8), stone: true, chimneys: chimneys(w, rh, apex: eave - rh, count: 2, wide: true), lights: true, attic: false, seed: rng.i(9999))
                items.append(Item(wx: x + w / 2, ext: w / 2 + 60, thing: .house(h), seed: 1)); x += w + 40
            case 4:
                items.append(Item(wx: x + 100, ext: 180, thing: .barn, seed: 1)); x += 330
            case 5:
                items.append(Item(wx: x + 80, ext: 140, thing: .fence(260), seed: rng.i(9999))); x += 300
            case 6:
                items.append(Item(wx: x + 80, ext: 140, thing: .wall(300), seed: rng.i(9999)))
                items.append(Item(wx: x + 420, ext: 90, thing: .gate, seed: rng.i(9999))); x += 600
            case 7:
                items.append(Item(wx: x + 30, ext: 150, thing: .pond(260), seed: 1)); x += 250
            default:
                if n % 18 == 8 { items.append(Item(wx: x + 20, ext: 100, thing: .snowman, seed: 1)); x += 180 }
                else { items.append(Item(wx: x, ext: 160, thing: .tree(Tree(kind: rng.pick([.pine, .spruce, .oak]), topY: g - 330, h: 300, w: 250, seed: rng.i(9999), base: g + 6)), seed: 1)); x += rng.r(180, 260) }
            }
        }
    }

    mutating func forest(_ x0: F, _ x1: F) {
        var x = x0
        let kinds: [(TreeKind, F)] = [(.spruce, 0.27), (.pine, 0.15), (.oak, 0.16), (.birch, 0.14), (.beech, 0.10), (.holly, 0.06), (.rowan, 0.12)]
        while x < x1 {
            var u = rng.u(), kind = TreeKind.spruce
            for (k, p) in kinds { if u < p { kind = k; break }; u -= p }
            let (h, w): (F, F)
            switch kind {
            case .spruce: (h, w) = (rng.r(340, 420), rng.r(230, 290))
            case .pine: (h, w) = (rng.r(320, 380), rng.r(300, 340))
            case .oak: (h, w) = (rng.r(320, 380), rng.r(300, 350))
            case .birch: (h, w) = (rng.r(340, 400), rng.r(200, 240))
            case .beech: (h, w) = (rng.r(280, 330), rng.r(260, 300))
            case .holly: (h, w) = (rng.r(210, 250), rng.r(190, 220))
            case .rowan: (h, w) = (rng.r(280, 330), rng.r(240, 280))
            }
            let top = rng.r(560, 760) + (kind == .holly ? 120 : 0)
            items.append(Item(wx: x, ext: w * 0.6, thing: .tree(Tree(kind: kind, topY: top, h: h, w: w, seed: rng.i(99999), decorated: kind == .spruce && rng.chance(0.2))), seed: 1))
            x += rng.r(120, 185)
        }
    }

    /// A low band of walls, hedges and fences along the very front, so open snow never looks empty.
    mutating func foreground(_ x0: F, _ x1: F) {
        var x = x0
        while x < x1 {
            let seed = rng.i(9999)
            switch rng.i(5) {
            case 0, 1: items.append(Item(wx: x + 160, ext: 220, thing: .wall(300), seed: seed, y: 1068, layer: 1)); x += rng.r(360, 460)
            case 2: items.append(Item(wx: x + 130, ext: 200, thing: .fence(260), seed: seed, y: 1062, layer: 1)); x += rng.r(330, 420)
            case 3: items.append(Item(wx: x + 120, ext: 200, thing: .hedge(240), seed: seed, y: 1074, layer: 1)); x += rng.r(320, 420)
            default: x += rng.r(150, 260)
            }
        }
    }

    mutating func midRow(journey k: Int) {
        let off = F(k) * Geo.C * 0.55
        let first = mid.count
        var mx: F = k == 0 ? -300 : 124
        while mx < 124 + Geo.C * 0.55 {
            let wxEq = (mx - 960) / 0.55 + 960
            let w = Geo.weights(wxEq)
            let dominant = [("town", w.town), ("country", w.country), ("forest", w.forest), ("village", w.village)].max { $0.1 < $1.1 }!.0
            let s: F = 0.55
            switch dominant {
            case "town", "village":
                if rng.chance(0.6) {
                    let hw = rng.r(190, 250), eave: F = -rng.r(120, 150), rh = rng.r(80, 105)
                    let h = House(w: hw, eaveY: eave, roofH: rh, baseY: 0, wall: dominant == "town" ? rng.pick(Self.walls) : RGB(0x9A9FC8), roof: rng.pick(Self.roofs), stone: dominant == "village", chimneys: [Chimney(dx: rng.r(-hw * 0.25, hw * 0.25), w: 36, topY: eave - rh - 40, pots: 1 + rng.i(2), smoke: true, aerial: rng.chance(0.4))], lights: false, attic: false, seed: rng.i(9999))
                    mid.append(MidItem(mx: mx, kind: .house(h), s: s)); mx += hw * s + rng.r(10, 70)
                } else {
                    mid.append(MidItem(mx: mx, kind: .tree(Tree(kind: rng.pick([.spruce, .spruce, .pine]), topY: -rng.r(250, 330), h: 230, w: 170, seed: rng.i(999), decorated: rng.chance(0.3), base: 0)), s: s)); mx += rng.r(70, 130)
                }
            case "country":
                mid.append(MidItem(mx: mx, kind: .tree(Tree(kind: rng.pick([.oak, .pine, .spruce]), topY: -rng.r(260, 340), h: 250, w: 230, seed: rng.i(999), base: 0)), s: s)); mx += rng.r(110, 210)
            default:
                mid.append(MidItem(mx: mx, kind: .tree(Tree(kind: rng.pick([.spruce, .spruce, .pine, .birch, .oak]), topY: -rng.r(280, 380), h: 300, w: 220, seed: rng.i(999), base: 0)), s: s)); mx += rng.r(70, 120)
            }
        }
        mid.append(MidItem(mx: (4900 - 960) * 0.55 + 960, kind: .church, s: 0.5))
        mid.append(MidItem(mx: (10700 - 960) * 0.55 + 960, kind: .church, s: 0.5))
        for i in first..<mid.count { mid[i].mx += off }
        mid.sort { $0.mx < $1.mx }
    }
}

// MARK: - Scene

final class ChristmasScene {
    let camSpeed: F = 150
    let items: [Item]
    let mid: [MidItem]
    let drops: [Drop]
    var duration: Double = 90

    // Santa's appearances in each journey: (enters, hovers from, hovers until, gone), in seconds from that journey's start.
    // He hovers over the rooftops while the world slides beneath him.
    static let baseVisits: [(F, F, F, F)] = [(1.0, 5.0, 17.0, 21.0), (52.0, 57.0, 68.0, 72.0), (73.0, 77.0, 86.0, 90.0)]
    static let holdX: F = 620
    static let santaScale: F = 0.85
    static let fall = 1.25
    let visits: [(F, F, F, F)]

    init(journeys: Int = 3) {
        var allItems: [Item] = [], allMid: [MidItem] = []
        var vs: [(F, F, F, F)] = []
        let tc = Geo.C / 150
        for k in 0..<journeys {
            let o = F(k) * Geo.C
            var b = WorldBuilder(seed: 20261125 + k * 7919)
            b.terrace(o - 560, o + Geo.b1 + 200, lights: 0.4, cottages: 0.12)
            b.country(o + Geo.b1 + 260, o + Geo.b2 + 100)
            b.forest(o + Geo.b2 - 60, o + Geo.b3 + 120)
            b.village(o + Geo.b3 + 240, o + Geo.b4 + 150)
            let end = b.terrace(o + Geo.b4 + 230, o + 15900, lights: 0.8, cottages: 0.18)
            // a snowy lane with a lamp between the last house of this journey and the first of the next
            let next = o + Geo.C - 560
            if next - end > 100 { b.items.append(Item(wx: (end + next) / 2, ext: 60, thing: .lamp, seed: 1)) }
            b.foreground(o + Geo.b1 + 260, o + Geo.b2 - 100)
            b.foreground(o + Geo.b3 + 260, o + Geo.b4 - 100)
            b.midRow(journey: k)
            allItems += b.items; allMid += b.mid
            for v in ChristmasScene.baseVisits { vs.append((v.0 + F(k) * tc, v.1 + F(k) * tc, v.2 + F(k) * tc, v.3 + F(k) * tc)) }
        }
        allItems.sort { ($0.layer, $0.wx) < ($1.layer, $1.wx) }
        allMid.sort { $0.mx < $1.mx }
        items = allItems
        mid = allMid
        visits = vs
        // schedule presents for every pot Santa can reach while he hovers
        var rng = RNG(99)
        var ds: [Drop] = []
        let x0 = ChristmasScene.holdX - 60
        for it in allItems {
            guard case .house(let h) = it.thing else { continue }
            for ch in h.chimneys {
                for i in 0..<min(ch.pots, 2) {
                    let wxPot = it.wx + ch.dx + ch.potDX(i)
                    let tL = Double(wxPot - x0) / Double(150)
                    let tD = tL - ChristmasScene.fall
                    for v in vs where tD >= Double(v.1) + 0.3 && tD <= Double(v.2) - 0.2 {
                        ds.append(Drop(tDrop: tD, tLand: tL, wxPot: wxPot, rimY: ch.rimY, size: rng.r(52, 74), paper: rng.pick(Pal.presentPapers), ribbon: rng.chance(0.5) ? Pal.gold : Pal.silver, pattern: rng.i(4), seed: rng.i(999)))
                    }
                }
            }
        }
        drops = ds
    }

    func cam(_ t: Double) -> F { camSpeed * F(t) }

    func santaY(_ t: Double) -> F { 238 + 14 * F(sin(t * 1.3)) }

    /// Sleigh centre and bank angle, if Santa is on screen.
    func santaPose(_ t: Double, width: F) -> (x: F, y: F, tilt: F)? {
        let tf = F(t)
        for v in visits where tf >= v.0 && tf <= v.3 {
            let S = ChristmasScene.holdX
            if tf < v.1 {
                let u = (tf - v.0) / (v.1 - v.0), e = 1 - pow(1 - u, 3)
                return (lerp(-950, S, e), lerp(80, santaY(t), e), -0.12 * (1 - e))
            } else if tf <= v.2 {
                return (S, santaY(t), 0.02 * F(sin(t * 1.3)))
            } else {
                let u = (tf - v.2) / (v.3 - v.2), e = u * u
                return (lerp(S, width + 1200, e), lerp(santaY(t), 40, e), -0.26 * e)
            }
        }
        return nil
    }

    // MARK: Drawing

    func draw(_ c: CGContext, t: Double, width W: F, fadeInOut: Bool = true) {
        let H: F = 1080
        let cm = cam(t)
        drawSky(c, t: t, cam: cm, W: W)
        drawFarHills(c, t: t, cam: cm, W: W)
        drawSnowfall(c, t: t, cam: cm, W: W, layer: 0)
        drawMidRow(c, t: t, cam: cm, W: W)
        drawMidHillsFront(c, cam: cm, W: W)
        // Santa, magic dust and falling presents sit between the distance and the rooftops
        drawSantaLayer(c, t: t, cam: cm, W: W)
        drawSnowfall(c, t: t, cam: cm, W: W, layer: 1)
        drawFront(c, t: t, cam: cm, W: W)
        drawPotBursts(c, t: t, cam: cm)
        drawSnowfall(c, t: t, cam: cm, W: W, layer: 2)
        // vignette
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [RGB(0x05061F).cg(0), RGB(0x05061F).cg(0.38)] as CFArray, locations: [0.55, 1])!
        c.drawRadialGradient(g, startCenter: CGPoint(x: W / 2, y: H / 2), startRadius: 0, endCenter: CGPoint(x: W / 2, y: H / 2), endRadius: hypot(W, H) * 0.62, options: [.drawsAfterEndLocation])
        if fadeInOut {
            let fade = max(1 - t / 1.4, 0, (t - (duration - 1.6)) / 1.6)
            if fade > 0 { c.setFillColor(RGB(0x06071E).cg(clamp(F(fade)))); c.fill(CGRect(x: 0, y: 0, width: W, height: H)) }
        }
    }

    func drawSky(_ c: CGContext, t: Double, cam: F, W: F) {
        c.vgrad(CGRect(x: 0, y: 0, width: W, height: 1080), [(RGB(0x090D38), 0), (RGB(0x1B2874), 0.3), (RGB(0x4A3B98), 0.58), (RGB(0xB05AA2), 0.8), (RGB(0xF2A3A0), 1.0)])
        // stars
        for i in 0..<170 {
            let x = (hashF(i, 1) * (W + 200) - cam * 0.012).truncatingRemainder(dividingBy: W + 200)
            let sx = x < 0 ? x + W + 200 : x
            let y = hashF(i, 2) * 620
            let tw = twinkle(t, hashF(i, 3) * 6.28, 0.8 + hashF(i, 4) * 1.8)
            let base = 0.35 + 0.65 * hashF(i, 5)
            c.circle(sx - 100, y, 0.9 + 1.6 * hashF(i, 6), RGB(0xFFFFFF).cg(base * (0.6 + 0.4 * (1 - tw))))
            if i % 9 == 0 { c.sparkle(sx - 100, y, 6 + 10 * tw, i % 2 == 0 ? RGB(0xFFF1B8) : RGB(0xCFE6FF), 0.4 + tw * 0.6) }
        }
        // moon
        let mx = 1480 - cam * 0.004, my: F = 210
        c.glow(mx, my, 420, RGB(0xFFF1C8), 0.38)
        c.circle(mx, my, 78, RGB(0xFFF7DC).cg()); c.circle(mx - 22, my + 14, 17, RGB(0xF0E1B8).cg()); c.circle(mx + 26, my - 22, 11, RGB(0xF0E1B8).cg()); c.circle(mx + 14, my + 34, 8, RGB(0xF0E1B8).cg())
        c.circle(mx + 12, my - 8, 66, RGB(0xFFFFFF).cg(0.12))
        // soft clouds
        for i in 0..<7 {
            let cx = (hashF(i, 40) * (W + 700) - cam * 0.03 - F(t) * (6 + 3 * hashF(i, 41))).truncatingRemainder(dividingBy: W + 700)
            let sx = (cx < 0 ? cx + W + 700 : cx) - 350
            let y = 120 + hashF(i, 42) * 330
            let s = 0.8 + hashF(i, 43) * 0.8
            for (dx, dy, rx, ry) in [(-70.0, 8.0, 70.0, 24.0), (0, -6, 90, 32), (70, 6, 74, 26), (20, 16, 100, 22)] as [(F, F, F, F)] {
                c.ellipse(sx + dx * s, y + dy * s, rx * s, ry * s, RGB(0x7B62BC).cg(0.5))
                c.ellipse(sx + dx * s, y + (dy - 8) * s, rx * s * 0.85, ry * s * 0.7, RGB(0xC98BD0).cg(0.28))
            }
        }
    }

    func hillLine(_ c: CGContext, par: F, cam: F, W: F, base: F, amp: F, mountains: F, fill: [(RGB, F)], top: RGB, seed: F) -> (F) -> F {
        func h(_ sx: F) -> F {
            let wx = (sx + cam * par) + seed
            let smoothH = 0.55 * F(sin(Double(wx) / 330)) + 0.3 * F(sin(Double(wx) / 140 + 1.2)) + 0.15 * F(sin(Double(wx) / 61))
            let ridge = 1 - abs(F(sin(Double(wx) / 190)) + 0.6 * F(sin(Double(wx) / 83 + 1.3)) + 0.3 * F(sin(Double(wx) / 37))) / 1.9
            return base - amp * (smoothH * (1 - mountains) + (ridge * 2.0 - 0.6) * mountains)
        }
        var pts: [CGPoint] = []
        var x: F = -10
        while x <= W + 10 { pts.append(CGPoint(x: x, y: h(x))); x += 8 }
        c.saveGState()
        c.move(to: CGPoint(x: -10, y: 1100)); for p in pts { c.addLine(to: p) }; c.addLine(to: CGPoint(x: W + 10, y: 1100)); c.closePath(); c.clip()
        c.vgrad(CGRect(x: 0, y: base - amp * 2.4, width: W, height: amp * 2.4 + 400), fill)
        c.restoreGState()
        c.setStrokeColor(top.cg(0.9)); c.setLineWidth(5); c.setLineJoin(.round)
        c.move(to: pts[0]); for p in pts.dropFirst() { c.addLine(to: p) }; c.strokePath()
        return h
    }

    func drawFarHills(_ c: CGContext, t: Double, cam: F, W: F) {
        let lc = Geo.local(cam)
        let mtn = smooth(7600, 9000, lc) * (1 - smooth(12500, 13400, lc))
        let h = hillLine(c, par: 0.08, cam: cam, W: W, base: 660, amp: 120, mountains: mtn, fill: [(RGB(0x8E86D4), 0), (RGB(0x6D63B9), 1)], top: RGB(0xE8E4FF), seed: 0)
        // Highland castle glimmering on a far crag
        if mtn > 0.3 {
            let cx = 1500 - (lc - 8000) * 0.08
            if cx > -200 && cx < W + 200 {
                let by = h(cx) + 6
                c.rrect(CGRect(x: cx - 46, y: by - 62, width: 92, height: 66), 2, RGB(0x4C4A9C).cg(mtn))
                for dx in [-44.0, 0.0, 44.0] as [F] { c.rrect(CGRect(x: cx + dx - 11, y: by - 98, width: 22, height: 40), 2, RGB(0x4C4A9C).cg(mtn)); c.poly([CGPoint(x: cx + dx - 14, y: by - 98), CGPoint(x: cx + dx, y: by - 120), CGPoint(x: cx + dx + 14, y: by - 98)], RGB(0x3A3880).cg(mtn)) }
                for dx in [-30.0, -8.0, 14.0, 34.0] as [F] { c.rrect(CGRect(x: cx + dx - 3, y: by - 40, width: 6, height: 10), 1, Pal.window.cg(mtn)) }
            }
        }
    }

    func drawMidHillsFront(_ c: CGContext, cam: F, W: F) {
        // low rolling hills with a far line of little trees and the odd lit cottage
        let par: F = 0.22
        let h = hillLine(c, par: par, cam: cam, W: W, base: 770, amp: 52, mountains: 0, fill: [(RGB(0xA9A3EA), 0), (RGB(0x7C74CE), 1)], top: RGB(0xF3F1FF), seed: 400)
        var x = (-(cam * par).truncatingRemainder(dividingBy: 34)) - 34
        while x < W + 40 {
            let id = Int(((x + cam * par) / 34).rounded())
            let w = Geo.weights(cam + x)
            let r = hashF(id, 77)
            if r < 0.5 + 0.3 * w.forest {
                drawFarTree(c, x: x + hashF(id, 78) * 18, base: h(x) + 8, h: 26 + 26 * hashF(id, 79), col: RGB(0x2D3C8C).cg(0.85), snow: RGB(0xE9E8FF).cg(0.9))
            } else if r > 0.93 && (w.village > 0.3 || w.town > 0.5) {
                let by = h(x) + 6
                c.rrect(CGRect(x: x - 8, y: by - 14, width: 16, height: 14), 1, RGB(0x4A4A9A).cg())
                c.poly([CGPoint(x: x - 11, y: by - 13), CGPoint(x: x, y: by - 24), CGPoint(x: x + 11, y: by - 13)], RGB(0xE8E6FF).cg())
                c.rrect(CGRect(x: x - 3, y: by - 10, width: 6, height: 7), 1, Pal.window.cg())
                c.glow(x, by - 7, 22, Pal.warm, 0.5)
            }
            x += 34
        }
    }

    func drawMidRow(_ c: CGContext, t: Double, cam: F, W: F) {
        let par: F = 0.55
        c.beginTransparencyLayer(auxiliaryInfo: nil)
        let groundMid: F = 800
        // a snowy ridge behind the row so its feet are hidden
        var pts: [CGPoint] = []
        var x: F = -10
        while x <= W + 10 { let wx = x + cam * par; pts.append(CGPoint(x: x, y: groundMid + 6 * F(sin(Double(wx) / 120)))); x += 10 }
        c.move(to: CGPoint(x: -10, y: 1100)); for p in pts { c.addLine(to: p) }; c.addLine(to: CGPoint(x: W + 10, y: 1100)); c.closePath()
        c.setFillColor(Pal.snowMid.cg()); c.fillPath()
        for m in mid {
            let sx = m.mx - cam * par
            if sx < -400 || sx > W + 400 { continue }
            let gy = groundMid + 6 * F(sin(Double(m.mx) / 120))
            c.saveGState(); c.translateBy(x: sx, y: gy); c.scaleBy(x: m.s, y: m.s)
            switch m.kind {
            case .house(let h): drawHouse(c, h, x: 0, t: t)
            case .tree(let tr): drawTree(c, tr, x: 0, t: t)
            case .church: drawChurch(c, x: 0, base: 0, t: t)
            }
            c.restoreGState()
        }
        // push the whole row towards the haze, but only where it was drawn
        c.setBlendMode(.sourceAtop); c.setFillColor(Pal.haze.cg(0.42)); c.fill(CGRect(x: 0, y: 0, width: W, height: 1100)); c.setBlendMode(.normal)
        c.endTransparencyLayer()
    }

    func drawSantaLayer(_ c: CGContext, t: Double, cam: F, W: F) {
        guard let pose = santaPose(t, width: W) else { return }
        let S = ChristmasScene.santaScale
        // dust trail follows the sleigh in the world (so it streams behind as the camera moves on)
        drawMagicDust(c, t: t, origin: { te in
            guard let p = self.santaPose(te, width: W) else { return nil }
            return CGPoint(x: p.x - 70 * S, y: p.y - 10)
        }, cam: { self.cam($0) })
        c.glow(pose.x + 250, pose.y, 640, RGB(0xFFD9A0), 0.16)
        drawSantaTeam(c, x: pose.x, y: pose.y, tilt: pose.tilt, s: S, t: t)
        // presents in flight
        for d in drops where t >= d.tDrop && t <= d.tLand + 0.3 {
            let sx0 = ChristmasScene.holdX - 60
            let y0 = santaY(d.tDrop) - 60 * S
            var x: F, y: F, sc: F = 1, a: F
            if t < d.tLand {
                let u = F((t - d.tDrop) / ChristmasScene.fall)
                x = sx0 + 14 * F(sin(Double(u) * 5)) * (1 - u)
                y = lerp(y0, d.rimY - 20, pow(u, 1.55))
                sc = 1 - 0.7 * smooth(0.8, 1.0, u)
                a = F(t - d.tDrop) * 2.6 + F(d.seed)
            } else {
                let u = F((t - d.tLand) / 0.3)
                x = d.wxPot - cam; y = d.rimY - 20 + 36 * u
                sc = 0.3 * (1 - u); a = 0.4
            }
            if sc > 0.02 { drawPresent(c, x: x, y: y, size: d.size * sc, angle: a, paper: d.paper, ribbon: d.ribbon, pattern: d.pattern, t: t, seed: d.seed) }
        }
    }

    func drawPotBursts(_ c: CGContext, t: Double, cam: F) {
        for d in drops where t >= d.tLand && t <= d.tLand + 0.9 {
            let u = F((t - d.tLand) / 0.9)
            let x = d.wxPot - cam, y = d.rimY + 2
            c.glow(x, y, 90 * (1 - u * 0.4), RGB(0xFFD25E), 0.9 * (1 - u))
            for k in 0..<9 {
                let a = F(k) / 9 * 6.283 + F(d.seed)
                let r = 10 + u * 60 * (0.6 + hashF(d.seed, k))
                c.sparkle(x + cos(a) * r, y - u * 30 + sin(a) * r * 0.7, (5 + 8 * hashF(d.seed, k + 20)) * (1 - u), k % 3 == 0 ? Pal.snow : RGB(0xFFD25E), (1 - u))
            }
        }
    }

    func drawFront(_ c: CGContext, t: Double, cam: F, W: F) {
        // forest canopy mass and ground
        let wf = Geo.weights(cam + W / 2)
        _ = wf
        drawGround(c, t: t, cam: cam, W: W)
        for it in items {
            let sx = it.wx - cam
            if sx + it.ext < -80 || sx - it.ext > W + 80 { continue }
            let g = (it.y ?? (Geo.groundY(it.wx) + 6)) - 6
            c.saveGState()
            if it.layer == 1 { c.translateBy(x: sx, y: g + 6); c.scaleBy(x: 1.25, y: 1.25); c.translateBy(x: -sx, y: -(g + 6)) }
            defer { c.restoreGState() }
            switch it.thing {
            case .house(let h): drawHouse(c, h, x: sx, t: t)
            case .tree(let tr): drawTree(c, tr, x: sx, t: t)
            case .sheep(let s): drawSheep(c, x: sx, y: g + 8, s: s, t: t, seed: it.seed)
            case .snowman: drawSnowman(c, x: sx, y: g + 6, s: 1.0, t: t)
            case .fence(let l): drawFence(c, x: sx - l / 2, y: g + 6, len: l, t: t, seed: it.seed)
            case .wall(let l): drawWall(c, x: sx - l / 2, y: g + 6, len: l, t: t, seed: it.seed)
            case .hedge(let l): drawHedge(c, x: sx - l / 2, y: g + 8, len: l, t: t, seed: it.seed)
            case .gate: drawGate(c, x: sx - 55, y: g + 6, t: t, seed: it.seed)
            case .lamp: drawLamp(c, x: sx, y: g + 6, t: t)
            case .pond(let w): drawPond(c, x: sx, y: g + 16, w: w, t: t)
            case .barn: drawBarn(c, x: sx, base: g + 10, t: t)
            }
        }
    }

    func drawGround(_ c: CGContext, t: Double, cam: F, W: F) {
        // forest canopy mass (so the tree tops float on a dark sea of branches)
        var fpts: [CGPoint] = []
        var anyForest = false
        var x: F = -20
        while x <= W + 20 {
            let wx = cam + x
            let wf = Geo.weights(wx).forest
            if wf > 0.01 { anyForest = true }
            fpts.append(CGPoint(x: x, y: lerp(1200, 790 + 22 * F(sin(Double(wx) / 70)), wf)))
            x += 12
        }
        if anyForest {
            c.saveGState()
            c.move(to: CGPoint(x: -20, y: 1100)); for p in fpts { c.addLine(to: p) }; c.addLine(to: CGPoint(x: W + 20, y: 1100)); c.closePath(); c.clip()
            c.vgrad(CGRect(x: 0, y: 700, width: W, height: 400), [(RGB(0x174F4C), 0), (RGB(0x1F6A5A), 0.5), (RGB(0x2A8068), 1)])
            c.restoreGState()
            let rows: [(F, F, RGB, F)] = [(-70, 150, RGB(0x174F4C), 40), (10, 125, RGB(0x1F6A5A), 36), (100, 115, RGB(0x2A8068), 34), (190, 110, RGB(0x33917A), 32)]
            for (ri, row) in rows.enumerated() {
                var px: F = -40 + F(ri) * 13
                while px < W + 40 {
                    let id = Int(((px + cam) / row.3).rounded()) + ri * 7919
                    let idx = min(fpts.count - 1, max(0, Int((px + 20) / 12)))
                    let wf = Geo.weights(cam + px).forest
                    if wf > 0.2 {
                        let tipH = row.1 * (0.7 + 0.6 * hashF(id, 3)) * wf
                        let base = fpts[idx].y + row.0 + tipH * 0.5
                        let col = row.2.mix(RGB(0x0F3B3A), hashF(id, 4) * 0.5)
                        let hw = tipH * 0.34
                        c.poly([CGPoint(x: px, y: base - tipH), CGPoint(x: px + hw, y: base), CGPoint(x: px - hw, y: base)], col.cg())
                        c.poly([CGPoint(x: px, y: base - tipH), CGPoint(x: px - hw * 0.45, y: base - tipH * 0.5), CGPoint(x: px - hw, y: base)], RGB(0x0A2F34).cg(0.35))
                        snowMounds(c, from: CGPoint(x: px, y: base - tipH + 6), to: CGPoint(x: px + hw * 0.7, y: base - tipH * 0.45), thick: 5, seed: id, shade: false)
                        snowMounds(c, from: CGPoint(x: px, y: base - tipH + 6), to: CGPoint(x: px - hw * 0.7, y: base - tipH * 0.45), thick: 5, seed: id + 1, shade: false)
                    }
                    px += row.3
                }
            }
        }
        // snowfield
        var pts: [CGPoint] = []
        var minY: F = 2000
        x = -20
        while x <= W + 20 { let y = Geo.groundY(cam + x); minY = min(minY, y); pts.append(CGPoint(x: x, y: y)); x += 12 }
        guard minY < 1090 else { return }
        c.saveGState()
        c.move(to: CGPoint(x: -20, y: 1100)); for p in pts { c.addLine(to: p) }; c.addLine(to: CGPoint(x: W + 20, y: 1100)); c.closePath(); c.clip()
        c.vgrad(CGRect(x: 0, y: max(0, minY - 20), width: W, height: 1100 - max(0, minY - 20)), [(Pal.snow, 0), (Pal.snowMid, 0.18), (Pal.snowShade, 1)])
        // soft drift bands
        for k in 1...3 {
            c.setStrokeColor(Pal.snow.cg(0.55)); c.setLineWidth(10); c.setLineCap(.round)
            c.move(to: CGPoint(x: pts[0].x, y: pts[0].y + F(k) * 26))
            for p in pts { c.addLine(to: CGPoint(x: p.x, y: p.y + F(k) * 26 + 8 * F(sin(Double(p.x + cam) / (50 + Double(k) * 20))))) }
            c.strokePath()
        }
        c.restoreGState()
        c.setStrokeColor(RGB(0xFFFFFF).cg(0.95)); c.setLineWidth(6); c.setLineJoin(.round)
        c.move(to: pts[0]); for p in pts.dropFirst() { c.addLine(to: p) }; c.strokePath()
        glitter(c, x0: cam - 20, x1: cam + W + 20, yTop: { wx in Geo.groundY(wx) }, depth: 150, t: t, cell: 40)
    }

    func drawSnowfall(_ c: CGContext, t: Double, cam: F, W: F, layer: Int) {
        let (count, rmin, rmax, speed, par, alpha): (Int, F, F, F, F, F)
        switch layer {
        case 0: (count, rmin, rmax, speed, par, alpha) = (230, 1.0, 1.9, 45, 0.18, 0.7)
        case 1: (count, rmin, rmax, speed, par, alpha) = (120, 1.8, 3.2, 85, 0.6, 0.85)
        default: (count, rmin, rmax, speed, par, alpha) = (44, 4.0, 8.0, 150, 1.25, 0.8)
        }
        let span = W + 300
        for i in 0..<count {
            let seed = i + layer * 1000
            let r = rmin + (rmax - rmin) * hashF(seed, 1)
            let sway = F(sin(t * (0.6 + Double(hashF(seed, 2))) + Double(hashF(seed, 3)) * 6.28)) * (10 + 14 * hashF(seed, 4))
            var x = (hashF(seed, 5) * span - cam * par - F(t) * 22 * hashF(seed, 9)).truncatingRemainder(dividingBy: span)
            if x < 0 { x += span }
            let y = (hashF(seed, 6) * 1200 + F(t) * speed * (0.7 + 0.6 * hashF(seed, 7))).truncatingRemainder(dividingBy: 1200) - 60
            let px = x - 150 + sway
            c.circle(px, y, r, RGB(0xFFFFFF).cg(alpha * (0.6 + 0.4 * hashF(seed, 8))))
            if layer == 2 { c.circle(px, y, r * 1.8, RGB(0xFFFFFF).cg(0.18)) }
        }
    }
}
