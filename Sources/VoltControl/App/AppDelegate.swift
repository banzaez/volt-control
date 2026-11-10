import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar accessory by default (switches to .regular with Dock icon when Settings window is open)
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = AppIconGenerator.makeImage(size: 512)

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
