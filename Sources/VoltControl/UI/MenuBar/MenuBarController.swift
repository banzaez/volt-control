import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject, NSWindowDelegate, NSPopoverDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var lastRenderKey: String = ""

    private override init() {
        super.init()
    }

    @MainActor
    public func setup() {
        // Assign the Blue Side-View Lego Brick App Icon to NSApp
        NSApp.applicationIconImage = AppIconGenerator.makeImage(size: 512)

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
        pop.delegate = self

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

        // Update menu bar appearance immediately
        updateMenuBar(force: true)
    }

    @MainActor
    public func updateMenuBar(with providedInfo: BatteryInfo? = nil, force: Bool = false) {
        guard let button = statusItem?.button else { return }

        let info = providedInfo ?? BatteryMonitor.shared.info
        let settings = AppSettings.shared

        // Optimization: Dirty check to avoid redundant image creation and CoreGraphics drawing
        let renderKey = "\(info.currentPercentage)_\(info.isACConnected)_\(info.isCharging)_\(info.isChargingInhibited)_\(settings.menuBarIconStyle.rawValue)_\(settings.menuBarDisplayMode.rawValue)_\(settings.menuBarColorizedIcon)_\(Int(info.batteryPowerWatts * 10))_\(Int(info.systemPowerWatts * 10))_\(Int(info.temperatureCelsius * 10))"

        if !force && renderKey == lastRenderKey {
            return
        }
        lastRenderKey = renderKey

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

    @MainActor
    public func closePopoverIfNeeded() {
        if !AppSettings.shared.keepMenuOpenOnAction {
            popover?.performClose(nil)
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            BatteryMonitor.shared.fetchSnapshot()
            HighEnergyAppService.shared.setMenuVisible(true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - NSPopoverDelegate
    public func popoverWillShow(_ notification: Notification) {
        HighEnergyAppService.shared.setMenuVisible(true)
    }

    public func popoverDidClose(_ notification: Notification) {
        HighEnergyAppService.shared.setMenuVisible(false)
    }

    @MainActor
    public func openSettings() {
        popover?.performClose(nil)

        // Show app icon in Dock & Cmd+Tab while Settings window is open
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppIconGenerator.makeImage(size: 512)

        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "VoltControl — Настройки"
            window.minSize = NSSize(width: 680, height: 520)
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        if let closedWin = notification.object as? NSWindow, closedWin == settingsWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
