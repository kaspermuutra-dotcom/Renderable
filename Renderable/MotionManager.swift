import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {

    private let motionManager = CMMotionManager()
    private var lastYaw: Double? = nil
    private var lastPitch: Double? = nil

    // Minimum rotation in degrees before next capture is allowed.
    private let minRotationDegrees: Double = 8.0

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
            // CMDeviceMotion.heading is -1 when the magnetometer reading is unreliable.
            let heading: Double? = motion.heading >= 0 ? motion.heading : nil

            if let lastYaw = self.lastYaw, let lastPitch = self.lastPitch {
                let rawDeltaYaw   = abs(yaw - lastYaw)
                let rawDeltaPitch = abs(pitch - lastPitch)
                // Wrap-corrected deltas: handles the 350°→10° boundary crossing
                // that the magnetic north reference frame can expose.
                let deltaYaw   = min(rawDeltaYaw,   360 - rawDeltaYaw)
                let deltaPitch = min(rawDeltaPitch, 360 - rawDeltaPitch)

                let moved     = deltaYaw > self.minRotationDegrees || deltaPitch > self.minRotationDegrees
                let remaining = Int(self.minRotationDegrees - max(deltaYaw, deltaPitch))
                let hint      = moved ? "" : "Rotate \(remaining)° before the next shot"

                DispatchQueue.main.async {
                    self.hasMovedEnough = moved
                    self.rotationHint   = hint
                    self.currentHeading = heading
                }
            } else {
                // First reading — always allow first capture.
                DispatchQueue.main.async {
                    self.hasMovedEnough = true
                    self.currentHeading = heading
                }
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// Call this after a frame is captured to reset the rotation baseline.
    /// Dispatched to motionQueue to keep lastYaw/lastPitch access on one thread.
    func resetBaseline() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionQueue.addOperation { [weak self] in
            guard let self,
                  let motion = self.motionManager.deviceMotion else { return }
            self.lastYaw   = motion.attitude.yaw   * 180 / .pi
            self.lastPitch = motion.attitude.pitch * 180 / .pi
            DispatchQueue.main.async { self.hasMovedEnough = false }
        }
    }
}
