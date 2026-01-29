import Foundation
import ServiceManagement

/// Service that manages launch at login functionality
final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    private init() {}

    /// Checks if the app is currently set to launch at login
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    /// Sets whether the app should launch at login
    /// - Parameter enabled: true to enable launch at login, false to disable
    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
}
