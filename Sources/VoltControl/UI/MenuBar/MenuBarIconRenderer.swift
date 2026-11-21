import AppKit
import SwiftUI

public enum MenuBarIconRenderer {
    /// Canvas size reduced by ~12.5% for optimal macOS menu bar proportions
    private static let batteryCanvasSize = NSSize(width: 35, height: 16.5)
    private static let batteryBodyRect = NSRect(x: 1.2, y: 1.65, width: 29.5, height: 13.2)
    private static let batteryCapRect = NSRect(x: 31.8, y: 5.25, width: 2.0, height: 6.0)

    @MainActor
    public static func renderIcon(info: BatteryInfo, settings: AppSettings) -> (NSImage, String) {
        let level = max(0, min(100, info.currentPercentage))
        let isAC = info.isACConnected
        let isCharging = info.isEffectivelyCharging
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
            let config = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .semibold)
            let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VoltControl")?.withSymbolConfiguration(config) ?? NSImage()
            img.isTemplate = true
            iconImage = img
        }

        var titleString = ""
        switch mode {
        case .iconOnly:
            titleString = ""
        case .iconAndPercent:
            titleString = style == .glassPill ? "" : "\(level)%"
        case .iconAndWatts:
            titleString = wattsDisplayString(info: info, isAC: isAC, isCharging: isCharging)
        case .iconPercentAndWatts:
            let wStr = wattsDisplayString(info: info, isAC: isAC, isCharging: isCharging)
            titleString = style == .glassPill ? wStr : "\(level)% \(wStr)"
        case .iconAndTemp:
            titleString = Formatting.celsiusCompact(info.temperatureCelsius)
        }

        return (iconImage, titleString)
    }

    private static func wattsDisplayString(info: BatteryInfo, isAC: Bool, isCharging: Bool) -> String {
        if isAC {
            if isCharging {
                return Formatting.watts(abs(info.batteryPowerWatts), signed: true)
            } else {
                return Formatting.watts(info.systemPowerWatts, signed: false)
            }
        } else {
            return Formatting.watts(-abs(info.batteryPowerWatts), signed: true)
        }
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

    private static func drawBatteryFrame(
        primaryColor: NSColor,
        cornerRadius: CGFloat,
        borderAlpha: CGFloat,
        capAlpha: CGFloat
    ) {
        let borderPath = NSBezierPath(roundedRect: batteryBodyRect, xRadius: cornerRadius, yRadius: cornerRadius)
        borderPath.lineWidth = 1.2
        primaryColor.withAlphaComponent(borderAlpha).setStroke()
        borderPath.stroke()

        let capPath = NSBezierPath(roundedRect: batteryCapRect, xRadius: 1.0, yRadius: 1.0)
        primaryColor.withAlphaComponent(capAlpha).setFill()
        capPath.fill()
    }

    private static func drawLevelFill(
        level: Int,
        primaryColor: NSColor,
        inset: CGFloat,
        minWidth: CGFloat,
        cornerRadius: CGFloat,
        fillAlpha: CGFloat
    ) {
        let insetRect = batteryBodyRect.insetBy(dx: inset, dy: inset)
        let fillWidth = max(minWidth, insetRect.width * CGFloat(level) / 100.0)
        let fillRect = NSRect(x: insetRect.minX, y: insetRect.minY, width: fillWidth, height: insetRect.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius)
        primaryColor.withAlphaComponent(fillAlpha).setFill()
        fillPath.fill()
    }

    private static func drawPillBattery(
        level: Int,
        isACConnected: Bool,
        isCharging: Bool,
        isInhibited: Bool,
        colorized: Bool
    ) -> NSImage {
        let image = NSImage(size: batteryCanvasSize, flipped: false) { _ in
            let primaryColor = resolveAccentColor(
                level: level,
                isACConnected: isACConnected,
                isCharging: isCharging,
                isInhibited: isInhibited,
                colorized: colorized
            )

            drawBatteryFrame(primaryColor: primaryColor, cornerRadius: 4.4, borderAlpha: 0.82, capAlpha: 0.68)
            drawLevelFill(
                level: level,
                primaryColor: primaryColor,
                inset: 1.6,
                minWidth: 2.5,
                cornerRadius: 2.8,
                fillAlpha: colorized ? 0.38 : 0.26
            )

            let text = "\(level)"
            let fontSize: CGFloat = isACConnected ? (level == 100 ? 8.2 : 9.0) : 9.6
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
                let boltWidth: CGFloat = 5.5
                let spacing: CGFloat = 1.2
                let totalContentWidth = strSize.width + spacing + boltWidth
                let startX = batteryBodyRect.midX - totalContentWidth / 2.0

                let textRect = NSRect(
                    x: startX,
                    y: batteryBodyRect.midY - strSize.height / 2.0 + 0.2,
                    width: strSize.width,
                    height: strSize.height
                )
                attrStr.draw(in: textRect)

                let boltCenter = NSPoint(
                    x: startX + strSize.width + spacing + boltWidth / 2.0,
                    y: batteryBodyRect.midY
                )
                drawVectorBolt(center: boltCenter, height: 8.5, color: NSColor.labelColor, filled: isCharging)
            } else {
                let textRect = NSRect(
                    x: batteryBodyRect.minX,
                    y: batteryBodyRect.midY - strSize.height / 2.0 + 0.2,
                    width: batteryBodyRect.width,
                    height: strSize.height
                )
                attrStr.draw(in: textRect)
            }

            return true
        }
        image.isTemplate = !colorized
        return image
    }

    private static func drawClassicBattery(
        level: Int,
        isACConnected: Bool,
        isCharging: Bool,
        isInhibited: Bool,
        colorized: Bool
    ) -> NSImage {
        let image = NSImage(size: batteryCanvasSize, flipped: false) { _ in
            let primaryColor = resolveAccentColor(
                level: level,
                isACConnected: isACConnected,
                isCharging: isCharging,
                isInhibited: isInhibited,
                colorized: colorized
            )

            drawBatteryFrame(primaryColor: primaryColor, cornerRadius: 3.6, borderAlpha: 0.85, capAlpha: 0.72)
            drawLevelFill(
                level: level,
                primaryColor: primaryColor,
                inset: 2.0,
                minWidth: 2.2,
                cornerRadius: 2.0,
                fillAlpha: isACConnected ? 0.35 : 0.78
            )

            if isACConnected {
                let boltCenter = NSPoint(x: batteryBodyRect.midX, y: batteryBodyRect.midY)
                drawVectorBolt(center: boltCenter, height: 9.8, color: NSColor.labelColor, filled: isCharging)
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

        if filled {
            color.setFill()
            bolt.fill()
        } else {
            bolt.lineWidth = 1.0
            color.setStroke()
            bolt.stroke()
        }
    }
}
