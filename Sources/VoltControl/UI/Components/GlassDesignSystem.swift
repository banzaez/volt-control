import SwiftUI
import AppKit

// MARK: - Blue Side-View Lego Brick App Icon Generator & View
public enum AppIconGenerator {
    public static func makeImage(size: CGFloat = 256) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            drawLegoBrickIcon(in: rect)
            return true
        }
        return img
    }

    public static func drawLegoBrickIcon(in rect: NSRect) {
        let s = min(rect.width, rect.height)
        let inset = s * 0.0625
        let bgRect = NSRect(x: rect.minX + inset, y: rect.minY + inset, width: s - inset * 2, height: s - inset * 2)
        let cornerRadius = bgRect.width * 0.225

        // 1. Squircle Background (Deep Navy-Slate with subtle blue ambient glow)
        let squircle = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
        let bgGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.26, alpha: 1.0),
            NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.15, alpha: 1.0)
        ])!
        bgGradient.draw(in: squircle, angle: -90)

        // Subtle outer border on squircle
        squircle.lineWidth = max(1.0, s * 0.014)
        NSColor(calibratedRed: 0.25, green: 0.55, blue: 1.0, alpha: 0.35).setStroke()
        squircle.stroke()

        // 2. Blue Lego Brick (Side Profile View)
        // Dimensions of the brick in side view:
        // Main brick body + 2 classic Lego studs on top + subtle bottom interlock lip
        let bodyWidth = s * 0.62
        let bodyHeight = s * 0.32
        let bodyX = rect.midX - bodyWidth / 2.0
        let bodyY = rect.midY - bodyHeight / 2.0 - s * 0.04

        // Drop shadow under brick
        let shadowRect = NSRect(x: bodyX + s * 0.02, y: bodyY - s * 0.035, width: bodyWidth - s * 0.04, height: s * 0.06)
        let shadowPath = NSBezierPath(ovalIn: shadowRect)
        NSColor(calibratedWhite: 0.0, alpha: 0.45).setFill()
        shadowPath.fill()

        // Bottom Lego interlock lip (subtle recessed base seen from the side)
        let lipWidth = bodyWidth * 0.86
        let lipHeight = s * 0.032
        let lipRect = NSRect(
            x: rect.midX - lipWidth / 2.0,
            y: bodyY - lipHeight * 0.65,
            width: lipWidth,
            height: lipHeight
        )
        let lipPath = NSBezierPath(roundedRect: lipRect, xRadius: s * 0.012, yRadius: s * 0.012)
        NSColor(calibratedRed: 0.02, green: 0.28, blue: 0.68, alpha: 1.0).setFill()
        lipPath.fill()

        // Two Lego Studs on top (side view of a 2-stud brick)
        let studWidth = bodyWidth * 0.31
        let studHeight = s * 0.095
        let studSpacing = bodyWidth * 0.14
        let leftStudX = rect.midX - studSpacing / 2.0 - studWidth
        let rightStudX = rect.midX + studSpacing / 2.0
        let studY = bodyY + bodyHeight - s * 0.012
        let studRadius = s * 0.024

        let studGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.18, green: 0.62, blue: 1.00, alpha: 1.0),
            NSColor(calibratedRed: 0.04, green: 0.45, blue: 0.92, alpha: 1.0)
        ])!

        for studX in [leftStudX, rightStudX] {
            let studRect = NSRect(x: studX, y: studY, width: studWidth, height: studHeight)
            let studPath = NSBezierPath(roundedRect: studRect, xRadius: studRadius, yRadius: studRadius)
            studGradient.draw(in: studPath, angle: 0)

            // Top specular highlight on stud
            let studHighlightRect = NSRect(
                x: studRect.minX + studWidth * 0.08,
                y: studRect.maxY - studHeight * 0.26,
                width: studWidth * 0.84,
                height: studHeight * 0.16
            )
            let studHighlight = NSBezierPath(roundedRect: studHighlightRect, xRadius: studRadius * 0.5, yRadius: studRadius * 0.5)
            NSColor(calibratedWhite: 1.0, alpha: 0.35).setFill()
            studHighlight.fill()

            studPath.lineWidth = max(0.8, s * 0.01)
            NSColor(calibratedWhite: 1.0, alpha: 0.25).setStroke()
            studPath.stroke()
        }

        // Main Brick Body (Side View)
        let bodyRect = NSRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight)
        let bodyRadius = s * 0.038
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: bodyRadius, yRadius: bodyRadius)

        let bodyGradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.14, green: 0.58, blue: 1.00, alpha: 1.0),
            NSColor(calibratedRed: 0.03, green: 0.42, blue: 0.90, alpha: 1.0),
            NSColor(calibratedRed: 0.01, green: 0.32, blue: 0.76, alpha: 1.0)
        ])!
        bodyGradient.draw(in: bodyPath, angle: -90)

        // Top bevel highlight along brick body
        let topBevelRect = NSRect(
            x: bodyRect.minX + s * 0.025,
            y: bodyRect.maxY - s * 0.032,
            width: bodyRect.width - s * 0.05,
            height: s * 0.018
        )
        let topBevelPath = NSBezierPath(roundedRect: topBevelRect, xRadius: s * 0.009, yRadius: s * 0.009)
        NSColor(calibratedWhite: 1.0, alpha: 0.38).setFill()
        topBevelPath.fill()

        // Bottom inner shadow line on brick body
        let bottomShadeRect = NSRect(
            x: bodyRect.minX + s * 0.02,
            y: bodyRect.minY + s * 0.012,
            width: bodyRect.width - s * 0.04,
            height: s * 0.02
        )
        let bottomShadePath = NSBezierPath(roundedRect: bottomShadeRect, xRadius: s * 0.008, yRadius: s * 0.008)
        NSColor(calibratedWhite: 0.0, alpha: 0.22).setFill()
        bottomShadePath.fill()

        // Crisp border on main brick body
        bodyPath.lineWidth = max(1.0, s * 0.012)
        NSColor(calibratedWhite: 1.0, alpha: 0.28).setStroke()
        bodyPath.stroke()
    }
}

public struct AppIconView: View {
    public let size: CGFloat

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        Image(nsImage: AppIconGenerator.makeImage(size: max(64, size * 2)))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

// MARK: - Clean Standard macOS Group Card Modifier
public struct GlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var padding: CGFloat

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    public func glassCard(
        cornerRadius: CGFloat = 10,
        padding: CGFloat = 14
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Minimalist Blue-Accented Custom Slider
public struct GlassSlider: View {
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double
    public var unit: String = "%"
    public var presets: [Double] = []

    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1.0,
        unit: String = "%",
        presets: [Double] = []
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.presets = presets
    }

    private var normalizedValue: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return CGFloat((clamped - range.lowerBound) / span)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let thumbDiameter: CGFloat = 16
                let usableWidth = max(1, width - thumbDiameter)
                let thumbX = usableWidth * normalizedValue

                ZStack(alignment: .leading) {
                    // Track Groove
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                        .frame(height: 6)

                    // Active Blue Fill
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.85), Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, thumbX + thumbDiameter * 0.5), height: 6)

                    // Subtle Tick Marks
                    ForEach(presets, id: \.self) { preset in
                        let norm = CGFloat((preset - range.lowerBound) / max(1, range.upperBound - range.lowerBound))
                        Circle()
                            .fill(Color.primary.opacity(0.28))
                            .frame(width: 3, height: 3)
                            .offset(x: usableWidth * norm + (thumbDiameter * 0.5) - 1.5)
                    }

                    // Minimalist Knob
                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .overlay(
                            Circle()
                                .fill(Color.white.opacity(0.95))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.22), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.20), radius: isDragging ? 3 : 1.5, x: 0, y: 1)
                        .scaleEffect(isDragging ? 1.08 : (isHovered ? 1.03 : 1.0))
                        .offset(x: thumbX)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .onHover { inside in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHovered = inside
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let locationX = gesture.location.x - thumbDiameter * 0.5
                            let ratio = min(max(0, locationX / usableWidth), 1)
                            let rawVal = range.lowerBound + Double(ratio) * (range.upperBound - range.lowerBound)
                            let stepped = (rawVal / step).rounded() * step
                            let clamped = min(max(stepped, range.lowerBound), range.upperBound)
                            if clamped != value {
                                value = clamped
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.15)) {
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 20)

            // Preset Pills
            if !presets.isEmpty {
                HStack(spacing: 5) {
                    ForEach(presets, id: \.self) { preset in
                        let isSelected = abs(value - preset) < 0.01
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                value = preset
                            }
                        }) {
                            Text(formatPreset(preset))
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(isSelected ? Color.blue.opacity(0.16) : Color.primary.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(isSelected ? Color.blue.opacity(0.45) : Color.clear, lineWidth: 0.7)
                                )
                                .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
        }
    }

    private func formatPreset(_ val: Double) -> String {
        if step >= 1.0 {
            return "\(Int(val))\(unit)"
        } else {
            return String(format: "%.1f%@", val, unit)
        }
    }
}

// MARK: - Clean Blue-Accented Toggle Row
public struct GlassToggleRow: View {
    public let icon: String
    public let title: String
    public var subtitle: String? = nil
    @Binding public var isOn: Bool

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    public var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 24, height: 24)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.blue)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(.primary)

                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.blue)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}
