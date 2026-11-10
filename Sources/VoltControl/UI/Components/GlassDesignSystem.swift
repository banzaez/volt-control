import SwiftUI
import AppKit

// MARK: - macOS 27 Liquid Glass App Icon View
public struct AppIconView: View {
    public let size: CGFloat

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Outer Squircle Base with Rich Liquid Gradient
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.14, blue: 0.28),
                            Color(red: 0.05, green: 0.24, blue: 0.34),
                            Color(red: 0.06, green: 0.42, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.cyan.opacity(0.28), radius: size * 0.12, x: 0, y: size * 0.05)

            // Ambient Glow Orbs inside Icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.mint.opacity(0.55), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.45
                    )
                )
                .frame(width: size * 0.85, height: size * 0.85)
                .offset(x: size * 0.12, y: size * 0.14)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.45), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.75, height: size * 0.75)
                .offset(x: -size * 0.16, y: -size * 0.15)

            // Inner Glass Battery Chamber
            HStack(spacing: size * 0.025) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: size * 0.56, height: size * 0.34)
                        .overlay(
                            RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.75), Color.white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: max(1.2, size * 0.025)
                                )
                        )

                    // Glowing Charge Fill inside Battery
                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.mint, Color.green, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: size * 0.40, height: size * 0.25)
                        .padding(.leading, size * 0.045)
                }

                // Battery Positive Cap
                RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                    .fill(Color.white.opacity(0.65))
                    .frame(width: size * 0.045, height: size * 0.13)
            }

            // Specular Lightning Bolt Overlay
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 0.85, green: 1.0, blue: 0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.black.opacity(0.35), radius: size * 0.04, x: 0, y: size * 0.02)

            // Top Glass Specular Rim
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.05),
                            Color.cyan.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.0, size * 0.022)
                )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - macOS 27 Liquid Glass Card Modifier
public struct GlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    public var tint: Color

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint)

                    // Top subtle sheen
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.10),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.03),
                                Color.white.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    public func glassCard(
        cornerRadius: CGFloat = 14,
        padding: CGFloat = 14,
        tint: Color = Color.primary.opacity(0.02)
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding, tint: tint))
    }
}

// MARK: - Custom macOS 27 Liquid Glass Slider
public struct GlassSlider: View {
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double
    public var unit: String = "%"
    public var accentColors: [Color] = [.cyan, .mint, .green]
    public var presets: [Double] = []

    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1.0,
        unit: String = "%",
        accentColors: [Color] = [.cyan, .mint, .green],
        presets: [Double] = []
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.accentColors = accentColors
        self.presets = presets
    }

    private var normalizedValue: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return CGFloat((clamped - range.lowerBound) / span)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let thumbDiameter: CGFloat = 20
                let usableWidth = max(1, width - thumbDiameter)
                let thumbX = usableWidth * normalizedValue

                ZStack(alignment: .leading) {
                    // Track Background (Frosted Groove)
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                        .frame(height: 10)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                        )

                    // Active Glowing Fill Track
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: accentColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, thumbX + thumbDiameter * 0.5), height: 10)
                        .shadow(color: (accentColors.last ?? .cyan).opacity(isDragging ? 0.5 : 0.25), radius: 6, x: 0, y: 0)

                    // Tick Marks for Presets on Track
                    ForEach(presets, id: \.self) { preset in
                        let norm = CGFloat((preset - range.lowerBound) / max(1, range.upperBound - range.lowerBound))
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 4, height: 4)
                            .offset(x: usableWidth * norm + (thumbDiameter * 0.5) - 2)
                    }

                    // Liquid Glass Thumb Knob
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: thumbDiameter, height: thumbDiameter)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.92),
                                        Color.white.opacity(0.65)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: thumbDiameter - 2, height: thumbDiameter - 2)

                        Circle()
                            .fill(accentColors.last ?? .accentColor)
                            .frame(width: 7, height: 7)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: isDragging ? 5 : 3, x: 0, y: 1.5)
                    .scaleEffect(isDragging ? 1.12 : (isHovered ? 1.05 : 1.0))
                    .offset(x: thumbX)
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .onHover { inside in
                    withAnimation(.easeOut(duration: 0.15)) {
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
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 24)

            // Quick Preset Chips (if provided)
            if !presets.isEmpty {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { preset in
                        let isSelected = abs(value - preset) < 0.01
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                value = preset
                            }
                        }) {
                            Text(formatPreset(preset))
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            isSelected
                                                ? (accentColors.last ?? Color.accentColor).opacity(0.24)
                                                : Color.primary.opacity(0.05)
                                        )
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(
                                            isSelected
                                                ? (accentColors.last ?? Color.accentColor).opacity(0.6)
                                                : Color.white.opacity(0.1),
                                            lineWidth: 0.8
                                        )
                                )
                                .foregroundStyle(isSelected ? (accentColors.last ?? Color.accentColor) : .secondary)
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

// MARK: - Glass Toggle Row
public struct GlassToggleRow: View {
    public let icon: String
    public let iconColor: Color
    public let title: String
    public var subtitle: String? = nil
    @Binding public var isOn: Bool

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.primary)

                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 3)
    }
}
