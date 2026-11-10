import AppKit
import SwiftUI

public enum MenuBarIconRenderer {
    public static func renderIcon(info: BatteryInfo, mode: MenuBarDisplayMode) -> (NSImage, String) {
        let level = info.currentPercentage
        let isCharging = info.isCharging && info.batteryPowerWatts > 0.1
        let isInhibited = info.isChargingInhibited

        // Select base symbol name
        let symbolName: String
        if isCharging {
            symbolName = "battery.100percent.bolt"
        } else if isInhibited {
            symbolName = "battery.100"
        } else if level >= 90 {
            symbolName = "battery.100"
        } else if level >= 65 {
            symbolName = "battery.75"
        } else if level >= 40 {
            symbolName = "battery.50"
        } else if level >= 15 {
            symbolName = "battery.25"
        } else {
            symbolName = "battery.0"
        }

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Battery")?.withSymbolConfiguration(config) ?? NSImage()
        baseImage.isTemplate = true

        // Formatted text next to icon
        var titleString = ""
        switch mode {
        case .iconOnly:
            titleString = ""
        case .iconAndPercent:
            titleString = "\(level)%"
        case .iconAndWatts:
            if info.isACConnected {
                if isCharging {
                    titleString = String(format: "+%.1fW", info.batteryPowerWatts)
                } else if isInhibited {
                    titleString = String(format: "%.1fW", info.systemPowerWatts)
                } else {
                    titleString = String(format: "-%.1fW", abs(info.batteryPowerWatts))
                }
            } else {
                titleString = String(format: "-%.1fW", abs(info.batteryPowerWatts))
            }
        case .iconPercentAndWatts:
            if isCharging {
                titleString = String(format: "%d%% (+%.0fW)", level, info.batteryPowerWatts)
            } else {
                titleString = String(format: "%d%% (-%.0fW)", level, abs(info.batteryPowerWatts))
            }
        }

        return (baseImage, titleString)
    }
}
