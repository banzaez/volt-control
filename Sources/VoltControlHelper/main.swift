#if !arch(arm64)
#error("VoltControl поддерживает только Apple Silicon")
#endif

import Foundation
import IOKit.ps
import OSLog
import Security
import VoltCore

private let logger = Logger(subsystem: VoltHelperConstants.machServiceName, category: "daemon")

final class HelperService: NSObject, VoltHelperProtocol, @unchecked Sendable {
    private let hardware = ChargeHardware()
    private let stateLock = NSLock()
    private var currentMode: ChargeMode = .normal
    private var watchdogTimer: DispatchSourceTimer?

    override init() {
        super.init()
        cleanupLegacyHelper()
        _ = hardware.probe()
        _ = hardware.apply(.normal)
        startWatchdog()
    }

    func resetToNormal(reason: String) {
        let shouldReset = stateLock.withLock { () -> Bool in
            let wasNonNormal = currentMode != .normal
            currentMode = .normal
            return wasNonNormal
        }
        if shouldReset {
            logger.info("Resetting charge mode to normal: \(reason, privacy: .public)")
        }
        _ = hardware.apply(.normal)
    }

    func protocolVersion(reply: @escaping @Sendable (Int) -> Void) {
        reply(VoltHelperConstants.protocolVersion)
    }

    func capabilities(reply: @escaping @Sendable (Data) -> Void) {
        let caps = hardware.capabilities()
        let data = (try? JSONEncoder().encode(caps)) ?? Data()
        reply(data)
    }

    func setMode(_ raw: Int, reply: @escaping @Sendable (Bool, String?) -> Void) {
        guard let mode = ChargeMode(rawValue: raw) else {
            reply(false, "Неизвестный режим: \(raw)")
            return
        }

        switch hardware.apply(mode) {
        case .success:
            stateLock.withLock { currentMode = mode }
            logger.info("Applied charge mode \(mode.rawValue, privacy: .public)")
            reply(true, nil)
        case .failure(let err):
            let message: String
            switch err {
            case .unsupported(let m):
                message = "Режим \(m.localizedName) не поддерживается на этой модели"
            case .smcWriteFailed(let details):
                message = "Ошибка записи SMC: \(details)"
            }
            logger.error("Failed to apply charge mode: \(message, privacy: .public)")
            reply(false, message)
        }
    }

    func diagnose(reply: @escaping @Sendable (String) -> Void) {
        let caps = hardware.probe()
        var lines: [String] = [
            "inhibit=\(caps.inhibitMethod?.rawValue ?? "none")",
            "adapter=\(caps.adapterMethod?.rawValue ?? "none")"
        ]
        for key in caps.diagnostics.keys.sorted() {
            if let val = caps.diagnostics[key] {
                lines.append("\(key): \(val)")
            }
        }
        reply(lines.joined(separator: "\n"))
    }

    private func cleanupLegacyHelper() {
        let legacyPath = VoltHelperConstants.legacyHelperPath
        if FileManager.default.fileExists(atPath: legacyPath) {
            do {
                try FileManager.default.removeItem(atPath: legacyPath)
                logger.info("Removed legacy setuid helper at \(legacyPath, privacy: .public)")
            } catch {
                logger.warning("Failed to remove legacy helper: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in
            self?.checkWatchdog()
        }
        timer.resume()
        watchdogTimer = timer
    }

    private func checkWatchdog() {
        let mode = stateLock.withLock { currentMode }
        guard mode == .discharge else { return }
        guard let level = readBatteryPercentage() else { return }
        if level <= 10 {
            resetToNormal(reason: "Watchdog discharge floor reached (\(level)%)")
        }
    }

    private func readBatteryPercentage() -> Int? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let cap = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
               maxCap > 0 {
                return Int((Double(cap) / Double(maxCap)) * 100.0)
            }
        }
        return nil
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let service: HelperService
    private let codeSigningRequirement: String

    init(service: HelperService) {
        self.service = service
        self.codeSigningRequirement = Self.buildCodeSigningRequirement()
        super.init()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.setCodeSigningRequirement(codeSigningRequirement)
        newConnection.exportedInterface = NSXPCInterface(with: VoltHelperProtocol.self)
        newConnection.exportedObject = service

        newConnection.invalidationHandler = { [service] in
            service.resetToNormal(reason: "XPC connection invalidated")
        }
        newConnection.interruptionHandler = { [service] in
            service.resetToNormal(reason: "XPC connection interrupted")
        }

        newConnection.resume()
        return true
    }

    private static func buildCodeSigningRequirement() -> String {
        var selfCode: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &selfCode) == errSecSuccess, let code = selfCode else {
            logger.warning("SecCodeCopySelf failed; falling back to bundle identifier requirement")
            return "identifier \"\(VoltHelperConstants.appBundleID)\""
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess, let sCode = staticCode else {
            logger.warning("SecCodeCopyStaticCode failed; falling back to bundle identifier requirement")
            return "identifier \"\(VoltHelperConstants.appBundleID)\""
        }

        var infoCF: CFDictionary?
        guard SecCodeCopySigningInformation(sCode, SecCSFlags(rawValue: kSecCSSigningInformation), &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any],
              let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String,
              !teamID.isEmpty else {
            logger.warning("Helper has no TeamIdentifier (ad-hoc build); using bundle identifier requirement only")
            return "identifier \"\(VoltHelperConstants.appBundleID)\""
        }

        logger.info("Enforcing TeamIdentifier requirement: \(teamID, privacy: .public)")
        return "identifier \"\(VoltHelperConstants.appBundleID)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
    }
}

let service = HelperService()
let delegate = ListenerDelegate(service: service)
let listener = NSXPCListener(machServiceName: VoltHelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()

dispatchMain()
