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

        // Stage 4A: yaw and pitch follow the same map / hasAny pattern.
        let yaws: [Double?] = session.frames.map { $0.yaw }
        let hasAnyYaw = yaws.contains { $0 != nil }

        let pitches: [Double?] = session.frames.map { $0.pitch }
        let hasAnyPitch = pitches.contains { $0 != nil }

        // Stage 4A: timestamps are always non-optional in CapturedFrame — capture all of them.
        // Stored as the outer optional so pre-4A sessions decode cleanly (missing key → nil).
        let timestamps: [Date] = session.frames.map { $0.timestamp }

        // Stage 4B: roll, rotation rate, and acceleration follow the same map / hasAny pattern.
        let rolls: [Double?] = session.frames.map { $0.roll }
        let hasAnyRoll = rolls.contains { $0 != nil }

        let rotationRates: [Double?] = session.frames.map { $0.captureRotationRate }
        let hasAnyRotationRate = rotationRates.contains { $0 != nil }

        let accelerations: [Double?] = session.frames.map { $0.captureAcceleration }
        let hasAnyAcceleration = accelerations.contains { $0 != nil }

        let record = CaptureSessionRecord(
            id: session.sessionID,
            createdAt: Date(),
            frameCount: session.frameCount,
            imagePaths: imagePaths,
            device: UIDevice.current.model,
            frameQualities: hasAnyQuality ? qualities : nil,
            frameHeadings: hasAnyHeading ? headings : nil,
            // Stage 3A: persist the capture mode so the record is self-describing.
            captureMode:      session.captureMode.rawValue,
            lensFactor:       session.captureMode.lensFactor,
            targetFrameCount: session.captureMode.targetFrameCount,
            // Stage 4A: orientation and timing arrays.
            frameYaws:        hasAnyYaw   ? yaws    : nil,
            framePitches:     hasAnyPitch ? pitches : nil,
            frameTimestamps:  timestamps.isEmpty ? nil : timestamps,
            // Stage 4B: roll and capture-moment stability arrays.
            frameRolls:                 hasAnyRoll          ? rolls         : nil,
            frameCaptureRotationRates:  hasAnyRotationRate  ? rotationRates : nil,
            frameCaptureAccelerations:  hasAnyAcceleration  ? accelerations : nil
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
