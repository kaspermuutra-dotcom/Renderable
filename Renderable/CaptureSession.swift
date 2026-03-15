import Foundation
import UIKit
import Combine

struct CapturedFrame: Identifiable {
    let id = UUID()
    let image: UIImage
    let timestamp: Date
    let index: Int
    /// Phase 19: quality analysis result. nil only if captured before analysis ran.
    let quality: FrameQuality?
    /// Sprint B: compass heading at capture time, degrees from magnetic north (0–360).
    /// nil when the magnetometer is unavailable or unreliable.
    let heading: Double?
}

class CaptureSession: ObservableObject {
    let sessionID = UUID()
    @Published var frames: [CapturedFrame] = []

    var frameCount: Int { frames.count }
    let targetFrameCount = 10

    /// Phase 19: pass quality from FrameQualityChecker.analyze() — defaults to nil for backward compat.
    /// Sprint B: pass heading from MotionManager.currentHeading — defaults to nil for backward compat.
    /// Must be called from the main thread. Appends synchronously so frameCount is
    /// correct immediately after the call — required for the review-screen trigger.
    func addFrame(_ image: UIImage, quality: FrameQuality? = nil, heading: Double? = nil) {
        assert(Thread.isMainThread, "addFrame must be called on the main thread")
        let frame = CapturedFrame(
            image: image,
            timestamp: Date(),
            index: frames.count,
            quality: quality,
            heading: heading
        )
        frames.append(frame)
    }

    func reset() {
        DispatchQueue.main.async {
            self.frames = []
        }
    }
}
