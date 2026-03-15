import SwiftUI
import AVFoundation

/// Inserted between HomeView and CaptureSessionView.
/// Lets the user choose Standard (1x, 20 frames) or Wide (0.5x, 12 frames)
/// before the camera session is created. Wide is disabled when the device
/// has no ultra-wide rear camera.
struct CaptureModeView: View {
    @State private var selectedMode: CaptureMode = .standard

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──
                VStack(spacing: 8) {
                    Text("Select Capture Mode")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Choose based on your room size.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.top, 36)
                .padding(.bottom, 32)

                // ── Mode cards ──
                VStack(spacing: 12) {
                    ForEach(CaptureMode.allCases, id: \.rawValue) { mode in
                        CaptureModeCard(
                            mode: mode,
                            isSelected: selectedMode == mode
                        ) {
                            if mode.isAvailable { selectedMode = mode }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // ── Continue ──
                NavigationLink(destination: CaptureSessionView(mode: selectedMode)) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
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
        }
    }
}

// MARK: - Mode card

private struct CaptureModeCard: View {
    let mode: CaptureMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {

                // Lens factor badge
                Text(mode.lensLabel)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(badgeForeground)
                    .frame(width: 54, height: 54)
                    .background(badgeBackground)
                    .cornerRadius(12)

                // Labels
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(mode.displayName)
                            .font(.headline)
                            .foregroundColor(mode.isAvailable ? .white : .white.opacity(0.3))

                        Text("\(mode.targetFrameCount) frames")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }

                    Text(mode.isAvailable ? mode.subtitle : "Not available on this device")
                        .font(.caption)
                        .foregroundColor(.white.opacity(mode.isAvailable ? 0.45 : 0.22))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Selection indicator
                if mode.isAvailable {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .green : .white.opacity(0.3))
                        .font(.title3)
                }
            }
            .padding(16)
            .background(cardBackground)
        }
        .disabled(!mode.isAvailable)
        .buttonStyle(.plain)
    }

    // MARK: Derived colours

    private var badgeForeground: Color {
        isSelected ? .black : (mode.isAvailable ? .white : .white.opacity(0.25))
    }

    private var badgeBackground: Color {
        if isSelected   { return Color.green }
        if !mode.isAvailable { return Color.white.opacity(0.04) }
        return Color.white.opacity(0.1)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                isSelected ? Color.green : Color.white.opacity(0.1),
                lineWidth: isSelected ? 1.5 : 1
            )
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.06 : 0.03))
            )
    }
}
