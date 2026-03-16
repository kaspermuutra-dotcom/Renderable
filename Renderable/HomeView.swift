import SwiftUI

struct HomeView: View {
    @State private var sessions: [CaptureSessionRecord] = []
    @State private var showInstructions = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if sessions.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Text("No captures yet")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Tap Start Capture to scan your first room.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(sessions) { record in
                                NavigationLink(destination: SessionDetailView(record: record)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Room Capture")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("\(record.frameCount) frames · \(HomeView.dateFormatter.string(from: record.createdAt))")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color.white.opacity(0.05))
                            }
                            .onDelete(perform: deleteSessions)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }

                    NavigationLink(destination: CaptureModeView()) {
                        Text("Start Capture")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(14)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 0) {
                        Text("Render")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text("able")
                            .font(.headline.bold())
                            .foregroundColor(.green)
                    }
                }
                // Scanning guidance — always accessible after onboarding is complete.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInstructions = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .sheet(isPresented: $showInstructions) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    InstructionsPage(
                        onComplete: { showInstructions = false },
                        buttonLabel: "Got it"
                    )
                }
                .preferredColorScheme(.dark)
            }
            .onAppear { sessions = LocalStorageManager.loadAllSessions() }
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        offsets.forEach { LocalStorageManager.delete(sessions[$0]) }
        sessions.remove(atOffsets: offsets)
    }
}
