import AVFoundation

/// All per-mode constants live here — frame counts, lens factors, device types,
/// and per-frame instruction copy. Everything downstream reads from this enum
/// so magic numbers stay in one place.
enum CaptureMode: String, CaseIterable {
    case standard
    case wide

    // MARK: - UI metadata

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .wide:     return "Wide"
        }
    }

    /// Short label shown on the mode card below the display name.
    var subtitle: String {
        switch self {
        case .standard: return "Best for most rooms — standard lens, 20 frames."
        case .wide:     return "Wider coverage — ultra-wide lens, 12 frames."
        }
    }

    /// Multiplier label shown in the mode selector badge (1x / 0.5x).
    var lensLabel: String {
        switch self {
        case .standard: return "1x"
        case .wide:     return "0.5x"
        }
    }

    // MARK: - Capture parameters

    /// Decimal lens multiplier written to the manifest.
    var lensFactor: Double {
        switch self {
        case .standard: return 1.0
        case .wide:     return 0.5
        }
    }

    /// Total frames required to complete a session in this mode.
    var targetFrameCount: Int {
        switch self {
        case .standard: return 20
        case .wide:     return 12
        }
    }

    // MARK: - Hardware

    /// Preferred AVFoundation device type for this mode.
    /// CameraManager falls back to wide-angle if this type is unavailable.
    var preferredDeviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .standard: return .builtInWideAngleCamera
        case .wide:     return .builtInUltraWideCamera
        }
    }

    /// True when the required rear camera hardware exists on this device.
    /// Wide mode is unavailable on iPhone SE and older models without ultra-wide.
    var isAvailable: Bool {
        AVCaptureDevice.default(preferredDeviceType, for: .video, position: .back) != nil
    }

    // MARK: - Per-frame instructions

    /// Guidance strings indexed by frame number (0 = before first capture).
    /// Array length always equals targetFrameCount.
    var instructions: [String] {
        switch self {
        case .standard: return buildInstructions(total: targetFrameCount, waypointInterval: 4)
        case .wide:     return buildInstructions(total: targetFrameCount, waypointInterval: 2)
        }
    }

    /// Builds a generic instruction list of the correct length.
    /// Every `waypointInterval` middle frames gets a spatial waypoint cue;
    /// remaining middle frames get the steady rotation cue.
    private func buildInstructions(total: Int, waypointInterval: Int) -> [String] {
        let waypoints = [
            "Face the right corner",
            "Face the back-right corner",
            "Face the back wall",
            "Face the back-left corner",
            "Face the left corner",
        ]

        var list: [String] = []
        var wpIndex = 0

        list.append("Face the starting wall — this is your reference point")

        for i in 1..<(total - 1) {
            if i % waypointInterval == 0, wpIndex < waypoints.count {
                list.append(waypoints[wpIndex])
                wpIndex += 1
            } else {
                list.append("Rotate right — keep the previous frame in view")
            }
        }

        list.append("Final frame — return to face the starting wall")
        return list
    }
}
