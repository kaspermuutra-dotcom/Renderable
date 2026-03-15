import SwiftUI

struct ShareView: View {
    let scanID: String
    let viewerURL: String

    @State private var copied = false
    @Environment(\.dismiss) var dismiss

    /// Derived from UploadManager.baseURL — single source of truth for the server address.
    var fullURL: String { UploadManager.baseURL + viewerURL }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Upload Complete")
                    .font(.title2.bold())
                Text("Your room capture is ready to share")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Scan ID
            VStack(spacing: 4) {
                Text("Scan ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(scanID)
                    .font(.caption.monospaced())
                    .foregroundColor(.primary)
            }

            // Viewer URL box
            VStack(spacing: 12) {
                Text(fullURL)
                    .font(.footnote.monospaced())
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                // Copy button
                Button(action: copyLink) {
                    Label(copied ? "Copied!" : "Copy Link", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(copied ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .animation(.easeInOut(duration: 0.2), value: copied)
                }

                // System share sheet
                ShareLink(item: URL(string: fullURL) ?? URL(string: "https://renderable.app")!) {
                    Label("Share via...", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .navigationTitle("Share Capture")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func copyLink() {
        UIPasteboard.general.string = fullURL
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }
}//
//  ShareView.swift
//  Renderable
//
//  Created by Kasper Muutra on 12.03.2026.
//

