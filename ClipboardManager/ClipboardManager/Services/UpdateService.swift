import Foundation
import Sparkle

/// Service that manages application auto-updates via Sparkle framework
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    private var updaterController: SPUStandardUpdaterController?

    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?

    private init() {
        setupUpdater()
    }

    /// Sets up the Sparkle updater controller
    private func setupUpdater() {
        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Monitor update check availability
        if let updater = updaterController?.updater {
            canCheckForUpdates = updater.canCheckForUpdates
            lastUpdateCheckDate = updater.lastUpdateCheckDate

            // Observe changes
            updater.publisher(for: \.canCheckForUpdates)
                .receive(on: DispatchQueue.main)
                .assign(to: &$canCheckForUpdates)

            updater.publisher(for: \.lastUpdateCheckDate)
                .receive(on: DispatchQueue.main)
                .assign(to: &$lastUpdateCheckDate)
        }
    }

    /// Manually checks for updates
    func checkForUpdates() {
        guard canCheckForUpdates else {
            print("Cannot check for updates at this time")
            return
        }

        updaterController?.checkForUpdates(nil)
    }

    /// Returns the current app version
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    /// Returns the current build number
    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}
