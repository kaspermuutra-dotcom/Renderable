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
}
