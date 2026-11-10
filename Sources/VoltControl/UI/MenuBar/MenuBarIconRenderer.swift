import AppKit
import SwiftUI

public enum MenuBarIconRenderer {
    /// Shared larger canvas size so both Classic Battery and Capsule Pill have the exact same dimensions
    private static let batteryCanvasSize = NSSize(width: 40, height: 19)
    private static let batteryBodyRect = NSRect(x: 1.5, y: 2.0, width: 33.5, height: 15.0)
    private static let batteryCapRect = NSRect(x: 36.2, y: 6.0, width: 2.3, height: 7.0)

    @MainActor
    public static func renderIcon(info: BatteryInfo, settings: AppSettings) -> (NSImage, String) {
        let level = max(0, min(100, info.currentPercentage))
        let isAC = info.isACConnected
        let isCharging = info.isCharging || (isAC && info.batteryPowerWatts > 0.25)
        let isInhibited = isAC && !isCharging
        let style = settings.menuBarIconStyle
        let mode = settings.menuBarDisplayMode
        let colorized = settings.menuBarColorizedIcon

        let iconImage: NSImage
        switch style {
        case .glassPill:
            iconImage = drawPillBattery(
                level: level,
                isACConnected: isAC,
                isCharging: isCharging,
                isInhibited: isInhibited,
                colorized: colorized
            )
        case .classicBattery:
            iconImage = drawClassicBattery(
                level: level,
                isACConnected: isAC,
                isCharging: isCharging,
                isInhibited: isInhibited,
                colorized: colorized
            )
        case .minimalBolt:
            let symbolName: String
            if isCharging {
                symbolName = "bolt.circle.fill"
            } else if isAC {
                symbolName = "powerplug.fill"
            } else {
                symbolName = "bolt.horizontal.circle"
            }
            let config = NSImage.SymbolConfiguration(pointSize: 15.5, weight: .semibold)
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
            if isAC {
                if isCharging {
                    titleString = formatWattsSigned(abs(info.batteryPowerWatts))
                } else {
                    titleString = formatWattsUnsigned(info.systemPowerWatts)
                }
            } else {
                titleString = formatWattsSigned(-abs(info.batteryPowerWatts))
            }
        case .iconPercentAndWatts:
            let wStr: String
            if isAC {
                wStr = isCharging ? formatWattsSigned(abs(info.batteryPowerWatts)) : formatWattsUnsigned(info.systemPowerWatts)
            } else {
                wStr = formatWattsSigned(-abs(info.batteryPowerWatts))
            }
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

    private static func resolveAccentColor(
        level: Int,
        isACConnected: Bool,
        isCharging: Bool,
        isInhibited: Bool,
        colorized: Bool
    ) -> NSColor {
        guard colorized else { return NSColor.labelColor }
        if isCharging {
            return NSColor.systemGreen
        } else if isInhibited || isACConnected {
            return NSColor.systemBlue
        } else if level <= 15 {
            return NSColor.systemRed
        } else {
            return NSColor.labelColor
        }
    }

    /// Draws the Capsule Pill Battery with percentage inside + crisp vector charging bolt when on AC
    /// Exact same outer size (40x19) as drawClassicBattery
    private static func drawPillBattery(
        level: Int,
        isACConnected: Bool,
        isCharging: Bool,
        isInhibited: Bool,
        colorized: Bool
    ) -> NSImage {
        let image = NSImage(size: batteryCanvasSize, flipped: false) { _ in
            let bodyRect = batteryBodyRect
            let capRect = batteryCapRect

            let primaryColor = resolveAccentColor(
                level: level,
                isACConnected: isACConnected,
                isCharging: isCharging,
                isInhibited: isInhibited,
                colorized: colorized
            )

            // Outer capsule border
            let borderPath = NSBezierPath(roundedRect: bodyRect, xRadius: 5.0, yRadius: 5.0)
            borderPath.lineWidth = 1.3
            primaryColor.withAlphaComponent(0.82).setStroke()
            borderPath.stroke()

            // Positive terminal cap
            let capPath = NSBezierPath(roundedRect: capRect, xRadius: 1.15, yRadius: 1.15)
            primaryColor.withAlphaComponent(0.68).setFill()
            capPath.fill()

            // Proportional inner level fill
            let insetRect = bodyRect.insetBy(dx: 1.8, dy: 1.8)
            let fillWidth = max(3.0, insetRect.width * CGFloat(level) / 100.0)
            let fillRect = NSRect(x: insetRect.minX, y: insetRect.minY, width: fillWidth, height: insetRect.height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 3.3, yRadius: 3.3)
            primaryColor.withAlphaComponent(colorized ? 0.38 : 0.26).setFill()
            fillPath.fill()

            // Percentage text + optional vector bolt when charger is connected
            let text = "\(level)"
            let fontSize: CGFloat = isACConnected ? (level == 100 ? 9.2 : 10.2) : 10.8
            let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let strSize = attrStr.size()

            if isACConnected {
                // Draw lightning bolt on the left/right and number next to it
                let boltWidth: CGFloat = 6.5
                let spacing: CGFloat = 1.5
                let totalContentWidth = strSize.width + spacing + boltWidth
                let startX = bodyRect.midX - totalContentWidth / 2.0

                let textRect = NSRect(
                    x: startX,
                    y: bodyRect.midY - strSize.height / 2.0 + 0.2,
                    width: strSize.width,
                    height: strSize.height
                )
                attrStr.draw(in: textRect)

                let boltCenter = NSPoint(
                    x: startX + strSize.width + spacing + boltWidth / 2.0,
                    y: bodyRect.midY
                )
                drawVectorBolt(center: boltCenter, height: 9.6, color: NSColor.labelColor, filled: isCharging)
            } else {
                let textRect = NSRect(
                    x: bodyRect.minX,
                    y: bodyRect.midY - strSize.height / 2.0 + 0.2,
                    width: bodyRect.width,
                    height: strSize.height
                )
                attrStr.draw(in: textRect)
            }

            return true
        }
        image.isTemplate = !colorized
        return image
    }

    /// Draws the Classic Battery with proportional level bar + crisp vector bolt when on AC
    /// Exact same outer size (40x19) as drawPillBattery
    private static func drawClassicBattery(
        level: Int,
        isACConnected: Bool,
        isCharging: Bool,
        isInhibited: Bool,
        colorized: Bool
    ) -> NSImage {
        let image = NSImage(size: batteryCanvasSize, flipped: false) { _ in
            let bodyRect = batteryBodyRect
            let capRect = batteryCapRect

            let primaryColor = resolveAccentColor(
                level: level,
                isACConnected: isACConnected,
                isCharging: isCharging,
                isInhibited: isInhibited,
                colorized: colorized
            )

            // Outer battery border
            let borderPath = NSBezierPath(roundedRect: bodyRect, xRadius: 4.2, yRadius: 4.2)
            borderPath.lineWidth = 1.35
            primaryColor.withAlphaComponent(0.85).setStroke()
            borderPath.stroke()

            // Positive terminal cap
            let capPath = NSBezierPath(roundedRect: capRect, xRadius: 1.15, yRadius: 1.15)
            primaryColor.withAlphaComponent(0.72).setFill()
            capPath.fill()

            // Inner battery capacity bar
            let insetRect = bodyRect.insetBy(dx: 2.3, dy: 2.3)
            let fillWidth = max(2.5, insetRect.width * CGFloat(level) / 100.0)
            let fillRect = NSRect(x: insetRect.minX, y: insetRect.minY, width: fillWidth, height: insetRect.height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2.4, yRadius: 2.4)
            primaryColor.withAlphaComponent(isACConnected ? 0.35 : 0.78).setFill()
            fillPath.fill()

            // When charger is connected, draw crisp centered lightning bolt
            if isACConnected {
                let boltCenter = NSPoint(x: bodyRect.midX, y: bodyRect.midY)
                drawVectorBolt(center: boltCenter, height: 11.2, color: NSColor.labelColor, filled: true)
            }

            return true
        }
        image.isTemplate = !colorized
        return image
    }

    /// Draws a sharp vector lightning bolt centered at `center`
    private static func drawVectorBolt(center: NSPoint, height: CGFloat, color: NSColor, filled: Bool) {
        let h = height
        let w = height * 0.62
        let cx = center.x
        let cy = center.y

        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: cx + w * 0.12, y: cy + h * 0.50))
        bolt.line(to: NSPoint(x: cx - w * 0.48, y: cy - h * 0.04))
        bolt.line(to: NSPoint(x: cx - w * 0.04, y: cy - h * 0.04))
        bolt.line(to: NSPoint(x: cx - w * 0.14, y: cy - h * 0.50))
        bolt.line(to: NSPoint(x: cx + w * 0.48, y: cy + h * 0.04))
        bolt.line(to: NSPoint(x: cx + w * 0.04, y: cy + h * 0.04))
        bolt.close()

        color.setFill()
        bolt.fill()
    }
}
