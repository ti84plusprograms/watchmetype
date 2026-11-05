import SwiftUI
import ApplicationServices
import AppKit

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
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Watch Me Type") {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
                    let localChanges = GitInfo.worktreeState == "clean"
                        ? "none"
                        : "ID \(GitInfo.worktreeFingerprint)"
                    let details = """
                    Branch: \(GitInfo.branch)
                    Commit: \(GitInfo.commit)
                    Git description: \(GitInfo.gitDescription)
                    Local changes: \(localChanges)
                    Built: \(GitInfo.builtAt)
                    Running from: \(Bundle.main.bundleURL.path)
                    """
                    let options: [NSApplication.AboutPanelOptionKey: Any] = [
                        .applicationName: "Watch Me Type",
                        .applicationVersion: "Version \(version) - \(GitInfo.displayString)",
                        .credits: NSAttributedString(string: details)
                    ]
                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
        }
    }
}
