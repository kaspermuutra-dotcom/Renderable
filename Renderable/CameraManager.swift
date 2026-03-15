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

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
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
