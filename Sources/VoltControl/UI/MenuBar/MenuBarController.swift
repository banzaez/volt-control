import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var updateTimer: Timer?

    private override init() {
        super.init()
    }

    @MainActor
    public func setup() {
        // Render and assign custom macOS 27 Glass App Icon to NSApp
        let iconHosting = NSHostingView(rootView: AppIconView(size: 256))
        iconHosting.frame = NSRect(x: 0, y: 0, width: 256, height: 256)
        if let bitmapRep = iconHosting.bitmapImageRepForCachingDisplay(in: iconHosting.bounds) {
            iconHosting.cacheDisplay(in: iconHosting.bounds, to: bitmapRep)
            let appIcon = NSImage(size: NSSize(width: 256, height: 256))
            appIcon.addRepresentation(bitmapRep)
            NSApp.applicationIconImage = appIcon
        }

        // Create NSStatusItem
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create NSPopover
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true

        let popoverView = MainPopoverView(
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        let hostingController = NSHostingController(rootView: popoverView)
        hostingController.sizingOptions = [.preferredContentSize]
        pop.contentViewController = hostingController
        self.popover = pop

        // Update menu bar appearance periodically
        updateMenuBar()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMenuBar()
            }
        }
    }

    @MainActor
    public func updateMenuBar() {
        guard let button = statusItem?.button else { return }

        let info = BatteryMonitor.shared.info
        let settings = AppSettings.shared
        let (icon, title) = MenuBarIconRenderer.renderIcon(info: info, settings: settings)

        button.image = icon
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        button.title = title

        if !title.isEmpty {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
            button.attributedTitle = NSAttributedString(
                string: " " + title,
                attributes: [.font: font]
            )
        } else {
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            BatteryMonitor.shared.fetchSnapshot()
            HighEnergyAppService.shared.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @MainActor
    public func openSettings() {
        popover?.performClose(nil)

        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 650),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "ВольтКонтроль — Настройки"
            window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 640, height: 540)
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            window.center()
            self.settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
