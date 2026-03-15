import SwiftUI
import Combine

struct WalkthroughView: View {
    let images: [UIImage]
    let startIndex: Int

    @State private var current: Int = 0
    @State private var isPlaying: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    /// Downscaled copies prepared once in onAppear — not recomputed on every body render.
    @State private var displayImages: [UIImage] = []

    @Environment(\.dismiss) var dismiss

    private let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if displayImages.isEmpty {
                // Guard: images not yet prepared or session has no frames.
                ProgressView()
                    .tint(.white)
            } else {
                // Main frame viewer
                GeometryReader { geo in
                    ZStack {
                        if current > 0 {
                            Image(uiImage: displayImages[current - 1])
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .offset(x: -geo.size.width + dragOffset)
                                .opacity(0.6)
                        }

                        Image(uiImage: displayImages[current])
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .scaleEffect(scale)
                            .offset(x: dragOffset)
                            .animation(.interactiveSpring(response: 0.3), value: dragOffset)

                        if current < displayImages.count - 1 {
                            Image(uiImage: displayImages[current + 1])
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .offset(x: geo.size.width + dragOffset)
                                .opacity(0.6)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isPlaying = false
                                dragOffset = value.translation.width
                                let progress = abs(value.translation.width) / geo.size.width
                                scale = 1.0 - (progress * 0.04)
                            }
                            .onEnded { value in
                                let threshold = geo.size.width * 0.25
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if value.translation.width < -threshold, current < displayImages.count - 1 {
                                        current += 1
                                    } else if value.translation.width > threshold, current > 0 {
                                        current -= 1
                                    }
                                    dragOffset = 0
                                    scale = 1.0
                                }
                            }
                    )
                }
                .ignoresSafeArea()

                // Gradient overlays
                VStack {
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 140)
                    .ignoresSafeArea()

                    Spacer()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 180)
                    .ignoresSafeArea()
                }

                // Top bar
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                                .padding()
                        }
                        Spacer()
                        Text("Frame \(current + 1) of \(displayImages.count)")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding()
                    }
                    Spacer()
                }

                // Bottom controls
                VStack {
                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(0..<displayImages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == current ? Color.white : Color.white.opacity(0.3))
                                .frame(width: i == current ? 20 : 6, height: 6)
                                .animation(.spring(response: 0.3), value: current)
                        }
                    }
                    .padding(.bottom, 16)

                    HStack(spacing: 48) {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if current > 0 { current -= 1 }
                            }
                        }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(current > 0 ? .white : .white.opacity(0.2))
                        }
                        .disabled(current == 0)

                        Button(action: { isPlaying.toggle() }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 52))
                                .foregroundColor(.white)
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if current < displayImages.count - 1 { current += 1 }
                            }
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(current < displayImages.count - 1 ? .white : .white.opacity(0.2))
                        }
                        .disabled(current == displayImages.count - 1)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            current = max(0, min(startIndex, images.count - 1))
            // Downscale all frames once here. As a @State var this result is
            // cached for the lifetime of the view and not recomputed per render.
            displayImages = images.map { downscale($0, to: CGSize(width: 1080, height: 1920)) }
        }
        .onReceive(timer) { _ in
            guard isPlaying, !displayImages.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                if current < displayImages.count - 1 {
                    current += 1
                } else {
                    isPlaying = false
                }
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Helpers

    private func downscale(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        guard ratio < 1.0 else { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
