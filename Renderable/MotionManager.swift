import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {

    private let motionManager = CMMotionManager()
    private var lastYaw: Double? = nil
    private var lastPitch: Double? = nil

    // Minimum rotation in degrees before next capture is allowed.
    // 9° gives enough angular separation for smooth rendering while
    // still allowing a comfortable capture pace.
    private let minRotationDegrees: Double = 9.0

    // Serial queue for all motion processing — keeps lastYaw/lastPitch access
    // off the main thread and eliminates data races with resetBaseline().
    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.renderable.motion"
        q.maxConcurrentOperationCount = 1
        return q
    }()

    @Published var hasMovedEnough: Bool = true
    @Published var rotationHint: String = ""
    /// Compass heading in degrees relative to magnetic north (0–360).
    /// nil when the magnetometer cannot provide a reliable reading (CMDeviceMotion returns -1).
    @Published var currentHeading: Double? = nil
    /// Raw yaw from CMDeviceMotion.attitude at the latest motion callback (degrees, −180→+180).
    /// Stamped on the main thread at capture time for use as per-frame orientation metadata.
    @Published var currentYaw: Double? = nil
    /// Raw pitch from CMDeviceMotion.attitude at the latest motion callback (degrees, −90→+90).
    /// Positive = nose up, negative = nose down.
    @Published var currentPitch: Double? = nil
    /// Raw roll from CMDeviceMotion.attitude at the latest motion callback (degrees, −180→+180).
    /// Near 0° = device held upright in portrait. Positive = clockwise lean.
    @Published var currentRoll: Double? = nil

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            hasMovedEnough = true
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.05
        // xMagneticNorthZVertical: X axis points to magnetic north, Z vertical.
        // CMDeviceMotion.heading then returns a real compass bearing (0–360°)
        // with no CLLocationManager or user permission required.
        motionManager.startDeviceMotionUpdates(
            using: .xMagneticNorthZVertical,
            to: motionQueue
        ) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let yaw   = motion.attitude.yaw   * 180 / .pi
            let pitch = motion.attitude.pitch * 180 / .pi
            let roll  = motion.attitude.roll  * 180 / .pi
            // CMDeviceMotion.heading is -1 when the magnetometer reading is unreliable.
            let heading: Double? = motion.heading >= 0 ? motion.heading : nil

            if let lastYaw = self.lastYaw, let lastPitch = self.lastPitch {
                let rawDeltaYaw = abs(yaw - lastYaw)
                // Wrap-correct yaw only: CMDeviceMotion.attitude.yaw ranges −180°→+180°
                // and can cross the ±180° boundary mid-pan.
                let deltaYaw = min(rawDeltaYaw, 360 - rawDeltaYaw)
                // Pitch ranges −90°→+90° and never wraps — plain absolute delta is correct.
                let deltaPitch = abs(pitch - lastPitch)

                let moved     = deltaYaw > self.minRotationDegrees || deltaPitch > self.minRotationDegrees
                let remaining = Int(self.minRotationDegrees - max(deltaYaw, deltaPitch))
                // Two-tier hint — no degree numbers shown to the user.
                // Half-threshold split: first half needs a meaningful rotation cue,
                // second half (nearly there) gets a lighter nudge.
                let hint: String
                if moved {
                    hint = ""
                } else if remaining > Int(self.minRotationDegrees) / 2 {
                    hint = "Rotate right — keep the previous frame in view"
                } else {
                    hint = "Almost there — a little more"
                }

                DispatchQueue.main.async {
                    self.hasMovedEnough = moved
                    self.rotationHint   = hint
                    self.currentHeading = heading
                    self.currentYaw     = yaw
                    self.currentPitch   = pitch
                    self.currentRoll    = roll
                }
            } else {
                // First reading — always allow first capture.
                DispatchQueue.main.async {
                    self.hasMovedEnough = true
                    self.currentHeading = heading
                    self.currentYaw     = yaw
                    self.currentPitch   = pitch
                    self.currentRoll    = roll
                }
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// Call this after a frame is captured to reset the rotation baseline.
    /// Reads deviceMotion immediately at call time — not inside the queued operation —
    /// so the baseline is stamped at the actual capture moment, not after pending
    /// motion callbacks have already advanced the position.
    func resetBaseline() {
        guard motionManager.isDeviceMotionAvailable,
              let snapshot = motionManager.deviceMotion else { return }
        // Capture values as local constants on the calling thread (main).
        // CMMotionManager.deviceMotion is thread-safe for reading.
        let yaw   = snapshot.attitude.yaw   * 180 / .pi
        let pitch = snapshot.attitude.pitch * 180 / .pi
        motionQueue.addOperation { [weak self] in
            guard let self else { return }
            self.lastYaw   = yaw
            self.lastPitch = pitch
            DispatchQueue.main.async { self.hasMovedEnough = false }
        }
    }

    /// Reads rotation rate and user acceleration magnitudes synchronously at call time.
    /// Must be called on the main thread immediately before addFrame() so the snapshot
    /// matches the actual shutter moment rather than a queued callback's position.
    /// Returns nil for each value when device motion is unavailable.
    ///
    /// rotationRate — magnitude of CMDeviceMotion.rotationRate in rad/s.
    ///   Measures angular velocity across all axes. High = camera was rotating at capture.
    /// acceleration — magnitude of CMDeviceMotion.userAcceleration in g units (gravity removed).
    ///   Measures linear hand shake at capture. High = physical jitter at shutter time.
    func readCaptureStability() -> (rotationRate: Double?, acceleration: Double?) {
        guard motionManager.isDeviceMotionAvailable,
              let snapshot = motionManager.deviceMotion else { return (nil, nil) }
        let r  = snapshot.rotationRate
        let rm = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)
        let a  = snapshot.userAcceleration
        let am = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
        return (rm, am)
    }
}
