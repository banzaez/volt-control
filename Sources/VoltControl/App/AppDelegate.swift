import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = AppIconGenerator.makeImage(size: 512)

        NotificationService.shared.requestAuthorization()

        HelperClient.shared.refreshStatus()
        Task {
            await HelperClient.shared.connectAndProbe()
        }

        MenuBarController.shared.setup()
        BatteryMonitor.shared.startMonitoring()

        let autoCheck = AppSettings.shared.autoCheckUpdates
        AppUpdateService.shared.setAutoCheckEnabled(autoCheck)
        if autoCheck {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                AppUpdateService.shared.checkForUpdates(isUserInitiated: false)
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        BatteryMonitor.shared.stopMonitoring()

        var finished = false
        Task { @MainActor in
            await ChargeController.shared.resetOnTerminate()
            finished = true
        }
        let deadline = Date().addingTimeInterval(0.3)
        while !finished && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }
}
