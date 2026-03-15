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
}
