import Foundation
import AVFoundation
import UIKit
import Combine

final class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    var onPhotoCaptured: ((UIImage) -> Void)?

    // Cooldown — prevents captures less than 1.2s apart
    @Published var isReady: Bool = true
    private let cooldownDuration: TimeInterval = 1.2
    private var cooldownTimer: Timer?

    /// Selects the preferred rear camera for the given CaptureMode.
    /// Falls back to the built-in wide-angle camera if the preferred type
    /// (e.g. ultra-wide) is unavailable on this device.
    init(mode: CaptureMode = .standard) {
        super.init()
        setupSession(preferring: mode.preferredDeviceType)
    }

    private func setupSession(preferring preferredType: AVCaptureDevice.DeviceType) {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Try the preferred lens first; fall back to wide-angle with a console note.
        let device: AVCaptureDevice? =
            AVCaptureDevice.default(preferredType, for: .video, position: .back)
            ?? {
                if preferredType != .builtInWideAngleCamera {
                    print("⚠️ CameraManager: \(preferredType) unavailable — falling back to wide-angle")
                }
                return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            }()

        guard
            let device,
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(photoOutput)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
        cooldownTimer?.invalidate()
    }

    func capturePhoto() {
        guard isReady else { return }

        // Start cooldown
        isReady = false
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: cooldownDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isReady = true
            }
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }

        DispatchQueue.main.async {
            self.onPhotoCaptured?(image)
        }
    }
}
