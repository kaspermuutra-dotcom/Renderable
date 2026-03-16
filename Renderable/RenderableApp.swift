import SwiftUI

@main
struct RenderableApp: App {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
            // Dissolve between OnboardingView and HomeView instead of a hard cut.
            .animation(.easeInOut(duration: 0.35), value: onboardingComplete)
            .preferredColorScheme(.dark)
        }
    }
}
