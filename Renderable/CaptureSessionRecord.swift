import Foundation

struct CaptureSessionRecord: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let frameCount: Int
    let imagePaths: [String]
    let device: String
    /// Phase 19: per-frame quality scores in capture order, index-aligned with frames.
    /// Each element is optional so a single nil entry does not shift later indices.
    /// The outer optional is nil for records saved before Phase 19.
    let frameQualities: [FrameQuality?]?
    /// Sprint B: per-frame compass headings in capture order, index-aligned with frames.
    /// Each element is optional (nil = magnetometer was unreliable for that frame).
    /// The outer optional is nil for sessions saved before Sprint B.
    let frameHeadings: [Double?]?
    /// Stage 3A: capture mode used when this session was recorded ("standard" or "wide").
    /// nil for sessions saved before Stage 3A — treat as "standard" when reading.
    let captureMode: String?
    /// Stage 3A: decimal lens multiplier (1.0 or 0.5).
    /// nil for sessions saved before Stage 3A.
    let lensFactor: Double?
    /// Stage 3A: the target frame count for the selected mode (20 or 12).
    /// Distinct from frameCount, which is the actual number of frames captured.
    /// nil for sessions saved before Stage 3A.
    let targetFrameCount: Int?
    /// Stage 4A: raw attitude yaw per frame (degrees, −180→+180), index-aligned with frames.
    /// Each element is optional (nil = motion data unavailable for that frame).
    /// The outer optional is nil for sessions saved before Stage 4A.
    let frameYaws: [Double?]?
    /// Stage 4A: raw attitude pitch per frame (degrees, −90→+90), index-aligned with frames.
    /// Positive = camera tilting upward. nil elements indicate unavailable readings.
    /// The outer optional is nil for sessions saved before Stage 4A.
    let framePitches: [Double?]?
    /// Stage 4A: capture timestamp per frame, index-aligned with frames.
    /// Populated from CapturedFrame.timestamp at save time.
    /// The outer optional is nil for sessions saved before Stage 4A.
    let frameTimestamps: [Date]?
    /// Stage 4B: raw attitude roll per frame (degrees, −180→+180), index-aligned with frames.
    /// Near 0° = device held upright. nil elements indicate unavailable readings.
    /// The outer optional is nil for sessions saved before Stage 4B.
    let frameRolls: [Double?]?
    /// Stage 4B: magnitude of CMDeviceMotion.rotationRate at shutter time (rad/s), per frame.
    /// Measures angular velocity at the instant of capture. Lower = steadier shot.
    /// nil elements indicate motion data was unavailable. Outer nil = pre-Stage 4B session.
    let frameCaptureRotationRates: [Double?]?
    /// Stage 4B: magnitude of CMDeviceMotion.userAcceleration at shutter time (g), per frame.
    /// Measures hand shake at the instant of capture. Lower = steadier shot.
    /// nil elements indicate motion data was unavailable. Outer nil = pre-Stage 4B session.
    let frameCaptureAccelerations: [Double?]?
}
