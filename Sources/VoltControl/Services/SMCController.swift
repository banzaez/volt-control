import Foundation
import IOKit

public struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

public struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

public struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

public struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
                0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    )
}

public enum SMCStatus {
    case activePrivileged
    case userModeMonitoring
    case unsupported
}

public final class SMCController: @unchecked Sendable {
    public static let shared = SMCController()

    private var connection: io_connect_t = 0
    public private(set) var status: SMCStatus = .userModeMonitoring

    public var isPrivileged: Bool {
        status == .activePrivileged
    }

    private init() {
        openSMC()
        verifyPrivileges()
    }

    deinit {
        closeSMC()
    }

    private func openSMC() {
        let smcService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard smcService != 0 else {
            status = .unsupported
            return
        }
        let kr = IOServiceOpen(smcService, mach_task_self_, 0, &connection)
        IOObjectRelease(smcService)
        if kr != kIOReturnSuccess {
            status = .unsupported
        }
    }

    private func closeSMC() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    private func fourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }

    public func verifyPrivileges() {
        if getuid() == 0 {
            status = .activePrivileged
            return
        }

        let helperPath = "/Library/PrivilegedHelperTools/com.voltcontrol.helper"
        guard FileManager.default.isExecutableFile(atPath: helperPath) else {
            status = .userModeMonitoring
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: helperPath)
        proc.arguments = ["status"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                status = .activePrivileged
            } else {
                status = .userModeMonitoring
            }
        } catch {
            status = .userModeMonitoring
        }
    }

    @discardableResult
    public func installPrivilegedHelper() -> (Bool, String) {
        let targetPath = "/Library/PrivilegedHelperTools/com.voltcontrol.helper"
        let bundledHelper = Bundle.main.url(forResource: "com.voltcontrol.helper", withExtension: nil)?.path
            ?? "\(Bundle.main.bundlePath)/Contents/Resources/com.voltcontrol.helper"
        let releaseHelper = ".build/release/VoltControlHelper"
        let debugHelper = ".build/debug/VoltControlHelper"

        let sourcePath: String
        if FileManager.default.fileExists(atPath: bundledHelper) {
            sourcePath = bundledHelper
        } else if FileManager.default.fileExists(atPath: releaseHelper) {
            sourcePath = releaseHelper
        } else if FileManager.default.fileExists(atPath: debugHelper) {
            sourcePath = debugHelper
        } else {
            return (false, "Бинарник com.voltcontrol.helper не найден в бандле")
        }

        let cmd = "mkdir -p /Library/PrivilegedHelperTools && cp -f '\(sourcePath)' '\(targetPath)' && chown root:wheel '\(targetPath)' && chmod 4755 '\(targetPath)'"
        let script = "osascript -e 'do shell script \"\(cmd)\" with administrator privileges'"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                verifyPrivileges()
                return (status == .activePrivileged, "Хелпер успешно установлен")
            } else {
                return (false, "Установка отменена пользователем")
            }
        } catch {
            return (false, "Ошибка запуска: \(error.localizedDescription)")
        }
    }

    /// Reads a 4-byte IEEE-754 float SMC key (such as PSTR for system watts, PDTR for adapter watts)
    public func readFloat(key: String) -> Double? {
        guard connection != 0 else { return nil }

        var infoIn = SMCParamStruct()
        infoIn.key = fourCharCode(key)
        infoIn.data8 = 9
        var infoOut = SMCParamStruct()
        var sz = MemoryLayout<SMCParamStruct>.stride
        let krInfo = IOConnectCallStructMethod(connection, 2, &infoIn, sz, &infoOut, &sz)
        guard krInfo == kIOReturnSuccess && infoOut.result == 0 && infoOut.keyInfo.dataSize == 4 else {
            return nil
        }

        var readIn = SMCParamStruct()
        readIn.key = fourCharCode(key)
        readIn.keyInfo.dataSize = 4
        readIn.data8 = 5
        var readOut = SMCParamStruct()
        var rSz = MemoryLayout<SMCParamStruct>.stride
        let krRead = IOConnectCallStructMethod(connection, 2, &readIn, rSz, &readOut, &rSz)
        guard krRead == kIOReturnSuccess && readOut.result == 0 else {
            return nil
        }

        let val = withUnsafeBytes(of: readOut.bytes) { ptr in
            ptr.load(as: Float.self)
        }
        guard val.isFinite else { return nil }
        return Double(val)
    }

    /// Read an SMC key as raw bytes
    public func readBytes(key: String) -> [UInt8]? {
        guard connection != 0 else { return nil }

        var infoIn = SMCParamStruct()
        infoIn.key = fourCharCode(key)
        infoIn.data8 = 9
        var infoOut = SMCParamStruct()
        var sz = MemoryLayout<SMCParamStruct>.stride
        let krInfo = IOConnectCallStructMethod(connection, 2, &infoIn, sz, &infoOut, &sz)
        guard krInfo == kIOReturnSuccess && infoOut.result == 0 else {
            return nil
        }

        let size = Int(infoOut.keyInfo.dataSize)

        var readIn = SMCParamStruct()
        readIn.key = fourCharCode(key)
        readIn.keyInfo.dataSize = infoOut.keyInfo.dataSize
        readIn.data8 = 5
        var readOut = SMCParamStruct()
        var rSz = MemoryLayout<SMCParamStruct>.stride
        let krRead = IOConnectCallStructMethod(connection, 2, &readIn, rSz, &readOut, &rSz)
        guard krRead == kIOReturnSuccess && readOut.result == 0 else {
            return nil
        }

        let mirror = Mirror(reflecting: readOut.bytes)
        return mirror.children.prefix(size).compactMap { $0.value as? UInt8 }
    }

    /// Direct write to SMC key (requires root/privileges)
    public func writeBytes(key: String, bytes: [UInt8]) -> Bool {
        guard connection != 0 else { return false }

        var infoIn = SMCParamStruct()
        infoIn.key = fourCharCode(key)
        infoIn.data8 = 9
        var infoOut = SMCParamStruct()
        var sz = MemoryLayout<SMCParamStruct>.stride
        let krInfo = IOConnectCallStructMethod(connection, 2, &infoIn, sz, &infoOut, &sz)
        guard krInfo == kIOReturnSuccess && infoOut.result == 0 else {
            return false
        }

        var writeIn = SMCParamStruct()
        writeIn.key = fourCharCode(key)
        writeIn.keyInfo = infoOut.keyInfo
        writeIn.data8 = 6

        var tupleBytes = writeIn.bytes
        withUnsafeMutableBytes(of: &tupleBytes) { ptr in
            for (i, b) in bytes.prefix(Int(infoOut.keyInfo.dataSize)).enumerated() {
                ptr[i] = b
            }
        }
        writeIn.bytes = tupleBytes

        var writeOut = SMCParamStruct()
        var wSz = MemoryLayout<SMCParamStruct>.stride
        let krWrite = IOConnectCallStructMethod(connection, 2, &writeIn, wSz, &writeOut, &wSz)
        return krWrite == kIOReturnSuccess && writeOut.result == 0
    }

    // MARK: - Charge Control Actions
    @discardableResult
    public func pauseCharging() -> Bool {
        runHelperCommand(["pause"])
    }

    @discardableResult
    public func forceDischarge() -> Bool {
        runHelperCommand(["discharge"])
    }

    @discardableResult
    public func setHardwareChargeLimit(percentage: Int) -> Bool {
        runHelperCommand(["limit", "\(percentage)"])
    }

    @discardableResult
    public func resumeCharging() -> Bool {
        runHelperCommand(["enable"])
    }

    @discardableResult
    public func setChargeInhibited(_ inhibit: Bool, limit: Int = 80) -> Bool {
        if inhibit {
            return pauseCharging()
        } else {
            return setHardwareChargeLimit(percentage: limit)
        }
    }

    private func runHelperCommand(_ args: [String]) -> Bool {
        if getuid() == 0 {
            return executeDirect(command: args[0], value: args.count > 1 ? Int(args[1]) : nil)
        }

        let helperPath = "/Library/PrivilegedHelperTools/com.voltcontrol.helper"
        guard FileManager.default.isExecutableFile(atPath: helperPath) else {
            return false
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: helperPath)
        proc.arguments = args
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func executeDirect(command: String, value: Int?) -> Bool {
        switch command {
        case "pause", "inhibit":
            let okB0CM = writeBytes(key: "B0CM", bytes: [0])
            _ = writeBytes(key: "CHIE", bytes: [0x00])
            let okCH0B = writeBytes(key: "CH0B", bytes: [0x02])
            _ = writeBytes(key: "CH0C", bytes: [0x02])
            return okB0CM || okCH0B
        case "discharge":
            _ = writeBytes(key: "B0CM", bytes: [0])
            let okCHIE = writeBytes(key: "CHIE", bytes: [0x01])
            let okCH0I = writeBytes(key: "CH0I", bytes: [0x01])
            _ = writeBytes(key: "CH0J", bytes: [0x01])
            return okCHIE || okCH0I
        case "limit":
            let val = UInt8(clamping: value ?? 80)
            let okB0CM = writeBytes(key: "B0CM", bytes: [val])
            let okBCLM = writeBytes(key: "BCLM", bytes: [val])
            _ = writeBytes(key: "CHIE", bytes: [0x00])
            let okCH0B = writeBytes(key: "CH0B", bytes: [0x00])
            _ = writeBytes(key: "CH0C", bytes: [0x00])
            return okB0CM || okBCLM || okCH0B
        case "enable", "resume", "topup":
            let okB0CM = writeBytes(key: "B0CM", bytes: [100])
            let okBCLM = writeBytes(key: "BCLM", bytes: [100])
            _ = writeBytes(key: "CHIE", bytes: [0x00])
            let okCH0B = writeBytes(key: "CH0B", bytes: [0x00])
            _ = writeBytes(key: "CH0C", bytes: [0x00])
            return okB0CM || okBCLM || okCH0B
        default:
            return false
        }
    }
}
