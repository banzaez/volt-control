import Foundation

public enum ChargeHardwareError: Error, Sendable, Equatable {
    case unsupported(ChargeMode)
    case smcWriteFailed(String)
}

public final class ChargeHardware: @unchecked Sendable {
    private let lock = NSLock()
    private let smc: SMCConnection
    private var cachedCapabilities: ChargeCapabilities?

    public init(smc: SMCConnection = SMCConnection()) {
        self.smc = smc
    }

    public func probe() -> ChargeCapabilities {
        lock.withLock {
            _ = smc.open()
            var diagnostics: [String: String] = [:]

            let probeKeys = ["CHTE", "CH0B", "CH0C", "CHIE", "CH0I", "B0CM"]
            var writableKeys = Set<String>()

            for key in probeKeys {
                let infoResult = smc.keyInfo(for: key)
                guard case .success(let info) = infoResult else {
                    diagnostics[key] = "absent"
                    continue
                }

                let readResult = smc.readBytes(key: key)
                guard case .success(let bytes) = readResult else {
                    diagnostics[key] = "read-error size=\(info.dataSize) type=\(FourCC.decode(info.dataType))"
                    continue
                }

                let hex = bytes.map { String(format: "%02x", $0) }.joined(separator: " ")

                // B0CM is never written during probe or control
                if key == "B0CM" {
                    diagnostics[key] = "readonly-probe value=\(hex) size=\(info.dataSize) type=\(FourCC.decode(info.dataType))"
                    continue
                }

                switch smc.write(key: key, bytes: bytes) {
                case .success:
                    writableKeys.insert(key)
                    diagnostics[key] = "writable value=\(hex) size=\(info.dataSize) type=\(FourCC.decode(info.dataType))"
                case .failure(let err):
                    diagnostics[key] = "readonly value=\(hex) err=\(err)"
                }
            }

            let inhibitMethod: InhibitMethod?
            if writableKeys.contains("CHTE") {
                inhibitMethod = .chte
            } else if writableKeys.contains("CH0B") && writableKeys.contains("CH0C") {
                inhibitMethod = .ch0bc
            } else {
                inhibitMethod = nil
            }

            let adapterMethod: AdapterMethod?
            if writableKeys.contains("CHIE") {
                adapterMethod = .chie
            } else if writableKeys.contains("CH0I") {
                adapterMethod = .ch0i
            } else {
                adapterMethod = nil
            }

            let caps = ChargeCapabilities(
                inhibitMethod: inhibitMethod,
                adapterMethod: adapterMethod,
                diagnostics: diagnostics
            )
            cachedCapabilities = caps
            return caps
        }
    }

    public func capabilities() -> ChargeCapabilities {
        if let cached = lock.withLock({ cachedCapabilities }) {
            return cached
        }
        return probe()
    }

    public func apply(_ mode: ChargeMode) -> Result<Void, ChargeHardwareError> {
        let caps = capabilities()
        return lock.withLock {
            _ = smc.open()

            switch mode {
            case .normal:
                // Best-effort restore: try all available write paths to ensure charging & adapter are re-enabled
                var failures: [String] = []
                if let inh = caps.inhibitMethod {
                    if case .failure(let e) = setInhibitLocked(false, method: inh) {
                        failures.append("inhibit=false: \(e)")
                    }
                }
                if let adp = caps.adapterMethod {
                    if case .failure(let e) = setAdapterDisabledLocked(false, method: adp) {
                        failures.append("adapter=on: \(e)")
                    }
                }
                return failures.isEmpty ? .success(()) : .failure(.smcWriteFailed(failures.joined(separator: "; ")))

            case .inhibit:
                guard let inh = caps.inhibitMethod else {
                    return .failure(.unsupported(.inhibit))
                }
                if let adp = caps.adapterMethod {
                    if case .failure(let e) = setAdapterDisabledLocked(false, method: adp) {
                        return .failure(.smcWriteFailed("adapter=on: \(e)"))
                    }
                }
                if case .failure(let e) = setInhibitLocked(true, method: inh) {
                    return .failure(.smcWriteFailed("inhibit=true: \(e)"))
                }
                return .success(())

            case .discharge:
                guard let adp = caps.adapterMethod else {
                    return .failure(.unsupported(.discharge))
                }
                if let inh = caps.inhibitMethod {
                    _ = setInhibitLocked(true, method: inh)
                }
                if case .failure(let e) = setAdapterDisabledLocked(true, method: adp) {
                    return .failure(.smcWriteFailed("adapter=off: \(e)"))
                }
                return .success(())
            }
        }
    }

    private func setInhibitLocked(_ inhibited: Bool, method: InhibitMethod) -> Result<Void, SMCError> {
        switch method {
        case .chte:
            let bytes: [UInt8] = inhibited ? [0x01, 0x00, 0x00, 0x00] : [0x00, 0x00, 0x00, 0x00]
            return smc.write(key: "CHTE", bytes: bytes)
        case .ch0bc:
            let val: UInt8 = inhibited ? 0x02 : 0x00
            if case .failure(let e) = smc.write(key: "CH0B", bytes: [val]) {
                return .failure(e)
            }
            return smc.write(key: "CH0C", bytes: [val])
        }
    }

    private func setAdapterDisabledLocked(_ disabled: Bool, method: AdapterMethod) -> Result<Void, SMCError> {
        switch method {
        case .chie:
            let val: UInt8 = disabled ? 0x08 : 0x00
            return smc.write(key: "CHIE", bytes: [val])
        case .ch0i:
            let val: UInt8 = disabled ? 0x01 : 0x00
            return smc.write(key: "CH0I", bytes: [val])
        }
    }
}
