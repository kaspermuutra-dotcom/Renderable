import SwiftUI

struct HomeView: View {
    @State private var sessions: [CaptureSessionRecord] = []

    /// Static formatter — DateFormatter is expensive to allocate; one instance is shared.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No captures yet")
                            .font(.title3.bold())
                        Text("Tap Start Capture to scan your first room")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else {
                    List {
                        ForEach(sessions) { record in
                            NavigationLink(destination: SessionDetailView(record: record)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Room Capture")
                                        .font(.headline)
                                    Text("\(record.frameCount) frames · \(HomeView.dateFormatter.string(from: record.createdAt))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                }

                NavigationLink(destination: CaptureSessionView()) {
                    Label("Start Capture", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Renderable")
            .onAppear { sessions = LocalStorageManager.loadAllSessions() }
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        offsets.forEach { LocalStorageManager.delete(sessions[$0]) }
        sessions.remove(atOffsets: offsets)
    }
}
