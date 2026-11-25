import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Test renderer: draws the scene without installing anything.
//   render still <seconds> <out.png> [width height]
//   render video <out.mp4> [seconds=90] [fps=30] [width=1920] [height=1080]

let args = Array(CommandLine.arguments.dropFirst())
let scene = ChristmasScene(journeys: 3)

func makeContext(_ w: Int, _ h: Int, _ data: UnsafeMutableRawPointer) -> CGContext {
    let ctx = CGContext(data: data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.setAllowsAntialiasing(true); ctx.setShouldAntialias(true); ctx.interpolationQuality = .high
    return ctx
}

func render(t: Double, w: Int, h: Int, into buf: UnsafeMutableRawPointer, fade: Bool = true) {
    let ctx = makeContext(w, h, buf)
    let s = CGFloat(h) / 1080
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: s, y: -s)
    scene.draw(ctx, t: t, width: CGFloat(w) / s, fadeInOut: fade)
}

func writePNG(_ buf: UnsafeMutableRawPointer, _ w: Int, _ h: Int, _ path: String) {
    let ctx = makeContext(w, h, buf)
    guard let img = ctx.makeImage(), let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

guard let cmd = args.first else { print("usage: render still|video ..."); exit(1) }

switch cmd {
case "still":
    let t = Double(args[1]) ?? 0
    let w = args.count > 3 ? Int(args[3])! : 1920, h = args.count > 4 ? Int(args[4])! : 1080
    let buf = UnsafeMutableRawPointer.allocate(byteCount: w * h * 4, alignment: 16)
    memset(buf, 0, w * h * 4)
    let t0 = Date()
    render(t: t, w: w, h: h, into: buf, fade: false)
    writePNG(buf, w, h, args[2])
    print(String(format: "t=%.1fs -> %@ (%.0f ms)", t, args[2], Date().timeIntervalSince(t0) * 1000))

case "video":
    let out = args[1]
    let secs = args.count > 2 ? Double(args[2])! : 90
    let fps = args.count > 3 ? Int(args[3])! : 30
    let w = args.count > 4 ? Int(args[4])! : 1920, h = args.count > 5 ? Int(args[5])! : 1080
    scene.duration = secs
    let total = Int(secs * Double(fps))
    let ff = Process()
    ff.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FFMPEG_PATH"] ?? "/opt/homebrew/bin/ffmpeg")
    ff.arguments = ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", "\(w)x\(h)", "-r", "\(fps)", "-i", "-",
                    "-c:v", "libx264", "-preset", "slow", "-tune", "animation", "-crf", ProcessInfo.processInfo.environment["FILM_CRF"] ?? "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out]
    let pipe = Pipe()
    ff.standardInput = pipe
    try! ff.run()
    let batch = max(4, ProcessInfo.processInfo.activeProcessorCount)
    let bytes = w * h * 4
    let bufs = (0..<batch).map { _ in UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 16) }
    let t0 = Date()
    var frame = 0
    while frame < total {
        let n = min(batch, total - frame)
        let start = frame
        DispatchQueue.concurrentPerform(iterations: n) { i in
            memset(bufs[i], 0, bytes)
            render(t: Double(start + i) / Double(fps), w: w, h: h, into: bufs[i])
        }
        for i in 0..<n { pipe.fileHandleForWriting.write(Data(bytesNoCopy: bufs[i], count: bytes, deallocator: .none)) }
        frame += n
        if (frame / batch) % 10 == 0 { print(String(format: "%d/%d frames (%.0fs elapsed)", frame, total, Date().timeIntervalSince(t0))) }
    }
    pipe.fileHandleForWriting.closeFile()
    ff.waitUntilExit()
    print("done: \(out) status \(ff.terminationStatus) in \(Int(Date().timeIntervalSince(t0)))s")

case "profile": break

default:
    print("unknown command")
}

// profile: time each stage on one thread
if cmd == "profile" {
    let w = 1920, h = 1080
    let buf = UnsafeMutableRawPointer.allocate(byteCount: w * h * 4, alignment: 16)
    for t in [10.0, 28.0, 46.0, 64.0, 80.0] {
        memset(buf, 0, w * h * 4)
        let ctx = makeContext(w, h, buf)
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
        let cm = scene.cam(t)
        func time(_ name: String, _ f: () -> Void) -> Double { let t0 = Date(); for _ in 0..<3 { f() }; return Date().timeIntervalSince(t0) / 3 * 1000 }
        var parts: [(String, Double)] = []
        parts.append(("sky", time("sky") { scene.drawSky(ctx, t: t, cam: cm, W: 1920) }))
        parts.append(("farHills", time("") { scene.drawFarHills(ctx, t: t, cam: cm, W: 1920) }))
        parts.append(("snow0", time("") { scene.drawSnowfall(ctx, t: t, cam: cm, W: 1920, layer: 0) }))
        parts.append(("midRow", time("") { scene.drawMidRow(ctx, t: t, cam: cm, W: 1920) }))
        parts.append(("midHills", time("") { scene.drawMidHillsFront(ctx, cam: cm, W: 1920) }))
        parts.append(("santa", time("") { scene.drawSantaLayer(ctx, t: t, cam: cm, W: 1920) }))
        parts.append(("front", time("") { scene.drawFront(ctx, t: t, cam: cm, W: 1920) }))
        parts.append(("snow2", time("") { scene.drawSnowfall(ctx, t: t, cam: cm, W: 1920, layer: 2) }))
        print(String(format: "t=%2.0f  total %5.0f ms  ", t, parts.reduce(0) { $0 + $1.1 }) + parts.map { String(format: "%@ %.0f", $0.0, $0.1) }.joined(separator: " | "))
    }
}
