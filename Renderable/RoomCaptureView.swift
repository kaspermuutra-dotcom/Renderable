import SwiftUI
import RoomPlan

struct RoomScannerView: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> RoomScannerViewController {
        let viewController = RoomScannerViewController()
        return viewController
    }

    func updateUIViewController(_ uiViewController: RoomScannerViewController,
                                context: Context) {}
}

class RoomScannerViewController: UIViewController {

    private var roomCaptureView: RoomPlan.RoomCaptureView!
    private var captureSession: RoomCaptureSession!

    override func viewDidLoad() {
        super.viewDidLoad()

        captureSession = RoomCaptureSession()
        roomCaptureView = RoomPlan.RoomCaptureView()
        roomCaptureView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(roomCaptureView)

        NSLayoutConstraint.activate([
            roomCaptureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roomCaptureView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roomCaptureView.topAnchor.constraint(equalTo: view.topAnchor),
            roomCaptureView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stop()
    }
}
