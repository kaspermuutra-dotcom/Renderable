import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var page = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $page) {
                WelcomePage(onNext: {
                    withAnimation(.easeInOut(duration: 0.4)) { page = 1 }
                })
                .tag(0)

                InstructionsPage(onComplete: {
                    onboardingComplete = true
                })
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator dots
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Color.white : Color.white.opacity(0.25))
                            .frame(width: i == page ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 44)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Wordmark
            HStack(spacing: 0) {
                Text("Render")
                    .font(.system(size: 44, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                Text("able")
                    .font(.system(size: 44, weight: .semibold, design: .default))
                    .foregroundColor(.green)
            }

            Text("Create navigable property walkthroughs.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.horizontal, 40)

            Spacer()

            Button(action: onNext) {
                Text("Begin")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 88)
        }
    }
}

// MARK: - Page 2: Instructions
// Internal (not private) so HomeView can present this page standalone as a sheet.

struct InstructionsPage: View {
    let onComplete: () -> Void
    /// Label for the primary button. Defaults to "Start Scanning" for the onboarding context;
    /// pass "Got it" when presenting as a revisit sheet from HomeView.
    var buttonLabel: String = "Start Scanning"

    private let items: [String] = [
        "Make sure the room is tidy",
        "Use good, even lighting",
        "Choose a normal open room",
        "Avoid very large halls or open-plan spaces",
        "Avoid very cramped or narrow spaces",
        "Rotate slowly and follow the on-screen guidance"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Before you scan")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.bottom, 36)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(item)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button(action: onComplete) {
                Text(buttonLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 88)
        }
    }
}
