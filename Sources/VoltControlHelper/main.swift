import Foundation
import IOKit
import Darwin

// Elevate privileges when executed as a setuid-root binary
setuid(0)
setgid(0)

func fourCharCode(_ str: String) -> UInt32 {
    var result: UInt32 = 0
    for char in str.utf8.prefix(4) {
        result = (result << 8) | UInt32(char)
    }
    return result
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCParamStruct {
    var key: UInt32 = 0
    var vers: (UInt8, UInt8, UInt8, UInt8, UInt16) = (0, 0, 0, 0, 0)
    var pLimitData: (UInt16, UInt16, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0)
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
                0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

final class SMCHelper {
    private var connection: io_connect_t = 0

    init() {
        let smcService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if smcService != 0 {
            _ = IOServiceOpen(smcService, mach_task_self_, 0, &connection)
            IOObjectRelease(smcService)
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func readByte(key: String) -> UInt8? {
        guard connection != 0 else { return nil }

        var infoIn = SMCParamStruct()
        infoIn.key = fourCharCode(key)
        infoIn.data8 = 9
        var infoOut = SMCParamStruct()
        var sz = MemoryLayout<SMCParamStruct>.stride
        let krInfo = IOConnectCallStructMethod(connection, 2, &infoIn, sz, &infoOut, &sz)
        guard krInfo == kIOReturnSuccess && infoOut.result == 0 else { return nil }

        var readIn = SMCParamStruct()
        readIn.key = fourCharCode(key)
        readIn.keyInfo = infoOut.keyInfo
        readIn.data8 = 5
        var readOut = SMCParamStruct()
        var rSz = MemoryLayout<SMCParamStruct>.stride
        let krRead = IOConnectCallStructMethod(connection, 2, &readIn, rSz, &readOut, &rSz)
        guard krRead == kIOReturnSuccess && readOut.result == 0 else { return nil }

        return readOut.bytes.0
    }

    func writeByte(key: String, value: UInt8) -> Bool {
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
        writeIn.bytes.0 = value

        var writeOut = SMCParamStruct()
        var wSz = MemoryLayout<SMCParamStruct>.stride
        let krWrite = IOConnectCallStructMethod(connection, 2, &writeIn, wSz, &writeOut, &wSz)
        return krWrite == kIOReturnSuccess && writeOut.result == 0
    }
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: com.voltcontrol.helper <status|pause|discharge|limit <percent>|enable>")
    exit(1)
}

let helper = SMCHelper()
let command = args[1]

switch command {
case "status":
    let b0cm = helper.readByte(key: "B0CM")
    let chie = helper.readByte(key: "CHIE")
    let chsc = helper.readByte(key: "CHSC")
    let bclm = helper.readByte(key: "BCLM")
    let ch0b = helper.readByte(key: "CH0B")
    let ch0c = helper.readByte(key: "CH0C")
    print("B0CM=\(b0cm.map(String.init) ?? "nil") CHIE=\(chie.map(String.init) ?? "nil") CHSC=\(chsc.map(String.init) ?? "nil") BCLM=\(bclm.map(String.init) ?? "nil") CH0B=\(ch0b.map(String.init) ?? "nil") CH0C=\(ch0c.map(String.init) ?? "nil")")
    exit(0)

case "pause", "inhibit":
    // AC Bypass: Stop charging battery, power MacBook from adapter
    let okB0CM = helper.writeByte(key: "B0CM", value: 0) // Limit = 0% stops charging on Apple Silicon
    let okCHIE = helper.writeByte(key: "CHIE", value: 0x00) // Keep adapter powering the system
    _ = helper.writeByte(key: "CHSC", value: 0x00)
    let okCH0B = helper.writeByte(key: "CH0B", value: 0x02) // Intel inhibit
    let okCH0C = helper.writeByte(key: "CH0C", value: 0x02) // Intel inhibit
    _ = helper.writeByte(key: "CH0I", value: 0x00)
    _ = helper.writeByte(key: "CH0J", value: 0x00)
    let success = okB0CM || okCHIE || okCH0B || okCH0C
    exit(success ? 0 : 2)

case "discharge":
    // Force Discharge: Disconnect AC adapter power, run directly from battery ("Работать от батареи")
    let okB0CM = helper.writeByte(key: "B0CM", value: 0)
    let okCHIE = helper.writeByte(key: "CHIE", value: 0x01) // Force battery discharge on Apple Silicon
    let okCH0I = helper.writeByte(key: "CH0I", value: 0x01) // Force discharge
    _ = helper.writeByte(key: "CH0J", value: 0x01)
    let okCH0B = helper.writeByte(key: "CH0B", value: 0x02)
    _ = helper.writeByte(key: "CH0C", value: 0x02)
    let success = okCHIE || okCH0I || okB0CM || okCH0B
    exit(success ? 0 : 2)

case "limit":
    // Charge up to specified limit (e.g. 80%), then hold
    let percent = args.count >= 3 ? (UInt8(args[2]) ?? 80) : 80
    let okB0CM = helper.writeByte(key: "B0CM", value: percent)
    let okBCLM = helper.writeByte(key: "BCLM", value: percent)
    _ = helper.writeByte(key: "CHIE", value: 0x00)
    _ = helper.writeByte(key: "CH0I", value: 0x00)
    _ = helper.writeByte(key: "CH0J", value: 0x00)
    let okCH0B = helper.writeByte(key: "CH0B", value: 0x00)
    _ = helper.writeByte(key: "CH0C", value: 0x00)
    _ = helper.writeByte(key: "CHSC", value: 0x01)
    let success = okB0CM || okBCLM || okCH0B
    exit(success ? 0 : 2)

case "enable", "resume", "topup":
    // Full charge up to 100%
    let okB0CM = helper.writeByte(key: "B0CM", value: 100)
    let okBCLM = helper.writeByte(key: "BCLM", value: 100)
    _ = helper.writeByte(key: "CHIE", value: 0x00)
    _ = helper.writeByte(key: "CHSC", value: 0x01)
    let okCH0B = helper.writeByte(key: "CH0B", value: 0x00)
    _ = helper.writeByte(key: "CH0C", value: 0x00)
    _ = helper.writeByte(key: "CH0I", value: 0x00)
    _ = helper.writeByte(key: "CH0J", value: 0x00)
    let success = okB0CM || okBCLM || okCH0B
    exit(success ? 0 : 2)

default:
    exit(1)
}
