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

private struct ProcessRow: Sendable {
    let pid: Int32
    let ppid: Int32
    let cpu: Double
    let comm: String
}

@MainActor
@Observable
public final class HighEnergyAppService {
    public static let shared = HighEnergyAppService()

    /// Always contains exactly 3 items so the menu layout never jumps
    public private(set) var topThreeSlots: [HighEnergyApp] = [
        HighEnergyApp(id: "slot-0", name: "—", impact: .low, cpuUsage: 0, isPlaceholder: true),
        HighEnergyApp(id: "slot-1", name: "—", impact: .low, cpuUsage: 0, isPlaceholder: true),
        HighEnergyApp(id: "slot-2", name: "—", impact: .low, cpuUsage: 0, isPlaceholder: true)
    ]

    public var hasRealApps: Bool {
        topThreeSlots.contains(where: { !$0.isPlaceholder })
    }

    public private(set) var appIcons: [String: NSImage] = [:]

    @ObservationIgnored private var timer: Timer?
    public private(set) var isMenuVisible: Bool = false

    private init() {}

    public func setMenuVisible(_ visible: Bool) {
        guard self.isMenuVisible != visible else { return }
        self.isMenuVisible = visible
        if visible {
            refresh()
            scheduleTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    public func scheduleTimer() {
        guard isMenuVisible else { return }
        timer?.invalidate()
        let interval = max(2.0, AppSettings.shared.processScanIntervalSeconds)
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isMenuVisible else { return }
                self.refresh()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }

    public func refresh() {
        let highThreshold = AppSettings.shared.highEnergyThresholdCPU
        let veryHighThreshold = max(highThreshold + 2.0, AppSettings.shared.veryHighEnergyThresholdCPU)
        let includeSystem = AppSettings.shared.includeSystemProcesses
        let showModerate = AppSettings.shared.showModerateEnergyApps
        let showLow = AppSettings.shared.showLowEnergyApps
        let ignoredSet = AppSettings.shared.parsedIgnoredApps()

        Task.detached(priority: .utility) { [weak self] in
            let rows = Self.readProcesses()
            guard !rows.isEmpty else { return }

            var childrenByParent: [Int32: [Int32]] = [:]
            var cpuByPid: [Int32: Double] = [:]
            var cpuByComm: [String: Double] = [:]

            for row in rows {
                childrenByParent[row.ppid, default: []].append(row.pid)
                cpuByPid[row.pid] = row.cpu
                cpuByComm[row.comm, default: 0.0] += row.cpu
            }

            func totalCPUForTree(rootPid: Int32) -> Double {
                var stack: [Int32] = [rootPid]
                var visited = Set<Int32>()
                var sum = 0.0
                while let current = stack.popLast() {
                    guard visited.insert(current).inserted else { continue }
                    sum += cpuByPid[current] ?? 0.0
                    if let children = childrenByParent[current] {
                        stack.append(contentsOf: children)
                    }
                }
                return sum
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
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
                var matchedIDs = Set<String>()

                for app in runningApps {
                    guard let name = app.localizedName, !name.isEmpty else { continue }
                    if ignoredSet.contains(name.lowercased()) { continue }

                    let appID = app.bundleIdentifier ?? name
                    guard matchedIDs.insert(appID).inserted else { continue }

                    let total = totalCPUForTree(rootPid: app.processIdentifier)
                    let impact = Self.classifyImpact(
                        cpu: total,
                        highThreshold: highThreshold,
                        veryHighThreshold: veryHighThreshold
                    )

                    if Self.shouldInclude(impact: impact, showModerate: showModerate, showLow: showLow) {
                        detected.append(HighEnergyApp(id: appID, name: name, impact: impact, cpuUsage: total))
                        if let icon = app.icon {
                            icons[appID] = icon
                        }
                    }
                }

                if includeSystem {
                    let sysCandidates = ["WindowServer", "kernel_task", "mds_stores", "cloudd", "coreaudiod"]
                    for sysName in sysCandidates where !ignoredSet.contains(sysName.lowercased()) {
                        if let cpu = cpuByComm[sysName], cpu >= highThreshold * 0.5 {
                            let impact = Self.classifyImpact(
                                cpu: cpu,
                                highThreshold: highThreshold,
                                veryHighThreshold: veryHighThreshold
                            )
                            if Self.shouldInclude(impact: impact, showModerate: showModerate, showLow: showLow) {
                                detected.append(HighEnergyApp(id: "sys:\(sysName)", name: sysName, impact: impact, cpuUsage: cpu))
                            }
                        }
                    }
                }

                detected.sort { $0.cpuUsage > $1.cpuUsage }

                var slots: [HighEnergyApp] = Array(detected.prefix(3))
                while slots.count < 3 {
                    let idx = slots.count
                    slots.append(
                        HighEnergyApp(
                            id: "empty-slot-\(idx)",
                            name: "—",
                            impact: .low,
                            cpuUsage: 0.0,
                            isPlaceholder: true
                        )
                    )
                }

                self.topThreeSlots = slots
                self.appIcons = icons
            }
        }
    }

    private nonisolated static func readProcesses() -> [ProcessRow] {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-Aeo", "pid=,ppid=,%cpu=,comm="]
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var rows: [ProcessRow] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count == 4,
                  let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1]),
                  let cpu = Double(parts[2].replacingOccurrences(of: ",", with: ".")) else {
                continue
            }
            let rawComm = String(parts[3]).trimmingCharacters(in: .whitespacesAndNewlines)
            let commName = URL(fileURLWithPath: rawComm).lastPathComponent
            if !commName.isEmpty {
                rows.append(ProcessRow(pid: pid, ppid: ppid, cpu: cpu, comm: commName))
            }
        }
        return rows
    }

    private nonisolated static func classifyImpact(cpu: Double, highThreshold: Double, veryHighThreshold: Double) -> EnergyImpactLevel {
        if cpu >= veryHighThreshold {
            return .veryHigh
        } else if cpu >= highThreshold {
            return .high
        } else if cpu >= max(1.0, highThreshold * 0.4) {
            return .moderate
        } else {
            return .low
        }
    }

    private nonisolated static func shouldInclude(impact: EnergyImpactLevel, showModerate: Bool, showLow: Bool) -> Bool {
        switch impact {
        case .veryHigh, .high: return true
        case .moderate: return showModerate
        case .low: return showLow
        }
    }
}
