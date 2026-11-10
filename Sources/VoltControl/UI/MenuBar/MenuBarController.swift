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
        pop.contentSize = NSSize(width: 275, height: 340)

        let popoverView = MainPopoverView(
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        pop.contentViewController = NSHostingController(rootView: popoverView)
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
        let mode = AppSettings.shared.menuBarDisplayMode
        let (icon, title) = MenuBarIconRenderer.renderIcon(info: info, mode: mode)

        button.image = icon
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        button.title = title

        // Monospaced numbers for smooth non-jumping layout
        if !title.isEmpty {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.font: font]
            )
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Trigger fresh reading on click
            BatteryMonitor.shared.fetchSnapshot()
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
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "ВольтКонтроль — Настройки"
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            window.center()
            self.settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
