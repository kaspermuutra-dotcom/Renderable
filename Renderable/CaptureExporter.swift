import Foundation
import UIKit

struct CaptureExporter {

    enum ExportError: Error {
        case sessionFolderNotFound
        case zipFailed
    }

    static let appVersion    = "1.0"
    static let viewerVersion = "1.0"

    static func export(record: CaptureSessionRecord) throws -> URL {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExportError.sessionFolderNotFound
        }

        let sessionFolder = docs
            .appendingPathComponent("sessions")
            .appendingPathComponent(record.id.uuidString)

        guard fm.fileExists(atPath: sessionFolder.path) else {
            throw ExportError.sessionFolderNotFound
        }

        // ── Thumbnail ─────────────────────────────────────────────────────────
        let thumbnailFilename = "thumbnail.jpg"
        let middleIndex = max(0, record.frameCount / 2)
        let middleFramePath = sessionFolder.appendingPathComponent("frame_\(middleIndex).jpg")

        if let sourceImage = UIImage(contentsOfFile: middleFramePath.path),
           let thumbData = generateThumbnail(from: sourceImage) {
            let thumbPath = sessionFolder.appendingPathComponent(thumbnailFilename)
            try? thumbData.write(to: thumbPath)
        }

        // ── Stage 4A: pre-compute per-frame delta yaw ────────────────────────
        // delta_yaw[i] = wrap-corrected angular distance between frame i-1 and frame i.
        // delta_yaw[0] is always nil (no predecessor frame).
        // Wrap correction mirrors MotionManager: yaw ranges −180°→+180°, can cross boundary.
        var deltaYaws: [Double?] = Array(repeating: nil, count: record.frameCount)
        if let yaws = record.frameYaws {
            for i in 1..<record.frameCount {
                if i < yaws.count,
                   let curr = yaws[i],
                   let prev = (i - 1 < yaws.count ? yaws[i - 1] : nil) {
                    let raw = abs(curr - prev)
                    deltaYaws[i] = min(raw, 360 - raw)
                }
            }
        }

        // ── Stage 4A: summary fields — computed only when source data is present ─
        let totalRotation: Double? = {
            guard record.frameYaws != nil else { return nil }
            let sum = deltaYaws.compactMap { $0 }.reduce(0, +)
            return sum > 0 ? sum : nil
        }()

        let scanDuration: Double? = {
            guard let ts = record.frameTimestamps, ts.count >= 2 else { return nil }
            return ts[ts.count - 1].timeIntervalSince(ts[0])
        }()

        let pitchRange: Double? = {
            guard let pitches = record.framePitches else { return nil }
            let valid = pitches.compactMap { $0 }
            guard valid.count >= 2, let lo = valid.min(), let hi = valid.max() else { return nil }
            return hi - lo
        }()

        // ISO8601 formatter reused across all per-frame timestamp strings.
        let iso = ISO8601DateFormatter()

        // ── Frame objects with nav graph + Phase 19 quality metadata ─────────
        let frameObjects: [[String: Any]] = (0..<record.frameCount).map { i in
            var neighbors: [String: Int] = [:]
            if i > 0                     { neighbors["back"]    = i - 1 }
            if i < record.frameCount - 1 { neighbors["forward"] = i + 1 }

            var obj: [String: Any] = [
                "index":     i,
                "filename":  "frame_\(i).jpg",
                "order":     i,
                "neighbors": neighbors
            ]

            // Embed quality scores when available (Phase 19).
            // Double optional-bind: outer nil = no quality array; inner nil = this frame lacked quality data.
            if let qualities = record.frameQualities, i < qualities.count, let q = qualities[i] {
                obj["blur_score"]     = Double(q.blurScore)
                obj["exposure_score"] = Double(q.exposureScore)
                obj["quality_score"]  = Double(q.qualityScore)
                obj["discarded"]      = q.discarded
            }

            // Embed compass heading when available (Sprint B).
            // Same double optional-bind: outer nil = pre-Sprint B session; inner nil = magnetometer was unreliable.
            if let headings = record.frameHeadings, i < headings.count, let h = headings[i] {
                obj["heading"] = h
            }

            // Stage 4A: yaw, pitch, timestamp, delta_yaw.
            // Double optional-bind for yaw/pitch (inner nil = motion unavailable for that frame).
            if let yaws = record.frameYaws, i < yaws.count, let y = yaws[i] {
                obj["yaw"] = y
            }
            if let pitches = record.framePitches, i < pitches.count, let p = pitches[i] {
                obj["pitch"] = p
            }
            if let timestamps = record.frameTimestamps, i < timestamps.count {
                obj["timestamp"] = iso.string(from: timestamps[i])
            }
            // delta_yaw: nil for frame 0 (no predecessor) and any frame whose yaw was unavailable.
            if let d = deltaYaws[i] {
                obj["delta_yaw"] = d
            }

            // Stage 4B: roll and capture-moment stability values.
            if let rolls = record.frameRolls, i < rolls.count, let r = rolls[i] {
                obj["roll"] = r
            }
            if let rates = record.frameCaptureRotationRates, i < rates.count, let rr = rates[i] {
                obj["rotation_rate"] = rr
            }
            if let accels = record.frameCaptureAccelerations, i < accels.count, let ac = accels[i] {
                obj["acceleration"] = ac
            }

            return obj
        }

        // ── Listing metadata placeholder ──────────────────────────────────────
        let listing: [String: Any] = [
            "listing_title":    "Room Capture",
            "listing_subtitle": "",
            "address":          "",
            "description":      "",
            "property_type":    "",
            "room_count":       0,
            "area_sqm":         0,
            "contact_name":     "",
            "contact_email":    "",
            "contact_phone":    "",
            "branding_name":    "Renderable"
        ]

        // ── Write manifest.json ───────────────────────────────────────────────
        // Stage 3A fields default to "standard" / 1.0 / frameCount for pre-mode sessions
        // so the server always receives a complete and consistent manifest.
        var manifest: [String: Any] = [
            "scan_name":            "Room Capture",
            "created_at":           ISO8601DateFormatter().string(from: record.createdAt),
            "app_version":          appVersion,
            "viewer_version":       viewerVersion,
            "device":               record.device,
            "frame_count":          record.frameCount,
            "capture_mode":         record.captureMode     ?? "standard",
            "lens_factor":          record.lensFactor      ?? 1.0,
            "target_frame_count":   record.targetFrameCount ?? record.frameCount,
            "starting_frame_index": 0,
            "thumbnail_filename":   thumbnailFilename,
            "frames":               frameObjects,
            "listing":              listing
        ]

        // Stage 4A: summary orientation fields — omitted entirely for pre-4A sessions
        // so the server can distinguish "not captured" from "zero".
        if let total = totalRotation    { manifest["total_rotation_degrees"] = total }
        if let dur   = scanDuration     { manifest["scan_duration_seconds"]  = dur   }
        if let pr    = pitchRange       { manifest["pitch_range_degrees"]    = pr    }

        if let manifestData = try? JSONSerialization.data(
            withJSONObject: manifest,
            options: .prettyPrinted
        ) {
            let manifestPath = sessionFolder.appendingPathComponent("manifest.json")
            try? manifestData.write(to: manifestPath)
            print("✅ manifest.json written — \(record.frameCount) frames")
        }

        // ── Legacy session.json ───────────────────────────────────────────────
        let legacyManifest = SessionExportManifest(
            sessionID:  record.id.uuidString,
            createdAt:  ISO8601DateFormatter().string(from: record.createdAt),
            frameCount: record.frameCount,
            frames:     (0..<record.frameCount).map { "frame_\($0).jpg" },
            device:     record.device
        )
        if let legacyData = try? JSONEncoder().encode(legacyManifest) {
            let legacyPath = sessionFolder.appendingPathComponent("session.json")
            try? legacyData.write(to: legacyPath)
        }

        // ── Zip ───────────────────────────────────────────────────────────────
        let zipURL = docs
            .appendingPathComponent("exports")
            .appendingPathComponent("\(record.id.uuidString).zip")

        try? fm.createDirectory(
            at: zipURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fm.removeItem(at: zipURL)

        guard zipFolder(at: sessionFolder, to: zipURL) else {
            throw ExportError.zipFailed
        }

        print("✅ Exported zip: \(zipURL.path)")
        return zipURL
    }

    private static func generateThumbnail(from image: UIImage) -> Data? {
        let targetSize = CGSize(width: 640, height: 480)
        let size = image.size
        let ratio = min(targetSize.width / size.width, targetSize.height / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return thumb.jpegData(compressionQuality: 0.72)
    }

    private static func zipFolder(at sourceURL: URL, to destinationURL: URL) -> Bool {
        var success = false
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(readingItemAt: sourceURL, options: .forUploading, error: &error) { zipURL in
            do {
                try FileManager.default.copyItem(at: zipURL, to: destinationURL)
                success = true
            } catch { print("❌ Zip copy failed: \(error)") }
        }
        if let error = error { print("❌ Coordinator error: \(error)") }
        return success
    }
}

struct SessionExportManifest: Codable {
    let sessionID:  String
    let createdAt:  String
    let frameCount: Int
    let frames:     [String]
    let device:     String
}
