import AppKit
import SwiftUI

public enum MenuBarIconRenderer {
    @MainActor
    public static func renderIcon(info: BatteryInfo, settings: AppSettings) -> (NSImage, String) {
        let level = max(0, min(100, info.currentPercentage))
        let isCharging = info.isCharging && info.batteryPowerWatts > 0.1
        let isInhibited = info.isChargingInhibited
        let style = settings.menuBarIconStyle
        let mode = settings.menuBarDisplayMode
        let colorized = settings.menuBarColorizedIcon

        let iconImage: NSImage
        switch style {
        case .glassPill:
            iconImage = drawGlassPillBattery(
                level: level,
                isCharging: isCharging,
                isInhibited: isInhibited,
                colorized: colorized
            )
        case .classicBattery:
            let symbolName: String
            if isCharging {
                symbolName = "battery.100percent.bolt"
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
            let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Battery")?.withSymbolConfiguration(config) ?? NSImage()
            img.isTemplate = true
            iconImage = img
        case .minimalBolt:
            let symbolName = isCharging ? "bolt.circle.fill" : (isInhibited ? "pause.circle.fill" : "bolt.horizontal.circle")
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VoltControl")?.withSymbolConfiguration(config) ?? NSImage()
            img.isTemplate = true
            iconImage = img
        }

        // Formatted text next to icon
        var titleString = ""
        switch mode {
        case .iconOnly:
            titleString = ""
        case .iconAndPercent:
            titleString = style == .glassPill ? "" : "\(level)%"
        case .iconAndWatts:
            if info.isACConnected {
                if isCharging {
                    titleString = formatWattsSigned(info.batteryPowerWatts)
                } else if isInhibited {
                    titleString = formatWattsUnsigned(info.systemPowerWatts)
                } else {
                    titleString = formatWattsSigned(-abs(info.batteryPowerWatts))
                }
            } else {
                titleString = formatWattsSigned(-abs(info.batteryPowerWatts))
            }
        case .iconPercentAndWatts:
            let wStr = isCharging ? formatWattsSigned(info.batteryPowerWatts) : formatWattsSigned(-abs(info.batteryPowerWatts))
            if style == .glassPill {
                titleString = wStr
            } else {
                titleString = "\(level)% \(wStr)"
            }
        case .iconAndTemp:
            titleString = String(format: "%.1f°C", info.temperatureCelsius).replacingOccurrences(of: ".", with: ",")
        }

        return (iconImage, titleString)
    }

    private static func formatWattsSigned(_ watts: Double) -> String {
        String(format: "%+.1f Вт", watts).replacingOccurrences(of: ".", with: ",")
    }

    private static func formatWattsUnsigned(_ watts: Double) -> String {
        String(format: "%.1f Вт", watts).replacingOccurrences(of: ".", with: ",")
    }

    /// Draws the macOS 27 Glass Pill Battery with the percentage number inside (like [ 60 ] in the reference screenshot)
    private static func drawGlassPillBattery(
        level: Int,
        isCharging: Bool,
        isInhibited: Bool,
        colorized: Bool
    ) -> NSImage {
        let size = NSSize(width: 34, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let bodyRect = NSRect(x: 1, y: 2.5, width: 29, height: 13)
            let capRect = NSRect(x: 31, y: 6.0, width: 2.0, height: 6.0)

            let primaryColor: NSColor
            if colorized {
                if isCharging {
                    primaryColor = NSColor.systemGreen
                } else if isInhibited {
                    primaryColor = NSColor.systemOrange
                } else if level <= 15 {
                    primaryColor = NSColor.systemRed
                } else {
                    primaryColor = NSColor.labelColor
                }
            } else {
                primaryColor = NSColor.labelColor
            }

            // Outer capsule border
            let borderPath = NSBezierPath(roundedRect: bodyRect, xRadius: 4.2, yRadius: 4.2)
            borderPath.lineWidth = 1.15
            primaryColor.withAlphaComponent(0.75).setStroke()
            borderPath.stroke()

            // Positive terminal cap
            let capPath = NSBezierPath(roundedRect: capRect, xRadius: 1.0, yRadius: 1.0)
            primaryColor.withAlphaComponent(0.6).setFill()
            capPath.fill()

            // Proportional inner level fill
            let insetRect = bodyRect.insetBy(dx: 1.6, dy: 1.6)
            let fillWidth = max(2.0, insetRect.width * CGFloat(level) / 100.0)
            let fillRect = NSRect(x: insetRect.minX, y: insetRect.minY, width: fillWidth, height: insetRect.height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2.8, yRadius: 2.8)
            primaryColor.withAlphaComponent(colorized ? 0.36 : 0.25).setFill()
            fillPath.fill()

            // Percentage text inside pill
            let text = isCharging ? "\(level)⚡" : "\(level)"
            let font = NSFont.monospacedDigitSystemFont(ofSize: isCharging ? 9.0 : 9.8, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let strSize = attrStr.size()
            let textRect = NSRect(
                x: bodyRect.minX,
                y: bodyRect.midY - strSize.height / 2.0 + 0.2,
                width: bodyRect.width,
                height: strSize.height
            )
            attrStr.draw(in: textRect)
            return true
        }
        image.isTemplate = !colorized
        return image
    }
}
