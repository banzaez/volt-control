import Foundation
import VoltCore

public struct SMCSensorReadings: Sendable {
    public let sbap: Double?
    public let pdtr: Double?
    public let pstr: Double?
    public let tb0t: Double?

    public init(sbap: Double? = nil, pdtr: Double? = nil, pstr: Double? = nil, tb0t: Double? = nil) {
        self.sbap = sbap
        self.pdtr = pdtr
        self.pstr = pstr
        self.tb0t = tb0t
    }
}

public final class SMCSensors: @unchecked Sendable {
    public static let shared = SMCSensors()

    private let smc = SMCConnection()

    public init() {
        _ = smc.open()
    }

    public func readPowerAndTemp() -> SMCSensorReadings {
        SMCSensorReadings(
            sbap: smc.readFloat(key: "SBAP"),
            pdtr: smc.readFloat(key: "PDTR"),
            pstr: smc.readFloat(key: "PSTR"),
            tb0t: smc.readFloat(key: "TB0T")
        )
    }
}
