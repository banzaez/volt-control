import AppKit
import Foundation

public struct HighEnergyApp: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let energyLevel: String
    public let cpuUsage: Double
}

@MainActor
@Observable
public final class HighEnergyAppService {
    public static let shared = HighEnergyAppService()

    public private(set) var apps: [HighEnergyApp] = []
    public private(set) var appIcons: [String: NSImage] = [:]

    private var timer: Timer?

    private init() {
        start()
    }

    public func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    public func refresh() {
        // Run ps in background thread to avoid blocking UI
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let pipe = Pipe()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/ps")
            proc.arguments = ["-Aceo", "%cpu,comm"]
            proc.standardOutput = pipe
            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            var cpuMap: [String: Double] = [:]
            for line in output.components(separatedBy: "\n").dropFirst() {
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
                if parts.count == 2, let cpu = Double(parts[0]) {
                    let comm = String(parts[1])
                    cpuMap[comm, default: 0.0] += cpu
                }
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let runningApps = NSWorkspace.shared.runningApplications.filter {
                    $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
                }

                var detected: [HighEnergyApp] = []
                var icons: [String: NSImage] = [:]

                for app in runningApps {
                    guard let name = app.localizedName, !name.isEmpty else { continue }
                    let bundleName = app.bundleURL?.lastPathComponent.replacingOccurrences(of: ".app", with: "") ?? name

                    // Match CPU usage
                    var total = (cpuMap[name] ?? 0.0) + (cpuMap[bundleName] ?? 0.0)
                    for (k, v) in cpuMap where k.contains(name) || name.contains(k) {
                        if k != name && k != bundleName {
                            total += v
                        }
                    }

                    if total >= 3.0 {
                        let level: String
                        if total >= 20.0 {
                            level = "Очень высокий"
                        } else if total >= 10.0 {
                            level = "Высокий"
                        } else {
                            level = "Умеренный"
                        }
                        detected.append(HighEnergyApp(name: name, energyLevel: level, cpuUsage: total))
                        if let icon = app.icon {
                            icons[name] = icon
                        }
                    }
                }

                // Sort by CPU descending
                detected.sort { $0.cpuUsage > $1.cpuUsage }
                self.apps = Array(detected.prefix(3))
                self.appIcons = icons
            }
        }
    }
}
