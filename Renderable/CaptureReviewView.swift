import SwiftUI

struct CaptureReviewView: View {
    @ObservedObject var captureSession: CaptureSession
    @StateObject private var uploader = UploadManager()

    @State private var saved = false
    @State private var isSaving = false
    @State private var isExporting = false
    @State private var savedRecord: CaptureSessionRecord? = nil
    @State private var showWalkthrough = false
    @State private var showShare = false
    @State private var exportError: String? = nil

    @Environment(\.dismiss) var dismiss

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        VStack(spacing: 0) {

            // Thumbnail grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(captureSession.frames) { frame in
                        Image(uiImage: frame.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110)
                            .clipped()
                            .cornerRadius(6)
                    }
                }
                .padding(8)
            }

            Divider()

            VStack(spacing: 12) {
                Text("\(captureSession.frameCount) frames captured")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let error = exportError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let error = uploader.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Save button
                if !saved {
                    if isSaving {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Saving...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        Button(action: saveSession) {
                            Text("Save & Finish")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }

                // Post-save buttons
                if saved {
                    Button(action: { showWalkthrough = true }) {
                        Label("Start Walkthrough", systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    if uploader.isUploading || isExporting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(isExporting ? "Preparing..." : "Uploading...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    } else if let result = uploader.result {
                        Button(action: { showShare = true }) {
                            Label("View Share Link", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .onAppear { showShare = true }
                        .sheet(isPresented: $showShare) {
                            ShareView(scanID: result.scan_id, viewerURL: result.viewer_url)
                        }

                    } else {
                        Button(action: uploadSession) {
                            Label("Upload Scan", systemImage: "icloud.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }

                    if let record = savedRecord {
                        NavigationLink(destination: SessionDetailView(record: record)) {
                            Label("View Session Detail", systemImage: "list.bullet.rectangle")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Review Capture")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showWalkthrough) {
            if let record = savedRecord {
                WalkthroughView(
                    images: record.imagePaths.compactMap { UIImage(contentsOfFile: $0) },
                    startIndex: 0
                )
            }
        }
    }

    // MARK: - Actions

    private func saveSession() {
        isSaving = true
        // JPEG encoding and file I/O run on a background thread.
        DispatchQueue.global(qos: .userInitiated).async {
            let record = LocalStorageManager.save(captureSession)
            DispatchQueue.main.async {
                isSaving = false
                if let record {
                    savedRecord = record
                    saved = true
                }
            }
        }
    }

    private func uploadSession() {
        guard let record = savedRecord else { return }
        exportError = nil
        isExporting = true
        // NSFileCoordinator zip runs on a background thread to avoid blocking the UI.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let zipURL = try CaptureExporter.export(record: record)
                DispatchQueue.main.async {
                    isExporting = false
                    uploader.upload(fileURL: zipURL)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    exportError = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
