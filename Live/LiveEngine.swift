import CoreGraphics
import Foundation
import QuartzCore

// The live renderer. The scenery (hills, houses, trees, snowy ground) never changes except by sliding sideways, so it is drawn once into
// cached "tiles" on a background thread. Every frame then only draws what actually moves (snow, smoke, twinkles, Santa, presents) into two
// transparent overlay pictures, and Core Animation stacks tiles and overlays on the graphics chip.

enum LayerKind: Int, CaseIterable {
    case farHills, midHills, midRow, front
    var par: F { [0.08, 0.22, 0.55, 1.0][rawValue] }
}

struct TileKey: Hashable {
    let kind: LayerKind
    let index: Int
}

final class BakedTile {
    let image: CGImage
    let u0: F              // layer position of the picture's left edge (it includes a small margin so neighbours overlap invisibly)
    let emitters: [Emitter]
    init(image: CGImage, u0: F, emitters: [Emitter]) { self.image = image; self.u0 = u0; self.emitters = emitters }
}

struct FrameData {
    let t: Double
    let back: CGImage      // snow, Santa, presents: sits between the distant and the near scenery
    let front: CGImage     // smoke, twinkles, bursts, near snow: sits on top
    let halo: CGPoint?     // where the soft glow around Santa's team is centred (design units), when he is on screen
}

/// Hands out and takes back the big pixel buffers used for the overlay pictures.
final class BufferPool {
    private let lock = NSLock()
    private var free: [UnsafeMutableRawPointer] = []
    let size: Int
    init(size: Int) { self.size = size }
    func take() -> UnsafeMutableRawPointer {
        lock.lock(); defer { lock.unlock() }
        if let p = free.popLast() { return p }
        return UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 64)
    }
    func give(_ p: UnsafeMutableRawPointer) {
        lock.lock(); defer { lock.unlock() }
        if free.count < 12 { free.append(p) } else { p.deallocate() }
    }
    deinit { for p in free { p.deallocate() } }
}

final class LiveEngine {
    static let tileW: F = 1024
    static let margin: F = 8
    static let top: F = 240          // the cached tiles only cover from here down; the sky above is separate
    static let H: F = 1080
    static let camSpeed: F = 150
    static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    /// Colour space for every picture the engine makes (the display's own, when known, so Core Animation can use them as they are).
    nonisolated(unsafe) static var space = srgb
    static func adopt(_ cs: CGColorSpace?) {
        guard let cs = cs, cs.model == .rgb,
              CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: bitmapInfo) != nil else { return }
        space = cs
        Sprites.use(space: cs)
    }
    static let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    let W: F                 // width of the picture in design units (the height is always 1080)
    let bakeScale: F         // pixels per design unit for the cached scenery
    let overlayScale: F      // pixels per design unit for the live overlays
    private let overlayW: Int, overlayH: Int
    private let pool: BufferPool

    private let tileLock = NSLock()
    private var tiles: [TileKey: BakedTile] = [:]
    private var requested: Set<TileKey> = []
    private let bakeQueue = DispatchQueue(label: "scottishchristmas.bake", qos: .utility)

    private let sceneLock = NSLock()
    private var scenes: [Int: ChristmasScene] = [:]
    private var sceneOrder: [Int] = []

    init(designWidth: F, bakeScale: F, overlayScale: F) {
        W = designWidth
        self.bakeScale = bakeScale
        self.overlayScale = overlayScale
        overlayW = max(2, Int((designWidth * overlayScale).rounded()))
        overlayH = max(2, Int((LiveEngine.H * overlayScale).rounded()))
        pool = BufferPool(size: overlayW * overlayH * 4)
    }

    // MARK: Worlds

    /// A scene covering the journey the camera is in, and the ones either side of it.
    func scene(centre k: Int) -> ChristmasScene {
        sceneLock.lock(); defer { sceneLock.unlock() }
        if let s = scenes[k] { return s }
        let s = ChristmasScene(journeys: max(0, k - 1)..<(k + 2))
        scenes[k] = s
        sceneOrder.append(k)
        if sceneOrder.count > 5 { scenes.removeValue(forKey: sceneOrder.removeFirst()) }
        return s
    }
    func scene(forCam cam: F) -> ChristmasScene {
        scene(centre: max(0, Int(((cam + 960 - Geo.origin) / Geo.C).rounded(.down))))
    }
    func scene(forTime t: Double) -> ChristmasScene { scene(forCam: LiveEngine.camSpeed * F(t)) }

    // MARK: Baking

    private func bake(_ key: TileKey) -> BakedTile {
        let par = key.kind.par
        let wD = LiveEngine.tileW + 2 * LiveEngine.margin, hD = LiveEngine.H - LiveEngine.top
        let u0 = F(key.index) * LiveEngine.tileW - LiveEngine.margin
        let pw = Int((wD * bakeScale).rounded(.up)), ph = Int((hD * bakeScale).rounded(.up))
        let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: LiveEngine.space, bitmapInfo: LiveEngine.bitmapInfo)!
        ctx.translateBy(x: 0, y: F(ph)); ctx.scaleBy(x: F(pw) / wD, y: -F(ph) / hD); ctx.translateBy(x: 0, y: -LiveEngine.top)
        ctx.interpolationQuality = .high

        let state = BakeState()
        state.originX = u0
        state.record = key.kind == .front || key.kind == .midRow
        state.baseInverse = ctx.ctm.inverted()
        state.twinkleValue = key.kind == .front ? 1 : 0.35
        Bake.begin(state)
        defer { Bake.end() }

        let camEq = (u0 + wD / 2 - 960) / par
        switch key.kind {
        case .farHills: scene(centre: 0).drawFarHillsTile(ctx, u0: u0, W: wD)
        case .midHills: scene(centre: 0).drawMidHillsTile(ctx, u0: u0, W: wD)
        case .midRow: scene(forCam: camEq).drawMidRowTile(ctx, t: 0, u0: u0, W: wD)
        case .front: scene(forCam: camEq).drawFront(ctx, t: 0, cam: u0, W: wD)
        }
        return BakedTile(image: ctx.makeImage()!, u0: u0, emitters: state.emitters)
    }

    private func range(_ kind: LayerKind, cam: F, ahead: Int) -> ClosedRange<Int> {
        let uL = cam * kind.par - LiveEngine.margin, uR = cam * kind.par + W + LiveEngine.margin
        return Int((uL / LiveEngine.tileW).rounded(.down))...(Int((uR / LiveEngine.tileW).rounded(.down)) + ahead)
    }

    /// Asks for every tile the camera will need soon, and drops the ones it has passed.
    func prepare(cam: F) {
        for kind in LayerKind.allCases {
            let r = range(kind, cam: cam, ahead: 2)
            for i in r {
                let key = TileKey(kind: kind, index: i)
                tileLock.lock()
                let need = tiles[key] == nil && !requested.contains(key)
                if need { requested.insert(key) }
                tileLock.unlock()
                if need {
                    bakeQueue.async { [weak self] in
                        guard let self = self else { return }
                        let tile = self.bake(key)
                        self.tileLock.lock(); self.tiles[key] = tile; self.requested.remove(key); self.tileLock.unlock()
                    }
                }
            }
            tileLock.lock()
            for k in tiles.keys where k.kind == kind && k.index < r.lowerBound - 1 { tiles.removeValue(forKey: k) }
            tileLock.unlock()
        }
    }

    /// Blocks until the tiles visible right now exist (used once at the start).
    func prepareAndWait(cam: F) {
        prepare(cam: cam)
        bakeQueue.sync {}
    }

    func visibleTiles(cam: F) -> [(TileKey, BakedTile)] {
        var out: [(TileKey, BakedTile)] = []
        tileLock.lock(); defer { tileLock.unlock() }
        for kind in LayerKind.allCases {
            for i in range(kind, cam: cam, ahead: 0) {
                let key = TileKey(kind: kind, index: i)
                if let t = tiles[key] { out.append((key, t)) }
            }
        }
        return out
    }

    func releaseAll() {
        tileLock.lock(); tiles.removeAll(); tileLock.unlock()
    }

    // MARK: Fixed pictures

    func skyImage() -> CGImage {
        let scale = max(1, min(bakeScale, 1.5))
        let pw = Int((W * scale).rounded()), ph = Int((LiveEngine.H * scale).rounded())
        let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: LiveEngine.space, bitmapInfo: LiveEngine.bitmapInfo)!
        ctx.translateBy(x: 0, y: F(ph)); ctx.scaleBy(x: scale, y: -scale)
        scene(centre: 0).drawSkyBase(ctx, W: W)
        return ctx.makeImage()!
    }

    func cloudImages() -> [(image: CGImage, bounds: CGRect)] {
        let scale = max(1, min(bakeScale, 1.5))
        return (0..<ChristmasScene.cloudCount).map { i in
            let b = ChristmasScene.cloudBounds(i)
            let pw = Int((b.width * scale).rounded(.up)), ph = Int((b.height * scale).rounded(.up))
            let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: LiveEngine.space, bitmapInfo: LiveEngine.bitmapInfo)!
            ctx.translateBy(x: 0, y: F(ph)); ctx.scaleBy(x: F(pw) / b.width, y: -F(ph) / b.height); ctx.translateBy(x: -b.minX, y: -b.minY)
            scene(centre: 0).drawCloud(ctx, i)
            return (ctx.makeImage()!, b)
        }
    }

    /// The soft warm glow around Santa's team: a gradient picture the graphics chip scales and moves for free.
    func haloImage() -> CGImage {
        let n = 256
        let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: LiveEngine.space, bitmapInfo: LiveEngine.bitmapInfo)!
        let c = RGB(0xFFD9A0)
        let g = CGGradient(colorsSpace: LiveEngine.srgb, colors: [c.cg(0.16), c.cg(0.16 * 0.35), c.cg(0)] as CFArray, locations: [0, 0.35, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: n / 2, y: n / 2), startRadius: 0, endCenter: CGPoint(x: n / 2, y: n / 2), endRadius: F(n / 2), options: [])
        return ctx.makeImage()!
    }

    func vignetteImage() -> CGImage {
        let scale: F = 0.5
        let pw = Int((W * scale).rounded()), ph = Int((LiveEngine.H * scale).rounded())
        let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: LiveEngine.space, bitmapInfo: LiveEngine.bitmapInfo)!
        ctx.translateBy(x: 0, y: F(ph)); ctx.scaleBy(x: scale, y: -scale)
        let g = CGGradient(colorsSpace: LiveEngine.srgb, colors: [RGB(0x05061F).cg(0), RGB(0x05061F).cg(0.38)] as CFArray, locations: [0.55, 1])!
        let c = CGPoint(x: W / 2, y: LiveEngine.H / 2)
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: hypot(W, LiveEngine.H) * 0.62, options: [.drawsAfterEndLocation])
        return ctx.makeImage()!
    }

    // MARK: Per-frame drawing

    private func overlay() -> (CGContext, UnsafeMutableRawPointer) {
        let buf = pool.take()
        memset(buf, 0, pool.size)
        let ctx = CGContext(data: buf, width: overlayW, height: overlayH, bitsPerComponent: 8, bytesPerRow: overlayW * 4, space: LiveEngine.space, bitmapInfo: LiveEngine.bitmapInfo)!
        ctx.translateBy(x: 0, y: F(overlayH)); ctx.scaleBy(x: overlayScale, y: -overlayScale)
        return (ctx, buf)
    }

    private func image(_ buf: UnsafeMutableRawPointer) -> CGImage {
        let info = Unmanaged.passRetained(pool).toOpaque()
        let provider = CGDataProvider(dataInfo: info, data: buf, size: pool.size) { info, data, _ in
            let p = Unmanaged<BufferPool>.fromOpaque(info!).takeRetainedValue()
            p.give(UnsafeMutableRawPointer(mutating: data))
        }!
        return CGImage(width: overlayW, height: overlayH, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: overlayW * 4, space: LiveEngine.space,
                       bitmapInfo: CGBitmapInfo(rawValue: LiveEngine.bitmapInfo), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }

    /// Draws everything that moves for time t.
    func renderFrame(t: Double) -> FrameData {
        let cam = LiveEngine.camSpeed * F(t)
        let scene = self.scene(forTime: t)
        let (bctx, bbuf) = overlay()
        let (fctx, fbuf) = overlay()

        // between the distant and near scenery
        scene.drawSkyTwinkles(bctx, t: t, W: W)
        scene.drawSnowfall(bctx, t: t, cam: cam, W: W, layer: 0)
        scene.drawSantaLayer(bctx, t: t, cam: cam, W: W, halo: false)
        scene.drawSnowfall(bctx, t: t, cam: cam, W: W, layer: 1)

        // smoke from the distant chimneys sits with the mid-distance scenery
        for (key, tile) in visibleTiles(cam: cam) where key.kind == .midRow {
            for e in tile.emitters where e.kind == .smoke {
                let sx = e.x - cam * key.kind.par
                if sx < -60 || sx > W + 60 { continue }
                bctx.saveGState(); bctx.translateBy(x: sx, y: e.y); bctx.scaleBy(x: e.sc, y: e.sc)
                drawSmoke(bctx, x: 0, y: 0, t: t, seed: e.seed, strength: e.r * 0.8)
                bctx.restoreGState()
            }
        }

        // on top of the near scenery
        for (key, tile) in visibleTiles(cam: cam) where key.kind == .front {
            for e in tile.emitters {
                let sx = e.x - cam
                if sx < -60 || sx > W + 60 { continue }
                switch e.kind {
                case .sparkle:
                    let f = twinkle(t, e.phase, e.rate)
                    if f > 0.05 { Sprites.draw(fctx, Sprites.starImage(e.c), sx, e.y, e.r * (0.45 + 0.55 * f) * 1.5, e.a * f) }
                case .glow:
                    Sprites.draw(fctx, Sprites.glowImage(e.c), sx, e.y, e.r, e.a * (e.base + (1 - e.base) * twinkle(t, e.phase, e.rate)))
                case .smoke:
                    fctx.saveGState(); fctx.translateBy(x: sx, y: e.y); fctx.scaleBy(x: e.sc, y: e.sc)
                    drawSmoke(fctx, x: 0, y: 0, t: t, seed: e.seed, strength: e.r)
                    fctx.restoreGState()
                }
            }
        }
        scene.drawFrontDynamic(fctx, t: t, cam: cam, W: W)
        scene.drawPotBursts(fctx, t: t, cam: cam)
        scene.drawSnowfall(fctx, t: t, cam: cam, W: W, layer: 2)
        var halo: CGPoint? = nil
        if let pose = scene.santaPose(t, width: W) { halo = CGPoint(x: pose.x + 250, y: pose.y) }
        return FrameData(t: t, back: image(bbuf), front: image(fbuf), halo: halo)
    }
}

// MARK: - Putting the pieces on screen with Core Animation

final class LiveCompositor {
    let root = CALayer()
    private let content = CALayer()
    private let engine: LiveEngine
    private var tileLayers: [TileKey: CALayer] = [:]
    private var clouds: [(layer: CALayer, bounds: CGRect)] = []
    private let backLayer = CALayer()
    private let frontLayer = CALayer()
    private let haloLayer = CALayer()
    private let W: F

    private static func plain(_ l: CALayer) {
        l.anchorPoint = .zero
        l.contentsGravity = .resize
        l.magnificationFilter = .linear
        l.minificationFilter = .linear
        l.edgeAntialiasingMask = []
        l.actions = ["contents": NSNull(), "position": NSNull(), "bounds": NSNull(), "frame": NSNull(), "opacity": NSNull()]
    }

    init(engine: LiveEngine) {
        self.engine = engine
        W = engine.W
        root.backgroundColor = CGColor(red: 0.035, green: 0.05, blue: 0.22, alpha: 1)
        root.masksToBounds = true
        content.bounds = CGRect(x: 0, y: 0, width: W, height: LiveEngine.H)
        LiveCompositor.plain(content)
        content.actions = ["position": NSNull(), "bounds": NSNull(), "frame": NSNull()]   // but let opacity animate for the fade-in
        root.addSublayer(content)

        func add(_ image: CGImage?, frame: CGRect, z: CGFloat) -> CALayer {
            let l = CALayer()
            LiveCompositor.plain(l)
            l.contents = image
            l.frame = frame
            l.zPosition = z
            content.addSublayer(l)
            return l
        }
        let full = CGRect(x: 0, y: 0, width: W, height: LiveEngine.H)
        _ = add(engine.skyImage(), frame: full, z: 0)
        for (img, b) in engine.cloudImages() {
            let l = add(img, frame: CGRect(origin: .zero, size: b.size), z: 1)
            l.opacity = 1
            clouds.append((l, b))
        }
        _ = add(engine.vignetteImage(), frame: full, z: 9)
        LiveCompositor.plain(haloLayer)
        haloLayer.contents = engine.haloImage()
        haloLayer.bounds = CGRect(x: 0, y: 0, width: 1280, height: 1280)
        haloLayer.zPosition = 4.5
        haloLayer.isHidden = true
        content.addSublayer(haloLayer)
        for (l, z) in [(backLayer, CGFloat(5)), (frontLayer, 7)] {
            LiveCompositor.plain(l)
            l.frame = full
            l.zPosition = z
            content.addSublayer(l)
        }
    }

    /// Lets go of every picture the layers hold (so the memory comes back at once, whenever the layer tree itself is finally freed).
    func clear() {
        func wipe(_ l: CALayer) { l.contents = nil; l.sublayers?.forEach(wipe) }
        wipe(root)
        tileLayers.removeAll()
    }

    /// Fits the picture to the view: it always fills the height, and shows a little more or less at the sides.
    func layout(viewSize: CGSize) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.frame = CGRect(origin: .zero, size: viewSize)
        let s = viewSize.height / LiveEngine.H
        content.position = CGPoint(x: (viewSize.width - W * s) / 2, y: 0)
        content.setAffineTransform(CGAffineTransform(scaleX: s, y: s))
        CATransaction.commit()
    }

    private var firstFrameShown = false

    /// Moves everything to where it belongs for this frame. Call on the main thread.
    func apply(_ frame: FrameData) {
        if !firstFrameShown {
            // a gentle fade up from the night sky when the screensaver starts
            firstFrameShown = true
            content.opacity = 0
            CATransaction.begin(); CATransaction.setAnimationDuration(0.9)
            content.opacity = 1
            CATransaction.commit()
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let cam = LiveEngine.camSpeed * F(frame.t)
        let hD = LiveEngine.H - LiveEngine.top, wD = LiveEngine.tileW + 2 * LiveEngine.margin
        var live: Set<TileKey> = []
        for (key, tile) in engine.visibleTiles(cam: cam) {
            live.insert(key)
            let layer: CALayer
            if let l = tileLayers[key] { layer = l } else {
                layer = CALayer(); LiveCompositor.plain(layer)
                layer.contents = tile.image
                // show only the picture's middle plus 1 unit each side: neighbours still overlap (no hairline gaps) without doubling up translucent edges
                let m = LiveEngine.margin
                layer.contentsRect = CGRect(x: (m - 1) / wD, y: 0, width: (LiveEngine.tileW + 2) / wD, height: 1)
                layer.bounds = CGRect(x: 0, y: 0, width: LiveEngine.tileW + 2, height: hD)
                layer.zPosition = [CGFloat(2), 3, 4, 6][key.kind.rawValue]
                content.addSublayer(layer)
                tileLayers[key] = layer
            }
            // bottom-left origin: the tile runs from y = top to the bottom of the picture, so it sits at y = 0
            layer.position = CGPoint(x: tile.u0 + LiveEngine.margin - 1 - cam * key.kind.par, y: 0)
        }
        for (key, layer) in tileLayers where !live.contains(key) { layer.removeFromSuperlayer(); tileLayers.removeValue(forKey: key) }

        let scene = engine.scene(forTime: frame.t)
        for (i, c) in clouds.enumerated() {
            let p = scene.cloudPosition(i, t: frame.t, cam: cam, W: W)
            c.layer.position = CGPoint(x: p.x + c.bounds.minX, y: LiveEngine.H - (p.y + c.bounds.minY) - c.bounds.height)
        }
        if let h = frame.halo {
            haloLayer.isHidden = false
            haloLayer.position = CGPoint(x: h.x - 640, y: LiveEngine.H - h.y - 640)
        } else { haloLayer.isHidden = true }
        backLayer.contents = frame.back
        frontLayer.contents = frame.front
        CATransaction.commit()
    }
}
