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
        // Test write attempt (or check if root)
        if getuid() == 0 {
            status = .activePrivileged
        } else {
            // Check if privileged helper tool exists
            let helperPath = "/Library/PrivilegedHelperTools/com.voltcontrol.helper"
            if FileManager.default.fileExists(atPath: helperPath) {
                status = .activePrivileged
            } else {
                status = .userModeMonitoring
            }
        }
    }

    /// Read an SMC key as raw bytes
    public func readBytes(key: String) -> [UInt8]? {
        guard connection != 0 else { return nil }

        // Step 1: Query Key Info
        var infoIn = SMCParamStruct()
        infoIn.key = fourCharCode(key)
        infoIn.data8 = 9 // SMC_CMD_READ_KEYINFO
        var infoOut = SMCParamStruct()
        var sz = MemoryLayout<SMCParamStruct>.stride
        let krInfo = IOConnectCallStructMethod(connection, 2, &infoIn, sz, &infoOut, &sz)
        guard krInfo == kIOReturnSuccess && infoOut.result == 0 else {
            return nil
        }

        let size = Int(infoOut.keyInfo.dataSize)

        // Step 2: Read Bytes
        var readIn = SMCParamStruct()
        readIn.key = fourCharCode(key)
        readIn.keyInfo.dataSize = infoOut.keyInfo.dataSize
        readIn.data8 = 5 // SMC_CMD_READ_BYTES
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

        // Query key info first
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
        writeIn.keyInfo.dataSize = infoOut.keyInfo.dataSize
        writeIn.data8 = 6 // SMC_CMD_WRITE_BYTES

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

    /// Sets charge inhibit state: true = stop charging (AC bypass), false = resume charging
    @discardableResult
    public func setChargeInhibited(_ inhibit: Bool) -> Bool {
        // If we are root:
        if getuid() == 0 {
            // Apple Silicon SMC keys
            let value: UInt8 = inhibit ? 0x02 : 0x00
            let resCH0B = writeBytes(key: "CH0B", bytes: [value])
            let resCH0C = writeBytes(key: "CH0C", bytes: [value])
            return resCH0B || resCH0C
        }

        // Check if helper daemon is installed
        let helperPath = "/Library/PrivilegedHelperTools/com.voltcontrol.helper"
        if FileManager.default.fileExists(atPath: helperPath) {
            let cmd = "\(helperPath) \(inhibit ? "inhibit" : "enable")"
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/sh")
            proc.arguments = ["-c", cmd]
            try? proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        }

        return false
    }

    /// Sets hardware charge limit percentage (e.g. 80 on Intel BCLM or Apple Silicon B0CM)
    @discardableResult
    public func setHardwareChargeLimit(percentage: Int) -> Bool {
        let val = UInt8(clamping: percentage)
        if getuid() == 0 {
            let resB0CM = writeBytes(key: "B0CM", bytes: [val])
            let resBCLM = writeBytes(key: "BCLM", bytes: [val])
            return resB0CM || resBCLM
        }
        return false
    }
}
