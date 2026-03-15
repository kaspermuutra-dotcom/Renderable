import Foundation
import UIKit

struct LocalStorageManager {

    // MARK: - Save

    static func save(_ session: CaptureSession) -> CaptureSessionRecord? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }

        let sessionFolder = docs
            .appendingPathComponent("sessions")
            .appendingPathComponent(session.sessionID.uuidString)

        try? fm.createDirectory(at: sessionFolder, withIntermediateDirectories: true)

        var imagePaths: [String] = []

        for frame in session.frames {
            if let data = frame.image.jpegData(compressionQuality: 0.85) {
                let path = sessionFolder.appendingPathComponent("frame_\(frame.index).jpg")
                try? data.write(to: path)
                imagePaths.append(path.path)
            }
        }

        // map (not compactMap) to preserve index alignment: a nil entry at position i
        // means that frame had no data, without shifting any later frame's index.
        let qualities: [FrameQuality?] = session.frames.map { $0.quality }
        let hasAnyQuality = qualities.contains { $0 != nil }

        // Sprint B: same pattern for headings.
        let headings: [Double?] = session.frames.map { $0.heading }
        let hasAnyHeading = headings.contains { $0 != nil }

        let record = CaptureSessionRecord(
            id: session.sessionID,
            createdAt: Date(),
            frameCount: session.frameCount,
            imagePaths: imagePaths,
            device: UIDevice.current.model,
            frameQualities: hasAnyQuality ? qualities : nil,
            frameHeadings: hasAnyHeading ? headings : nil
        )

        if let json = try? JSONEncoder().encode(record) {
            let metaPath = sessionFolder.appendingPathComponent("metadata.json")
            try? json.write(to: metaPath)
        }

        print("✅ Session saved: \(sessionFolder.path)")
        return record
    }

    // MARK: - Load All

    static func loadAllSessions() -> [CaptureSessionRecord] {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }

        let sessionsRoot = docs.appendingPathComponent("sessions")
        guard let folders = try? fm.contentsOfDirectory(at: sessionsRoot, includingPropertiesForKeys: nil) else { return [] }

        return folders.compactMap { folder in
            let metaPath = folder.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metaPath),
                  let record = try? JSONDecoder().decode(CaptureSessionRecord.self, from: data)
            else { return nil }
            return record
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Delete

    static func delete(_ record: CaptureSessionRecord) {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let folder = docs.appendingPathComponent("sessions").appendingPathComponent(record.id.uuidString)
        try? fm.removeItem(at: folder)
    }
}
