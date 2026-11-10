import SwiftUI
import AppKit

// MARK: - Minimalist Monochrome App Icon View
public struct AppIconView: View {
    public let size: CGFloat

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Minimalist Graphite Squircle
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.20),
                            Color(white: 0.11)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.black.opacity(0.22), radius: size * 0.08, x: 0, y: size * 0.03)

            // Subtle Inner Highlight
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: max(1.0, size * 0.018)
                )

            // Minimalist Battery Outline + Bolt
            HStack(spacing: size * 0.025) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: size * 0.54, height: size * 0.34)
                        .overlay(
                            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                                .stroke(Color.white.opacity(0.85), lineWidth: max(1.2, size * 0.03))
                        )

                    Image(systemName: "bolt.fill")
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundStyle(.white)
                }

                RoundedRectangle(cornerRadius: size * 0.025, style: .continuous)
                    .fill(Color.white.opacity(0.75))
                    .frame(width: size * 0.04, height: size * 0.12)
            }
        }
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

// MARK: - Minimalist Monochrome Custom Slider
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

                    // Active Monochrome Fill
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.70))
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
                                .fill(Color.white.opacity(0.9))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.25), lineWidth: 0.8)
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

            // Monochrome Preset Pills
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
                                        .fill(isSelected ? Color.primary.opacity(0.15) : Color.primary.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 0.6)
                                )
                                .foregroundStyle(isSelected ? .primary : .secondary)
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

// MARK: - Minimalist Monochrome Toggle Row
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
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)

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
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}
