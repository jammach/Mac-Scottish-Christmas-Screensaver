import Foundation

/// Draws frames ahead of time on a couple of background threads, and hands the right one to the screen at the right moment.
/// Every frame depends only on its own time, so the workers never need to wait for each other.
final class FramePipeline {
    let engine: LiveEngine
    let fps: Double
    let startT: Double                 // film time of frame 0
    private let cond = NSCondition()
    private var ready: [Int: FrameData] = [:]
    private var nextToRender = 0
    private var consumerIndex = 0
    private var running = false
    private var threads: [Thread] = []
    private(set) var framesDrawn = 0
    private(set) var latestReady = -1

    init(engine: LiveEngine, startT: Double, fps: Double = 30) {
        self.engine = engine
        self.startT = startT
        self.fps = fps
    }

    func start(workers: Int = 2) {
        cond.lock()
        guard !running else { cond.unlock(); return }
        running = true
        nextToRender = 0; consumerIndex = 0; ready.removeAll()
        cond.unlock()
        engine.prepareAndWait(cam: LiveEngine.camSpeed * F(startT))
        for i in 0..<workers {
            let th = Thread { [weak self] in self?.work() }
            th.name = "scottishchristmas.render.\(i)"
            th.qualityOfService = .userInitiated
            threads.append(th)
            th.start()
        }
    }

    func stop() {
        cond.lock(); running = false; cond.broadcast(); cond.unlock()
        threads.removeAll()
        cond.lock(); ready.removeAll(); cond.unlock()
    }

    private func work() {
        while true {
            cond.lock()
            while running && nextToRender > consumerIndex + 5 { cond.wait() }
            if !running { cond.unlock(); return }
            nextToRender = max(nextToRender, consumerIndex)   // never draw frames that are already in the past
            let k = nextToRender
            nextToRender += 1
            cond.unlock()

            let t = startT + Double(k) / fps
            engine.prepare(cam: LiveEngine.camSpeed * F(t))
            let frame = engine.renderFrame(t: t)

            cond.lock()
            if running {
                ready[k] = frame
                framesDrawn += 1
                latestReady = max(latestReady, k)
                for key in ready.keys where key < consumerIndex - 1 { ready.removeValue(forKey: key) }
            }
            cond.unlock()
        }
    }

    /// Frames 0, 1 and 2 are ready: time to start the clock.
    var isPrimed: Bool {
        cond.lock(); defer { cond.unlock() }
        return ready[0] != nil && ready[1] != nil
    }

    /// The newest finished frame at or before index k (so a late frame shows the previous one rather than nothing), and tells the workers where we are.
    func frame(atIndex k: Int) -> (index: Int, frame: FrameData)? {
        cond.lock(); defer { cond.unlock() }
        consumerIndex = max(consumerIndex, k)
        cond.broadcast()
        var j = k
        while j >= max(0, k - 6) { if let f = ready[j] { return (j, f) }; j -= 1 }
        return nil
    }
}
