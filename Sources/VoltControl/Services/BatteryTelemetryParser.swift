import Foundation

public struct IOPSPowerSnapshot: Sendable {
    public var isACConnected: Bool
    public var isCharging: Bool

    public init(isACConnected: Bool = false, isCharging: Bool = false) {
        self.isACConnected = isACConnected
        self.isCharging = isCharging
    }
}

public struct BatteryReading: Sendable {
    public var currentPercentage: Int
    public var isCharging: Bool
    public var isACConnected: Bool
    public var isFullyCharged: Bool
    public var batteryPowerWatts: Double
    public var adapterPowerWatts: Double
    public var systemPowerWatts: Double
    public var voltageVolts: Double
    public var amperageMilliAmps: Int
    public var temperatureCelsius: Double?
    public var cycleCount: Int
    public var designCapacityMah: Int
    public var currentMaxCapacityMah: Int
    public var remainingCapacityMah: Int
    public var timeRemainingMinutes: Int?
}

public enum BatteryTelemetryParser {
    /// Safely converts an IOKit CFNumber (which may store negative values as 64-bit unsigned two's complement) into signed Int64
    public static func signedInt64(_ anyVal: Any?) -> Int64 {
        guard let num = anyVal as? NSNumber else { return 0 }
        return Int64(bitPattern: num.uint64Value)
    }

    /// Converts signed milliwatts from IOKit dictionary entry to Watts
    public static func signedMilliwattsToWatts(_ anyVal: Any?) -> Double {
        Double(signedInt64(anyVal)) / 1000.0
    }

    public static func parse(
        battDict: [String: Any],
        packDict: [String: Any],
        iops: IOPSPowerSnapshot,
        sensors: SMCSensorReadings,
        effectiveChargeLimit: Int,
        isTopUpActive: Bool
    ) -> BatteryReading {
        let level = battDict["CurrentCapacity"] as? Int ?? 0
        let bData = battDict["BatteryData"] as? [String: Any] ?? [:]
        let pDist = battDict["PowerDistribution"] as? [String: Any] ?? [:]
        let ptd = battDict["PowerTelemetryData"] as? [String: Any] ?? [:]
        let packBData = packDict["BatteryData"] as? [String: Any] ?? [:]

        // Signed telemetry values from PowerTelemetryData & BatteryData (in mW -> W)
        let ptdSystemPowerInWatts = max(0.0, signedMilliwattsToWatts(ptd["SystemPowerIn"]))
        let ptdSystemLoadWatts = max(0.0, signedMilliwattsToWatts(ptd["SystemLoad"]))
        let ptdBattWatts = signedMilliwattsToWatts(ptd["BatteryPower"])
        let bDataBattWatts = signedMilliwattsToWatts(bData["BatteryPower"])
        let ipdInputWatts = max(0.0, signedMilliwattsToWatts(pDist["IPDInputPower"]))

        let rawPDTR = max(0.0, (sensors.pdtr ?? 0.0) < 0.05 ? 0.0 : (sensors.pdtr ?? 0.0))
        let regExternalConnected = battDict["ExternalConnected"] as? Bool ?? false
        let isAC = regExternalConnected || iops.isACConnected || rawPDTR > 0.5 || ptdSystemPowerInWatts > 0.5

        let adapterWatts: Double
        let systemWatts: Double
        let battWatts: Double

        if let sbap = sensors.sbap, sensors.pdtr != nil {
            let cleanSBAP = abs(sbap) < 0.03 ? 0.0 : sbap
            let cleanPDTR = isAC ? max(rawPDTR, ptdSystemPowerInWatts, ipdInputWatts) : 0.0

            adapterWatts = cleanPDTR
            battWatts = -cleanSBAP

            let computedSys = cleanPDTR + cleanSBAP
            if computedSys > 0.2 {
                systemWatts = computedSys
            } else if let pstr = sensors.pstr, pstr > 0.2 {
                systemWatts = pstr
            } else if ptdSystemLoadWatts > 0.2 {
                systemWatts = ptdSystemLoadWatts
            } else {
                systemWatts = max(0.5, abs(cleanSBAP))
            }
        } else {
            if isAC {
                adapterWatts = max(rawPDTR, ptdSystemPowerInWatts, ipdInputWatts)
                battWatts = abs(ptdBattWatts) > 0.05 ? ptdBattWatts : bDataBattWatts
                if ptdSystemLoadWatts > 0.2 {
                    systemWatts = ptdSystemLoadWatts
                } else if let pstr = sensors.pstr, pstr > 0.2 {
                    systemWatts = pstr
                } else {
                    systemWatts = max(0.5, adapterWatts - max(0.0, battWatts))
                }
            } else {
                adapterWatts = 0.0
                let discharge = max(abs(ptdBattWatts), abs(bDataBattWatts), ptdSystemLoadWatts, sensors.pstr ?? 0.5)
                systemWatts = max(0.3, discharge)
                battWatts = -systemWatts
            }
        }

        let regIsCharging = battDict["IsCharging"] as? Bool ?? false
        let isChg = isAC && (regIsCharging || iops.isCharging || battWatts > 0.25)

        // Temperature: pack Temperature/100 -> batt Temperature/100 -> SMC TB0T -> nil
        let rawPackTemp = (packBData["Temperature"] as? NSNumber)?.doubleValue ?? 0.0
        let rawBattTemp = (battDict["Temperature"] as? NSNumber)?.doubleValue ?? 0.0
        let tempCelsius: Double?
        if rawPackTemp > 100 {
            tempCelsius = rawPackTemp / 100.0
        } else if rawBattTemp > 100 {
            tempCelsius = rawBattTemp / 100.0
        } else if let tb0t = sensors.tb0t, tb0t > 1.0 && tb0t < 120.0 {
            tempCelsius = tb0t
        } else {
            tempCelsius = nil
        }

        let fcc = (battDict["AppleRawMaxCapacity"] as? NSNumber)?.intValue
            ?? (bData["AppleRawMaxCapacity"] as? NSNumber)?.intValue
            ?? (bData["FullChargeCapacity"] as? NSNumber)?.intValue ?? 0
        let dc = (battDict["DesignCapacity"] as? NSNumber)?.intValue
            ?? (bData["DesignCapacity"] as? NSNumber)?.intValue ?? 0
        let remCap = (battDict["AppleRawCurrentCapacity"] as? NSNumber)?.intValue
            ?? (bData["RemainingCapacity"] as? NSNumber)?.intValue ?? 0

        let cycles = battDict["CycleCount"] as? Int
            ?? (bData["CycleCount"] as? NSNumber)?.intValue ?? 0
        let rawVolt = (battDict["Voltage"] as? NSNumber)?.doubleValue
            ?? (bData["Voltage"] as? NSNumber)?.doubleValue ?? 0.0
        let volts = rawVolt / 1000.0
        let amps = Int(signedInt64(battDict["Amperage"] ?? battDict["InstantAmperage"]))
        let fullyCharged = (battDict["FullyCharged"] as? Bool ?? false) || (level >= 100 && !isChg)

        let timeRemaining = computeTimeRemainingMinutes(
            isAC: isAC,
            isCharging: isChg,
            currentLevel: level,
            battDict: battDict,
            fcc: fcc,
            remCap: remCap,
            amps: amps,
            volts: volts,
            battWatts: battWatts,
            sysWatts: systemWatts,
            effectiveChargeLimit: effectiveChargeLimit,
            isTopUpActive: isTopUpActive
        )

        return BatteryReading(
            currentPercentage: level,
            isCharging: isChg,
            isACConnected: isAC,
            isFullyCharged: fullyCharged,
            batteryPowerWatts: battWatts,
            adapterPowerWatts: adapterWatts,
            systemPowerWatts: systemWatts,
            voltageVolts: volts,
            amperageMilliAmps: amps,
            temperatureCelsius: tempCelsius,
            cycleCount: cycles,
            designCapacityMah: dc,
            currentMaxCapacityMah: fcc,
            remainingCapacityMah: remCap,
            timeRemainingMinutes: timeRemaining
        )
    }

    private static func computeTimeRemainingMinutes(
        isAC: Bool,
        isCharging: Bool,
        currentLevel: Int,
        battDict: [String: Any],
        fcc: Int,
        remCap: Int,
        amps: Int,
        volts: Double,
        battWatts: Double,
        sysWatts: Double,
        effectiveChargeLimit: Int,
        isTopUpActive: Bool
    ) -> Int? {
        if !isAC {
            let iokitVal = (battDict["AvgTimeToEmpty"] as? Int)
                ?? (battDict["TimeRemaining"] as? Int)
                ?? (battDict["InstantTimeToEmpty"] as? Int)

            if let val = iokitVal, val > 0, val < 65535 {
                return val
            }

            let dischargeAmps = abs(amps) > 50 ? abs(amps) : Int((sysWatts / max(1.0, volts)) * 1000.0)
            if dischargeAmps > 50 && remCap > 0 {
                let estimatedMinutes = Int((Double(remCap) / Double(dischargeAmps)) * 60.0)
                if estimatedMinutes > 0 && estimatedMinutes < 2400 {
                    return estimatedMinutes
                }
            }
            return nil
        }

        guard isCharging else {
            return nil
        }

        let isFullTarget = isTopUpActive || effectiveChargeLimit >= 100
        if isFullTarget {
            let iokitVal = (battDict["AvgTimeToFull"] as? Int)
                ?? (battDict["TimeRemaining"] as? Int)

            if let val = iokitVal, val > 0, val < 65535 {
                return val
            }

            let chargeAmps = amps > 50 ? amps : Int((battWatts / max(1.0, volts)) * 1000.0)
            let neededMah = max(0, fcc - remCap)
            if chargeAmps > 50 && neededMah > 0 {
                return max(1, Int((Double(neededMah) / Double(chargeAmps)) * 60.0))
            }
            return nil
        } else {
            if currentLevel >= effectiveChargeLimit {
                return 0
            }

            let targetMah = Double(fcc) * (Double(effectiveChargeLimit) / 100.0)
            let neededMah = max(0.0, targetMah - Double(remCap))
            let chargeAmps = amps > 50 ? amps : Int((battWatts / max(1.0, volts)) * 1000.0)

            if chargeAmps > 50 && neededMah > 0 {
                return max(1, Int((neededMah / Double(chargeAmps)) * 60.0))
            } else if let iokitVal = (battDict["AvgTimeToFull"] as? Int) ?? (battDict["TimeRemaining"] as? Int),
                      iokitVal > 0, iokitVal < 65535 {
                let remainingPercentTo100 = max(1, 100 - currentLevel)
                let neededPercentToLimit = max(1, effectiveChargeLimit - currentLevel)
                return max(1, (iokitVal * neededPercentToLimit) / remainingPercentTo100)
            }
            return nil
        }
    }
}
