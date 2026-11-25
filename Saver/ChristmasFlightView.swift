import AVFoundation
import QuartzCore
import ScreenSaver

/// Plays the bundled film (a fixed camera flying over snowy UK rooftops and treetops while Santa drops presents down the
/// chimneys) silently and in a loop, full screen. The film is hardware-decoded, so the saver uses almost no CPU.
@objc(ChristmasFlightView)
final class ChristmasFlightView: ScreenSaverView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private var missingVideo = false
    private var stopObserver: NSObjectProtocol?
    private var itemObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var ready = false          // the film is loaded and (if wanted) moved to its starting point
    private var randomStart = false

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setUp(isPreview: isPreview)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp(isPreview: false)
    }

    deinit {
        if let o = stopObserver { DistributedNotificationCenter.default().removeObserver(o) }
    }

    override var hasConfigureSheet: Bool { false }
    override var isOpaque: Bool { true }

    private func setUp(isPreview: Bool) {
        animationTimeInterval = 1.0   // only used as a gentle watchdog, the film plays itself
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        guard let url = Bundle(for: ChristmasFlightView.self).url(forResource: "christmas-flight", withExtension: "mp4") else {
            missingVideo = true
            NSLog("ScottishChristmas: christmas-flight.mp4 is missing from the saver bundle")
            return
        }
        let asset = AVURLAsset(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(asset: asset))
        player = queue

        let pl = AVPlayerLayer(player: queue)
        pl.frame = bounds
        pl.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(pl)
        playerLayer = pl
        updateGravity()

        // A different part of the journey each time (and on each display); the settings preview always starts at the beginning.
        // The jump happens once the film is loaded, before it starts playing, so nothing odd is ever seen.
        randomStart = !isPreview
        itemObservation = queue.observe(\.currentItem, options: [.initial, .new]) { [weak self] q, _ in
            guard let self = self, !self.ready, let item = q.currentItem else { return }
            self.statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard let self = self, item.status == .readyToPlay else { return }
                DispatchQueue.main.async { self.filmIsReady(item) }
            }
        }

        // The screensaver host does not always call stopAnimation promptly, so also listen for the system's own signal.
        stopObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.willstop"), object: nil, queue: .main) { [weak self] _ in
            self?.player?.pause()
        }
    }

    private func filmIsReady(_ item: AVPlayerItem) {
        guard !ready else { return }
        ready = true
        statusObservation = nil
        let length = item.duration.seconds
        if randomStart, length.isFinite, length > 60 {
            let target = CMTime(seconds: Double.random(in: 0...(length - 40)), preferredTimescale: 600)
            player?.seek(to: target) { [weak self] _ in
                DispatchQueue.main.async { if self?.isAnimating == true { self?.player?.play() } }
            }
        } else if isAnimating {
            player?.play()
        }
    }

    private func updateGravity() {
        // Fill the screen on normal displays; on very wide ones show the whole picture so Santa and the rooftops are never cropped.
        let aspect = bounds.width / max(bounds.height, 1)
        playerLayer?.videoGravity = aspect > 2.05 ? .resizeAspect : .resizeAspectFill
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer?.frame = bounds
        updateGravity()
        CATransaction.commit()
    }

    override func startAnimation() {
        super.startAnimation()
        if ready { player?.play() }   // otherwise it starts as soon as the film is loaded
    }

    override func stopAnimation() {
        super.stopAnimation()
        player?.pause()
    }

    override func animateOneFrame() {
        // Watchdog: if playback ever stalls, nudge it.
        if isAnimating, ready, let p = player, p.rate == 0 { p.play() }
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
        if missingVideo {
            let text = "Scottish Christmas: the film file is missing from the saver. Please reinstall."
            let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 18)]
            let size = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: bounds.height / 2), withAttributes: attrs)
        }
    }
}
