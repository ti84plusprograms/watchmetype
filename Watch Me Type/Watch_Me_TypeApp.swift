import SwiftUI
import ApplicationServices

@main
struct Watch_Me_TypeApp: App {
    init() {
        // Accessibility permission is requested after an in-app explanation.
        // Do not start Sparkle in the fork until a fork-owned signing key,
        // published signed releases, and a working fork appcast are configured.
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The forced Dark Mode is available only to explicitly
                // flagged UI-test launches; ordinary app appearance is unchanged.
                .preferredColorScheme(UIRegressionFixture.forceDarkAppearance ? .dark : nil)
        }
        .defaultSize(width: 1000, height: 840)
    }
}
