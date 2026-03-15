import SwiftUI

struct CaptureSessionView: View {
    let mode: CaptureMode

    @StateObject private var camera: CameraManager
    @StateObject private var captureSession: CaptureSession
    @StateObject private var motion: MotionManager

    @State private var showReview = false
    @State private var flash = false
    @State private var warningMessage: String? = nil
    @State private var showWarning = false

    /// Default .standard so previews and any existing call site with no argument still compile.
    init(mode: CaptureMode = .standard) {
        self.mode = mode
        _camera         = StateObject(wrappedValue: CameraManager(mode: mode))
        _captureSession = StateObject(wrappedValue: CaptureSession(mode: mode))
        _motion         = StateObject(wrappedValue: MotionManager())
    }

    var currentInstruction: String {
        let i            = captureSession.frameCount
        let instructions = mode.instructions
        guard i < instructions.count else { return "All frames captured. Review below." }
        return instructions[i]
    }

    // Gate: cooldown + motion
    var captureDisabled: Bool {
        captureSession.frameCount >= captureSession.targetFrameCount
            || !camera.isReady
            || !motion.hasMovedEnough
    }

    var progress: CGFloat {
        guard captureSession.targetFrameCount > 0 else { return 0 }
        return CGFloat(captureSession.frameCount) / CGFloat(captureSession.targetFrameCount)
    }

    var body: some View {
        ZStack {
            // Camera feed
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // Flash
            if flash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Grid
            GridOverlay()
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top bar ──
                VStack(spacing: 4) {
                    Text(currentInstruction)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .animation(.easeInOut(duration: 0.3), value: currentInstruction)

                    // Overlap hint — show after first frame
                    if captureSession.frameCount > 0 {
                        Text("Keep 40% overlap with previous shot")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)

                Spacer()

                // ── Motion gate hint ──
                if !motion.hasMovedEnough && captureSession.frameCount > 0 {
                    Text(motion.rotationHint.isEmpty ? "Move the camera to continue" : motion.rotationHint)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .padding(.bottom, 8)
                }

                // ── Quality warning ──
                if showWarning, let warning = warningMessage {
                    Text(warning)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.orange.opacity(0.85))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .padding(.bottom, 8)
                }

                // ── Circular progress + capture button + compass ──
                // HStack layout: fixed-width left placeholder mirrors compass width
                // so the shutter ring stays horizontally centred on all screen sizes.
                HStack(alignment: .center, spacing: 0) {
                    Spacer().frame(width: 68) // mirrors compass (44) + trailing gap (24)

                    Spacer()

                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 4)
                            .frame(width: 92, height: 92)

                        // Capture arc segment ticks — one per target frame.
                        // Each tick fills green as that frame is captured,
                        // giving a clear "completing a circle" visual.
                        ForEach(0..<captureSession.targetFrameCount, id: \.self) { i in
                            let angle = Double(i) / Double(captureSession.targetFrameCount) * 360.0 - 90.0
                            Rectangle()
                                .fill(i < captureSession.frameCount
                                      ? Color.green
                                      : Color.white.opacity(0.2))
                                .frame(width: 2, height: 8)
                                .offset(y: -54)
                                .rotationEffect(.degrees(angle))
                        }

                        // Progress ring fill
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 92, height: 92)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.4), value: progress)

                        // Cooldown arc
                        if !camera.isReady {
                            Circle()
                                .trim(from: 0, to: 0.75)
                                .stroke(Color.white.opacity(0.5), lineWidth: 3)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1.2), value: camera.isReady)
                        }

                        // Shutter button
                        Circle()
                            .fill(captureDisabled ? Color.white.opacity(0.35) : Color.white)
                            .frame(width: 68, height: 68)
                            .scaleEffect(camera.isReady && motion.hasMovedEnough ? 1.0 : 0.88)
                            .animation(.spring(response: 0.25), value: captureDisabled)

                        // Frame count in centre
                        Text("\(captureSession.frameCount)/\(captureSession.targetFrameCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(captureDisabled ? Color.black.opacity(0.3) : Color.black.opacity(0.6))
                    }
                    .onTapGesture {
                        if !captureDisabled { takePhoto() }
                    }

                    Spacer()

                    // Compass HUD — to the right of the shutter
                    CompassHUDView(heading: motion.currentHeading)
                        .frame(width: 44)
                        .padding(.trailing, 24)
                }
                .padding(.bottom, 40)
                .padding(.top, 8)
            }
        }
        .onAppear {
            camera.start()
            motion.start()

            camera.onPhotoCaptured = { image in
                // Phase 19: full quality analysis (blur + exposure + score + discard flag)
                let quality = FrameQualityChecker.analyze(image)

                if quality.discarded {
                    if quality.exposureScore < quality.blurScore {
                        showCaptureWarning("Poor lighting — adjust before the next shot")
                    } else {
                        showCaptureWarning("Frame may be blurry — hold the camera steady")
                    }
                }

                // addFrame is now synchronous — frameCount is correct immediately after.
                captureSession.addFrame(image, quality: quality, heading: motion.currentHeading)
                motion.resetBaseline()
                triggerFlash()
                // Review transition is handled by onChange(of: captureSession.frameCount) below.
            }
        }
        .onDisappear {
            camera.stop()
            motion.stop()
        }
        .navigationDestination(isPresented: $showReview) {
            CaptureReviewView(captureSession: captureSession)
        }
        // Belt-and-suspenders: fires reactively when frames.count changes,
        // regardless of async dispatch ordering in the capture callback.
        .onChange(of: captureSession.frameCount) { count in
            guard count >= captureSession.targetFrameCount, !showReview else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showReview = true
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func takePhoto() {
        camera.capturePhoto()
    }

    private func triggerFlash() {
        flash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { flash = false }
    }

    private func showCaptureWarning(_ message: String) {
        warningMessage = message
        withAnimation { showWarning = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showWarning = false }
        }
    }
}

// MARK: - Grid overlay

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        }
    }
}

// MARK: - Compass HUD

/// Minimal compass indicator that shows cardinal direction and numeric heading.
/// Reads from MotionManager.currentHeading (CMDeviceMotion, magnetic north reference).
/// Displays "—" when heading is unavailable (magnetometer unreliable or uncalibrated).
struct CompassHUDView: View {
    let heading: Double?

    private var cardinal: String {
        guard let h = heading else { return "—" }
        switch h {
        case 337.5...360, 0..<22.5:  return "N"
        case 22.5..<67.5:            return "NE"
        case 67.5..<112.5:           return "E"
        case 112.5..<157.5:          return "SE"
        case 157.5..<202.5:          return "S"
        case 202.5..<247.5:          return "SW"
        case 247.5..<292.5:          return "W"
        case 292.5..<337.5:          return "NW"
        default:                      return "—"
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(cardinal)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            Text(heading.map { "\(Int($0))°" } ?? "—")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 44)
    }
}
