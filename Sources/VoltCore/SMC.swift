#if !arch(arm64)
#error("VoltControl поддерживает только Apple Silicon")
#endif

import Foundation
import IOKit

public struct SMCVersion: Sendable {
    public var major: UInt8 = 0
    public var minor: UInt8 = 0
    public var build: UInt8 = 0
    public var reserved: UInt8 = 0
    public var release: UInt16 = 0

    public init() {}
}

public struct SMCPLimitData: Sendable {
    public var version: UInt16 = 0
    public var length: UInt16 = 0
    public var cpuPLimit: UInt32 = 0
    public var gpuPLimit: UInt32 = 0
    public var memPLimit: UInt32 = 0

    public init() {}
}

public struct SMCKeyInfoData: Sendable {
    public var dataSize: UInt32 = 0
    public var dataType: UInt32 = 0
    public var dataAttributes: UInt8 = 0

    public init() {}
}

public struct SMCParamStruct: Sendable {
    public var key: UInt32 = 0
    public var vers = SMCVersion()
    public var pLimitData = SMCPLimitData()
    public var keyInfo = SMCKeyInfoData()
    public var padding: UInt16 = 0
    public var result: UInt8 = 0
    public var status: UInt8 = 0
    public var data8: UInt8 = 0
    public var data32: UInt32 = 0
    public var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )

    public init() {}
}

public enum FourCC {
    public static func encode(_ string: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in string.utf8.prefix(4) {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    public static func decode(_ value: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}

public enum SMCError: Error, Sendable, Equatable {
    case serviceNotFound
    case openFailed(kern_return_t)
    case notConnected
    case keyNotFound(String)
    case readFailed(key: String, kernReturn: kern_return_t, smcResult: UInt8)
    case writeFailed(key: String, kernReturn: kern_return_t, smcResult: UInt8)
    case invalidDataSize(key: String, expected: Int, actual: Int)
}

public final class SMCConnection: @unchecked Sendable {
    private let lock = NSLock()
    private var connection: io_connect_t = 0
    private var keyInfoCache: [String: SMCKeyInfoData] = [:]

    public var isOpen: Bool {
        lock.withLock { connection != 0 }
    }

    public init() {}

    deinit {
        close()
    }

    @discardableResult
    public func open() -> Bool {
        lock.withLock {
            if connection != 0 { return true }
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
            guard service != 0 else { return false }
            defer { IOObjectRelease(service) }

            var conn: io_connect_t = 0
            let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
            guard kr == kIOReturnSuccess, conn != 0 else { return false }
            connection = conn
            return true
        }
    }

    public func close() {
        lock.withLock {
            if connection != 0 {
                IOServiceClose(connection)
                connection = 0
            }
            keyInfoCache.removeAll()
        }
    }

    public func keyInfo(for key: String) -> Result<SMCKeyInfoData, SMCError> {
        lock.withLock {
            if let cached = keyInfoCache[key] {
                return .success(cached)
            }
            guard ensureOpenLocked() else { return .failure(.notConnected) }

            var input = SMCParamStruct()
            input.key = FourCC.encode(key)
            input.data8 = 9 // kSMCGetKeyInfo
            var output = SMCParamStruct()
            var size = MemoryLayout<SMCParamStruct>.stride

            let kr = IOConnectCallStructMethod(connection, 2, &input, size, &output, &size)
            guard kr == kIOReturnSuccess, output.result == 0 else {
                return .failure(.keyNotFound(key))
            }
            keyInfoCache[key] = output.keyInfo
            return .success(output.keyInfo)
        }
    }

    public func readBytes(key: String) -> Result<[UInt8], SMCError> {
        lock.withLock {
            guard ensureOpenLocked() else { return .failure(.notConnected) }
            let info: SMCKeyInfoData
            switch keyInfoLocked(for: key) {
            case .success(let value):
                info = value
            case .failure(let error):
                return .failure(error)
            }

            let dataSize = Int(info.dataSize)
            guard dataSize > 0, dataSize <= 32 else {
                return .failure(.invalidDataSize(key: key, expected: 1...32 ~= dataSize ? dataSize : 1, actual: dataSize))
            }

            var input = SMCParamStruct()
            input.key = FourCC.encode(key)
            input.keyInfo.dataSize = info.dataSize
            input.data8 = 5 // kSMCReadKey
            var output = SMCParamStruct()
            var size = MemoryLayout<SMCParamStruct>.stride

            let kr = IOConnectCallStructMethod(connection, 2, &input, size, &output, &size)
            guard kr == kIOReturnSuccess, output.result == 0 else {
                return .failure(.readFailed(key: key, kernReturn: kr, smcResult: output.result))
            }

            let bytes = withUnsafeBytes(of: output.bytes) { rawPtr in
                Array(rawPtr.prefix(dataSize))
            }
            return .success(bytes)
        }
    }

    public func readFloat(key: String) -> Double? {
        switch readBytes(key: key) {
        case .success(let bytes) where bytes.count == 4:
            let val = bytes.withUnsafeBytes { $0.load(as: Float.self) }
            return val.isFinite ? Double(val) : nil
        default:
            return nil
        }
    }

    public func write(key: String, bytes: [UInt8]) -> Result<Void, SMCError> {
        lock.withLock {
            guard ensureOpenLocked() else { return .failure(.notConnected) }
            let info: SMCKeyInfoData
            switch keyInfoLocked(for: key) {
            case .success(let value):
                info = value
            case .failure(let error):
                return .failure(error)
            }

            let expected = Int(info.dataSize)
            guard expected > 0, expected <= 32, bytes.count == expected else {
                return .failure(.invalidDataSize(key: key, expected: expected, actual: bytes.count))
            }

            var input = SMCParamStruct()
            input.key = FourCC.encode(key)
            input.keyInfo = info
            input.data8 = 6 // kSMCWriteKey

            var tupleBytes = input.bytes
            withUnsafeMutableBytes(of: &tupleBytes) { ptr in
                for (index, byte) in bytes.enumerated() {
                    ptr[index] = byte
                }
            }
            input.bytes = tupleBytes

            var output = SMCParamStruct()
            var size = MemoryLayout<SMCParamStruct>.stride
            let kr = IOConnectCallStructMethod(connection, 2, &input, size, &output, &size)
            guard kr == kIOReturnSuccess, output.result == 0 else {
                return .failure(.writeFailed(key: key, kernReturn: kr, smcResult: output.result))
            }
            return .success(())
        }
    }

    private func ensureOpenLocked() -> Bool {
        if connection != 0 { return true }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard kr == kIOReturnSuccess, conn != 0 else { return false }
        connection = conn
        return true
    }

    private func keyInfoLocked(for key: String) -> Result<SMCKeyInfoData, SMCError> {
        if let cached = keyInfoCache[key] {
            return .success(cached)
        }
        var input = SMCParamStruct()
        input.key = FourCC.encode(key)
        input.data8 = 9
        var output = SMCParamStruct()
        var size = MemoryLayout<SMCParamStruct>.stride

        let kr = IOConnectCallStructMethod(connection, 2, &input, size, &output, &size)
        guard kr == kIOReturnSuccess, output.result == 0 else {
            return .failure(.keyNotFound(key))
        }
        keyInfoCache[key] = output.keyInfo
        return .success(output.keyInfo)
    }
}
