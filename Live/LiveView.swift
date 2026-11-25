import AppKit
import QuartzCore
import ScreenSaver

/// The live-drawn screensaver: an endless journey over snowy UK rooftops and treetops, drawn as it plays (the scenery is cached in
/// tiles and only what moves is drawn each frame, on two background threads, and composited by the graphics chip).
@objc(ScottishChristmasLiveView)
final class ScottishChristmasLiveView: ScreenSaverView {
    private var engine: LiveEngine?
    private var pipeline: FramePipeline?
    private var compositor: LiveCompositor?
    private var builtFor = CGSize.zero
    private var startWall: CFTimeInterval?
    private var lastShown = -1
    private var stopObserver: NSObjectProtocol?
    private var previewMode = false
    private var displayLink: CADisplayLink?
    private var lastLinkTick: CFTimeInterval = 0

    // Counters for diagnosing smoothness (read by the test host; harmless otherwise).
    private var ticks = 0, shown = 0, skipped = 0, notReady = 0
    private var applyTotal = 0.0, applyMax = 0.0
    @objc var debugStats: String {
        String(format: "ticks=%d shown=%d skipped(frame numbers jumped)=%d notReady=%d  main-thread apply avg %.2f ms max %.1f ms", ticks, shown, skipped, notReady, shown > 0 ? applyTotal / Double(shown) * 1000 : 0, applyMax * 1000)
    }

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        previewMode = isPreview
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        if let o = stopObserver { DistributedNotificationCenter.default().removeObserver(o) }
    }

    private func commonInit() {
        animationTimeInterval = 1.0 / 30.0   // fallback only: the display link below normally drives the frames
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        stopObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.willstop"), object: nil, queue: .main) { [weak self] _ in
            self?.tearDown()
        }
    }

    override var hasConfigureSheet: Bool { false }
    override var isOpaque: Bool { true }

    private func build() {
        let size = bounds.size
        guard size.width > 8, size.height > 8 else { return }
        tearDown()
        let screen = window?.screen ?? NSScreen.main
        LiveEngine.adopt(screen?.colorSpace?.cgColorSpace)
        let scale = window?.backingScaleFactor ?? screen?.backingScaleFactor ?? 2
        let pixelH = size.height * scale
        let aspect = size.width / size.height
        let designW = (1080 * aspect).rounded()
        let bakeScale = max(0.3, min(1.5, pixelH / 1080))
        let overlayScale: CGFloat = previewMode ? 0.35 : 1
        let eng = LiveEngine(designWidth: designW, bakeScale: bakeScale, overlayScale: overlayScale)
        let comp = LiveCompositor(engine: eng)
        comp.layout(viewSize: size)
        comp.root.contentsScale = scale
        layer = comp.root          // the whole picture is one layer tree, composited on the graphics chip
        wantsLayer = true
        // a different part of the endless journey each time
        var startT = previewMode ? 8.0 : Double.random(in: 0..<20000)   // the settings preview starts with Santa over the rooftops
        if let forced = ProcessInfo.processInfo.environment["SCOTTISH_CHRISTMAS_START"], let v = Double(forced) { startT = v }   // for testing
        let pipe = FramePipeline(engine: eng, startT: startT)
        engine = eng; compositor = comp; pipeline = pipe; builtFor = size
        startWall = nil; lastShown = -1
        pipe.start(workers: previewMode ? 1 : 2)
    }

    private func tearDown() {
        pipeline?.stop()
        compositor?.clear()
        engine?.releaseAll()
        pipeline = nil; engine = nil; compositor = nil
        startWall = nil
    }

    override func startAnimation() {
        super.startAnimation()
        if pipeline == nil { build() }
        startDisplayLink()
    }

    override func stopAnimation() {
        super.stopAnimation()
        stopDisplayLink()
        tearDown()
    }

    /// Frames are paced by the display's own refresh signal, which ticks evenly (a plain timer drifts and makes the glide judder).
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = displayLink(target: self, selector: #selector(linkTick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func linkTick(_ link: CADisplayLink) {
        lastLinkTick = CACurrentMediaTime()
        showFrame(at: link.targetTimestamp)
    }

    override func layout() {
        super.layout()
        guard compositor != nil else { return }
        if abs(bounds.size.width - builtFor.width) > 1 || abs(bounds.size.height - builtFor.height) > 1 {
            // a new size (a new display, or the settings preview resizing): rebuild for it
            if isAnimating { build() }
        }
    }

    override func animateOneFrame() {
        // only needed if the display link is not delivering
        if CACurrentMediaTime() - lastLinkTick > 0.25 { showFrame(at: CACurrentMediaTime()) }
    }

    private func showFrame(at now: CFTimeInterval) {
        guard let pipe = pipeline, let comp = compositor else { return }
        if startWall == nil {
            guard pipe.isPrimed else { return }
            startWall = now
        }
        let k = Int((now - startWall!) * pipe.fps)
        ticks += 1
        if let (j, frame) = pipe.frame(atIndex: k) {
            if j > lastShown {
                if lastShown >= 0 && j - lastShown > 1 { skipped += 1 }
                lastShown = j
                let t0 = CACurrentMediaTime()
                comp.apply(frame)
                let d = CACurrentMediaTime() - t0
                shown += 1; applyTotal += d; applyMax = max(applyMax, d)
            }
        } else { notReady += 1 }
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
    }
}
