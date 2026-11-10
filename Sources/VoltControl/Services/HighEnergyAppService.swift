import AppKit
import Foundation
import SwiftUI

public enum EnergyImpactLevel: String, Sendable {
    case veryHigh = "Очень высокий"
    case high = "Высокий"
    case moderate = "Умеренный"
    case low = "Низкий"

    public var badgeColor: Color {
        switch self {
        case .veryHigh: return .red
        case .high: return .orange
        case .moderate: return .yellow
        case .low: return .secondary
        }
    }

    public var iconName: String {
        switch self {
        case .veryHigh: return "bolt.trianglebadge.exclamationmark.fill"
        case .high: return "gauge.with.dots.needle.67percent"
        case .moderate: return "gauge.with.dots.needle.33percent"
        case .low: return "gauge.with.dots.needle.0percent"
        }
    }
}

public struct HighEnergyApp: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let impact: EnergyImpactLevel
    public let cpuUsage: Double
    public let isPlaceholder: Bool

    public init(id: String? = nil, name: String, impact: EnergyImpactLevel, cpuUsage: Double, isPlaceholder: Bool = false) {
        self.id = id ?? name
        self.name = name
        self.impact = impact
        self.cpuUsage = cpuUsage
        self.isPlaceholder = isPlaceholder
    }
}

@MainActor
@Observable
public final class HighEnergyAppService {
    public static let shared = HighEnergyAppService()

    /// Always contains exactly 4 items so the menu layout never jumps
    public private(set) var topFourSlots: [HighEnergyApp] = [
        HighEnergyApp(id: "slot-0", name: "Анализ процессов...", impact: .low, cpuUsage: 0, isPlaceholder: true),
        HighEnergyApp(id: "slot-1", name: "—", impact: .low, cpuUsage: 0, isPlaceholder: true),
        HighEnergyApp(id: "slot-2", name: "—", impact: .low, cpuUsage: 0, isPlaceholder: true),
        HighEnergyApp(id: "slot-3", name: "—", impact: .low, cpuUsage: 0, isPlaceholder: true)
    ]

    public private(set) var appIcons: [String: NSImage] = [:]

    private var timer: Timer?

    private init() {
        start()
    }

    public func start() {
        refresh()
        scheduleTimer()
    }

    public func scheduleTimer() {
        timer?.invalidate()
        let interval = max(2.0, AppSettings.shared.processScanIntervalSeconds)
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }

    public func refresh() {
        let highThreshold = AppSettings.shared.highEnergyThresholdCPU
        let veryHighThreshold = max(highThreshold + 2.0, AppSettings.shared.veryHighEnergyThresholdCPU)
        let includeSystem = AppSettings.shared.includeSystemProcesses
        let ignoredSet = AppSettings.shared.parsedIgnoredApps()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let pipe = Pipe()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/ps")
            proc.arguments = ["-Aceo", "%cpu,comm"]
            proc.standardOutput = pipe
            do {
                try proc.run()
            } catch {
                return
            }

            // Read before waitUntilExit to prevent pipe buffer deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return }

            var cpuMap: [String: Double] = [:]
            for line in output.components(separatedBy: "\n").dropFirst() {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
                if parts.count == 2, let cpu = Double(parts[0]) {
                    let comm = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !comm.isEmpty {
                        cpuMap[comm, default: 0.0] += cpu
                    }
                }
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let runningApps = NSWorkspace.shared.runningApplications.filter { app in
                    guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
                    if includeSystem {
                        return app.activationPolicy == .regular || app.activationPolicy == .accessory
                    } else {
                        return app.activationPolicy == .regular
                    }
                }

                var detected: [HighEnergyApp] = []
                var icons: [String: NSImage] = [:]
                var matchedNames: Set<String> = []

                for app in runningApps {
                    guard let name = app.localizedName, !name.isEmpty else { continue }
                    if ignoredSet.contains(name.lowercased()) { continue }
                    guard !matchedNames.contains(name) else { continue }
                    matchedNames.insert(name)

                    let bundleName = app.bundleURL?.lastPathComponent.replacingOccurrences(of: ".app", with: "") ?? name

                    var total = (cpuMap[name] ?? 0.0)
                    if bundleName != name {
                        total += (cpuMap[bundleName] ?? 0.0)
                    }
                    for (k, v) in cpuMap where k != name && k != bundleName {
                        if k.hasPrefix(name) || k.hasPrefix(bundleName) {
                            total += v
                        }
                    }

                    let impact: EnergyImpactLevel
                    if total >= veryHighThreshold {
                        impact = .veryHigh
                    } else if total >= highThreshold {
                        impact = .high
                    } else if total >= max(1.0, highThreshold * 0.4) {
                        impact = .moderate
                    } else {
                        impact = .low
                    }

                    detected.append(HighEnergyApp(name: name, impact: impact, cpuUsage: total))
                    if let icon = app.icon {
                        icons[name] = icon
                    }
                }

                if includeSystem {
                    let sysCandidates = ["WindowServer", "kernel_task", "mds_stores", "cloudd", "coreaudiod"]
                    for sysName in sysCandidates where !ignoredSet.contains(sysName.lowercased()) {
                        if let cpu = cpuMap[sysName], cpu >= highThreshold * 0.5 {
                            let impact: EnergyImpactLevel = cpu >= veryHighThreshold ? .veryHigh : (cpu >= highThreshold ? .high : .moderate)
                            detected.append(HighEnergyApp(name: sysName, impact: impact, cpuUsage: cpu))
                        }
                    }
                }

                detected.sort { $0.cpuUsage > $1.cpuUsage }

                var slots: [HighEnergyApp] = Array(detected.prefix(4))
                while slots.count < 4 {
                    let idx = slots.count
                    slots.append(
                        HighEnergyApp(
                            id: "empty-slot-\(idx)",
                            name: "Нет высокой нагрузки",
                            impact: .low,
                            cpuUsage: 0.0,
                            isPlaceholder: true
                        )
                    )
                }

                self.topFourSlots = slots
                self.appIcons = icons
            }
        }
    }
}
