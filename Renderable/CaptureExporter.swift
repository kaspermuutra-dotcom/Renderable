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
        let manifest: [String: Any] = [
            "scan_name":            "Room Capture",
            "created_at":           ISO8601DateFormatter().string(from: record.createdAt),
            "app_version":          appVersion,
            "viewer_version":       viewerVersion,
            "device":               record.device,
            "frame_count":          record.frameCount,
            "starting_frame_index": 0,
            "thumbnail_filename":   thumbnailFilename,
            "frames":               frameObjects,
            "listing":              listing
        ]

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
