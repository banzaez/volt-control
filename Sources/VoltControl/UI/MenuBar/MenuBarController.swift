import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject, NSWindowDelegate {
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

        // Update menu bar appearance immediately and periodically in .common RunLoop mode
        updateMenuBar()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMenuBar()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.updateTimer = timer
    }

    @MainActor
    public func updateMenuBar(with providedInfo: BatteryInfo? = nil) {
        guard let button = statusItem?.button else { return }

        let info = providedInfo ?? BatteryMonitor.shared.info
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
            HighEnergyAppService.shared.refresh()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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
