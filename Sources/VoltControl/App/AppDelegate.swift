import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar accessory without dock icon
        NSApp.setActivationPolicy(.accessory)

        // Request user notification permissions
        NotificationService.shared.requestAuthorization()

        // Setup Menu Bar Item and Popover
        MenuBarController.shared.setup()

        // Start battery monitoring service
        BatteryMonitor.shared.startMonitoring()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        BatteryMonitor.shared.stopMonitoring()
    }
}
