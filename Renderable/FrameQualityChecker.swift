import UIKit

// MARK: - FrameQuality result (Phase 19)

struct FrameQuality: Codable {
    /// 0–1. Higher = sharper. Derived from luminance variance on a 40×40 thumb.
    let blurScore: Float
    /// 0–1. Higher = better exposed. Falls off toward 0 for very dark or very bright frames.
    let exposureScore: Float
    /// 0–1. Weighted combination: 0.5 × blur + 0.5 × exposure.
    let qualityScore: Float
    /// true when qualityScore is below discardThreshold. Frame is flagged, not deleted.
    let discarded: Bool
}

// MARK: - Checker

struct FrameQualityChecker {

    // ── Tunable thresholds ────────────────────────────────────────────────────

    /// Luminance variance at or above this value maps to blurScore = 1.0.
    /// Typical sharp indoor scene: 0.02–0.08. Blurry: 0.002–0.01.
    static let blurVarianceNorm: Float = 0.04

    /// Brightness below this ramps exposureScore down toward 0 (too dark).
    static let exposureDarkEdge: Float = 0.15

    /// Brightness above this ramps exposureScore down toward 0 (too bright).
    static let exposureBrightEdge: Float = 0.85

    /// Frames with qualityScore < this are flagged discarded = true.
    static let discardThreshold: Float = 0.35

    // ── Public API ─────────────────────────────────────────────────────────────

    /// Full Phase 19 analysis. Returns blur, exposure, quality score and discard flag.
    static func analyze(_ image: UIImage) -> FrameQuality {
        guard let (brightness, variance) = samplePixels(image) else {
            return FrameQuality(blurScore: 1, exposureScore: 1, qualityScore: 1, discarded: false)
        }

        let blurScore     = Float(min(1.0, variance / Double(blurVarianceNorm)))
        let exposureScore = computeExposureScore(brightness: Float(brightness))
        let qualityScore  = 0.5 * blurScore + 0.5 * exposureScore
        let discarded     = qualityScore < discardThreshold

        return FrameQuality(
            blurScore:     blurScore,
            exposureScore: exposureScore,
            qualityScore:  qualityScore,
            discarded:     discarded
        )
    }

    // ── Pixel sampling ────────────────────────────────────────────────────────

    /// Returns (averageBrightness, luminanceVariance) from a 40×40 thumbnail.
    /// Variance is computed as E[X²] − E[X]² in a single pass.
    private static func samplePixels(_ image: UIImage) -> (brightness: Double, variance: Double)? {
        let thumbSize = CGSize(width: 40, height: 40)
        let renderer  = UIGraphicsImageRenderer(size: thumbSize)
        let thumb     = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: thumbSize)) }

        guard let data  = thumb.cgImage?.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }

        let length = CFDataGetLength(data)
        var sum:   Double = 0
        var sumSq: Double = 0
        var count: Double = 0

        var i = 0
        while i < length - 3 {
            let r   = Double(bytes[i])     / 255
            let g   = Double(bytes[i + 1]) / 255
            let b   = Double(bytes[i + 2]) / 255
            let lum = 0.299 * r + 0.587 * g + 0.114 * b
            sum   += lum
            sumSq += lum * lum
            count += 1
            i += 4
        }

        guard count > 0 else { return nil }
        let mean     = sum / count
        let variance = (sumSq / count) - (mean * mean)
        return (mean, variance)
    }

    // ── Exposure scoring ──────────────────────────────────────────────────────

    /// Produces 1.0 in the well-exposed range [exposureDarkEdge … exposureBrightEdge],
    /// tapering linearly to 0 outside that range.
    private static func computeExposureScore(brightness: Float) -> Float {
        let low  = min(1.0, brightness / exposureDarkEdge)
        let high = min(1.0, (1.0 - brightness) / (1.0 - exposureBrightEdge))
        return min(low, high)
    }
}
