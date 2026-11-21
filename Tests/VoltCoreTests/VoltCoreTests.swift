import Foundation
import Testing
@testable import VoltCore

@Suite("VoltCore Tests")
struct VoltCoreTests {
    @Test("FourCC encode and decode")
    func testFourCC() {
        let keys = ["CHIE", "CHTE", "CH0B", "CH0C", "CH0I", "B0CM", "SBAP", "PDTR"]
        for key in keys {
            let encoded = FourCC.encode(key)
            #expect(FourCC.decode(encoded) == key)
        }
    }

    @Test("SMCParamStruct memory layout matches AppleSMC driver")
    func testSMCParamStructLayout() {
        #expect(MemoryLayout<SMCParamStruct>.stride == 80)
        #expect(MemoryLayout<SMCParamStruct>.offset(of: \SMCParamStruct.result) == 40)
        #expect(MemoryLayout<SMCParamStruct>.offset(of: \SMCParamStruct.data32) == 44)
        #expect(MemoryLayout<SMCParamStruct>.offset(of: \SMCParamStruct.bytes) == 48)
    }

    @Test("ChargeCapabilities and ChargeMode Codable")
    func testCodable() throws {
        let caps = ChargeCapabilities(
            inhibitMethod: .chte,
            adapterMethod: .chie,
            diagnostics: ["CHIE": "writable value=00", "CHTE": "writable value=00 00 00 00"]
        )
        let data = try JSONEncoder().encode(caps)
        let decoded = try JSONDecoder().decode(ChargeCapabilities.self, from: data)
        #expect(decoded == caps)
        #expect(decoded.canInhibit == true)
        #expect(decoded.canDisableAdapter == true)

        #expect(ChargeMode(rawValue: 0) == .normal)
        #expect(ChargeMode(rawValue: 1) == .inhibit)
        #expect(ChargeMode(rawValue: 2) == .discharge)
        #expect(ChargeMode(rawValue: 99) == nil)
    }
}
