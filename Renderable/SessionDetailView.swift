import SwiftUI

struct SessionDetailView: View {
    let record: CaptureSessionRecord
    @State private var showWalkthrough = false
    @State private var walkthroughStart = 0

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    /// Loaded once in onAppear to avoid synchronous disk I/O on every body evaluation.
    @State private var images: [UIImage] = []

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var formattedDate: String {
        SessionDetailView.dateFormatter.string(from: record.createdAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Info bar
            HStack(spacing: 16) {
                Label("\(record.frameCount) frames", systemImage: "photo.stack")
                Spacer()
                Label(formattedDate, systemImage: "calendar")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Thumbnail grid — tap to open at that frame
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipped()
                            .cornerRadius(6)
                            .overlay(
                                Text("\(index + 1)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(.black.opacity(0.4))
                                    .cornerRadius(4)
                                    .padding(4),
                                alignment: .bottomLeading
                            )
                            .onTapGesture {
                                walkthroughStart = index
                                showWalkthrough = true
                            }
                    }
                }
                .padding(8)
            }

            Divider()

            // Start walkthrough button
            Button(action: {
                walkthroughStart = 0
                showWalkthrough = true
            }) {
                Label("Start Walkthrough", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Room Capture")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if images.isEmpty {
                images = record.imagePaths.compactMap { UIImage(contentsOfFile: $0) }
            }
        }
        .fullScreenCover(isPresented: $showWalkthrough) {
            WalkthroughView(images: images, startIndex: walkthroughStart)
        }
    }
}
