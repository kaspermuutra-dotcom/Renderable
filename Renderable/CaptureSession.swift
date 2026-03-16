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
    /// Stage 4A: raw attitude yaw at capture time (degrees, −180→+180).
    /// nil when motion data was unavailable.
    let yaw: Double?
    /// Stage 4A: raw attitude pitch at capture time (degrees, −90→+90).
    /// Positive = camera tilting upward, negative = downward. nil when unavailable.
    let pitch: Double?
    /// Stage 4B: raw attitude roll at capture time (degrees, −180→+180).
    /// Near 0° = device held upright in portrait. Positive = clockwise lean. nil when unavailable.
    let roll: Double?
    /// Stage 4B: magnitude of CMDeviceMotion.rotationRate at shutter time (rad/s).
    /// Measures how fast the camera was rotating across all axes at the moment of capture.
    /// Lower = more stable. nil when device motion was unavailable.
    let captureRotationRate: Double?
    /// Stage 4B: magnitude of CMDeviceMotion.userAcceleration at shutter time (g units, gravity removed).
    /// Measures hand shake / vibration at the moment of capture. Lower = more stable.
    /// nil when device motion was unavailable.
    let captureAcceleration: Double?
}

class CaptureSession: ObservableObject {
    let sessionID  = UUID()
    let captureMode: CaptureMode
    let targetFrameCount: Int

    @Published var frames: [CapturedFrame] = []

    var frameCount: Int { frames.count }

    /// Default is .standard so any call site that doesn't supply a mode
    /// (e.g. previews, tests) continues to compile and behave as before.
    init(mode: CaptureMode = .standard) {
        self.captureMode     = mode
        self.targetFrameCount = mode.targetFrameCount
    }

    /// Phase 19: pass quality from FrameQualityChecker.analyze() — defaults to nil for backward compat.
    /// Sprint B: pass heading from MotionManager.currentHeading — defaults to nil for backward compat.
    /// Stage 4A: pass yaw/pitch from MotionManager.currentYaw/currentPitch — default nil for backward compat.
    /// Stage 4B: pass roll from MotionManager.currentRoll; pass captureRotationRate and
    ///           captureAcceleration from MotionManager.readCaptureStability() — all default nil.
    /// Must be called from the main thread. Appends synchronously so frameCount is
    /// correct immediately after the call — required for the review-screen trigger.
    func addFrame(
        _ image: UIImage,
        quality: FrameQuality? = nil,
        heading: Double? = nil,
        yaw: Double? = nil,
        pitch: Double? = nil,
        roll: Double? = nil,
        captureRotationRate: Double? = nil,
        captureAcceleration: Double? = nil
    ) {
        assert(Thread.isMainThread, "addFrame must be called on the main thread")
        let frame = CapturedFrame(
            image: image,
            timestamp: Date(),
            index: frames.count,
            quality: quality,
            heading: heading,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            captureRotationRate: captureRotationRate,
            captureAcceleration: captureAcceleration
        )
        frames.append(frame)
    }

    func reset() {
        DispatchQueue.main.async {
            self.frames = []
        }
    }
}
