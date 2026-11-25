import AppKit
import CoreGraphics
import Foundation
import ImageIO
import QuartzCore
import UniformTypeIdentifiers

// Test tool for the live engine.
//   livetest still <seconds> <out.png> [width height]      composite one frame exactly as the screensaver does
//   livetest bench [width height]                          time baking and per-frame drawing

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? ""

func makeEngine(_ w: Int, _ h: Int, scale: F = 1) -> LiveEngine {
    LiveEngine(designWidth: (1080 * F(w) / F(h)).rounded(), bakeScale: scale, overlayScale: 1)
}

func png(_ layer: CALayer, _ w: Int, _ h: Int, _ path: String) {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: LiveEngine.srgb, bitmapInfo: LiveEngine.bitmapInfo)!
    layer.render(in: ctx)
    let img = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

switch cmd {
case "still":
    let t = Double(args[1]) ?? 0
    let w = args.count > 3 ? Int(args[3])! : 1920, h = args.count > 4 ? Int(args[4])! : 1080
    let engine = makeEngine(w, h)
    let comp = LiveCompositor(engine: engine)
    comp.layout(viewSize: CGSize(width: w, height: h))
    let cam = LiveEngine.camSpeed * F(t)
    let t0 = Date()
    engine.prepareAndWait(cam: cam)
    let tBake = Date().timeIntervalSince(t0)
    let frame = engine.renderFrame(t: t)
    comp.apply(frame)
    png(comp.root, w, h, args[2])
    print(String(format: "t=%.1fs -> %@  (first-screen bake %.0f ms)", t, args[2], tBake * 1000))

case "bench":
    let w = args.count > 2 ? Int(args[1])! : 1920, h = args.count > 2 ? Int(args[2])! : 1080
    for (label, start) in [("rooftops + Santa", 8.0), ("countryside", 28.0), ("forest", 46.0), ("village + Santa", 64.0)] {
        let engine = makeEngine(w, h)
        let cam0 = LiveEngine.camSpeed * F(start)
        let t0 = Date()
        engine.prepareAndWait(cam: cam0)
        let bake = Date().timeIntervalSince(t0)
        // draw 90 consecutive frames (3 s of film) on one thread
        let n = 90
        let t1 = Date()
        var held: [FrameData] = []
        for i in 0..<n {
            let t = start + Double(i) / 30
            engine.prepare(cam: LiveEngine.camSpeed * F(t))
            held.append(engine.renderFrame(t: t)); if held.count > 4 { held.removeFirst() }
        }
        let per = Date().timeIntervalSince(t1) / Double(n) * 1000
        print(String(format: "%-18@ first-screen bake %4.0f ms | live frame %5.1f ms  (= %.0f frames/s on one thread)", label as NSString, bake * 1000, per, 1000 / per))
    }

case "santa":
    let scene = ChristmasScene(journeys: 0..<2)
    let W: F = 1920
    let ctx = CGContext(data: nil, width: 1920, height: 1080, bitsPerComponent: 8, bytesPerRow: 0, space: LiveEngine.srgb, bitmapInfo: LiveEngine.bitmapInfo)!
    ctx.translateBy(x: 0, y: 1080); ctx.scaleBy(x: 1, y: -1)
    let t = 10.0, cam = LiveEngine.camSpeed * F(t)
    let pose = scene.santaPose(t, width: W)!
    func time(_ name: String, _ f: () -> Void) { let t0 = Date(); for _ in 0..<20 { f() }; print(String(format: "%-26@ %6.2f ms", name as NSString, Date().timeIntervalSince(t0) / 20 * 1000)) }
    time("whole Santa layer") { scene.drawSantaLayer(ctx, t: t, cam: cam, W: W) }
    time("big halo glow r=640") { ctx.glow(pose.x + 250, pose.y, 640, RGB(0xFFD9A0), 0.16) }
    time("sleigh + team") { drawSantaTeam(ctx, x: pose.x, y: pose.y, tilt: pose.tilt, s: 0.85, t: t) }
    time("one reindeer") { drawReindeer(ctx, x: 500, y: 300, s: 0.9, phase: 0, rudolph: true, t: t) }
    time("magic dust") { drawMagicDust(ctx, t: t, origin: { te in CGPoint(x: pose.x - 60, y: pose.y - 10) }, cam: { LiveEngine.camSpeed * F($0) }) }
    time("one present") { drawPresent(ctx, x: 600, y: 400, size: 60, angle: 0.3, paper: Pal.presentPapers[1], ribbon: Pal.gold, pattern: 2, t: t, seed: 3) }
    time("snow layer 0 + 1 + 2") { scene.drawSnowfall(ctx, t: t, cam: cam, W: W, layer: 0); scene.drawSnowfall(ctx, t: t, cam: cam, W: W, layer: 1); scene.drawSnowfall(ctx, t: t, cam: cam, W: W, layer: 2) }
    time("sky twinkles") { scene.drawSkyTwinkles(ctx, t: t, W: W) }

default:
    print("usage: livetest still|bench ...")
}
