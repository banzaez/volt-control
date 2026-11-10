import SwiftUI

public struct MainPopoverView: View {
    @Bindable var monitor = BatteryMonitor.shared
    @Bindable var settings = AppSettings.shared
    public let onOpenSettings: () -> Void
    public let onQuit: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            // Top App Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.batteryblock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)

                    Text("ВольтКонтроль")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                if monitor.info.isACConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: 10))
                        Text("Сеть подключена")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.4)

            // Content ScrollView
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // 1. Current Battery Status & Gauge
                    BatteryGaugeView(info: monitor.info, settings: settings)

                    // 2. Power Flow (В батарею, расход Mac, адаптер)
                    PowerFlowView(info: monitor.info)

                    // 3. Quick Actions (Зарядить до 100%, пресеты, пауза)
                    QuickActionsView(
                        info: monitor.info,
                        settings: settings,
                        onToggleTopUp: { monitor.toggleTopUp() },
                        onSetLimit: { monitor.setQuickLimit($0) },
                        onTogglePause: { monitor.togglePause() }
                    )

                    // 4. Battery Health & Analytics
                    BatteryHealthView(info: monitor.info)
                }
                .padding(14)
            }

            Divider()
                .opacity(0.4)

            // Footer Bar: Settings & Quit
            HStack {
                Button(action: onOpenSettings) {
                    Label("Настройки...", systemImage: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }

                Spacer()

                Button(action: onQuit) {
                    Label("Выход", systemImage: "power")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 350, height: 560)
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
    }
}

// macOS Visual Effect Blur
public struct VisualEffectBlur: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
