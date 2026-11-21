import Foundation
import Testing
@testable import VoltControl
@testable import VoltCore

@Suite("VoltControl Core Tests")
struct VoltControlTests {

    @Test("Battery State and Health Calculation")
    func testBatteryHealth() {
        var info = BatteryInfo()
        info.designCapacityMah = 6000
        info.currentMaxCapacityMah = 5700
        #expect(info.healthPercentage == 95.0)

        info.currentPercentage = 80
        info.isACConnected = false
        #expect(info.state == .discharging)

        info.isACConnected = true
        info.isCharging = true
        info.batteryPowerWatts = 25.0
        #expect(info.state == .charging)

        info.isCharging = false
        info.batteryPowerWatts = 0.0
        info.controlStatus = .active(.inhibit)
        #expect(info.isChargingInhibited == true)
        #expect(info.state == .pluggedInPaused)

        info.currentPercentage = 100
        info.isFullyCharged = true
        #expect(info.state == .pluggedInFull)
    }

    @Test("Power Flow Calculation")
    func testPowerFlowFormatting() {
        var info = BatteryInfo()
        info.isACConnected = true
        info.batteryPowerWatts = 24.5
        info.adapterPowerWatts = 35.0
        info.systemPowerWatts = 10.5

        #expect(info.systemPowerWatts == 10.5)
        #expect(info.batteryPowerWatts == 24.5)
        #expect(info.adapterPowerWatts == 35.0)
    }

    @Test("Time Remaining Formatter and Labels")
    func testTimeRemaining() {
        var info = BatteryInfo()
        info.isACConnected = false
        info.isCharging = false
        info.timeRemainingMinutes = 150
        #expect(info.timeRemainingLabel == "Осталось работы")
        #expect(info.timeRemainingFormatted == "2 ч 30 мин")

        info.isACConnected = true
        info.isCharging = true
        info.appChargeLimit = 80
        info.isTopUpActive = false
        info.timeRemainingMinutes = 25
        #expect(info.timeRemainingLabel == "До лимита")
        #expect(info.timeRemainingFormatted == "25 мин")

        info.appChargeLimit = 100
        info.timeRemainingMinutes = 75
        #expect(info.timeRemainingLabel == "До полной зарядки")
        #expect(info.timeRemainingFormatted == "1 ч 15 мин")

        info.isFullyCharged = true
        info.isCharging = false
        info.timeRemainingMinutes = nil
        #expect(info.timeRemainingFormatted == "Полностью заряжен")

        var limitInfo = BatteryInfo()
        limitInfo.isACConnected = true
        limitInfo.currentPercentage = 84
        limitInfo.appChargeLimit = 80
        limitInfo.isTopUpActive = false
        limitInfo.timeRemainingMinutes = 0
        #expect(limitInfo.timeRemainingLabel == "Состояние")
        #expect(limitInfo.timeRemainingFormatted == "Лимит достигнут")
    }

    @Test("Effective Charge Limit uses min(app, system)")
    func testEffectiveLimit() {
        var info = BatteryInfo()
        info.appChargeLimit = 80
        info.systemChargeLimit = 70
        #expect(info.chargeLimit == 70)

        info.systemChargeLimit = 90
        #expect(info.chargeLimit == 80)

        info.systemChargeLimit = nil
        #expect(info.chargeLimit == 80)
    }

    @Test("Settings Defaults with isolated UserDefaults")
    @MainActor
    func testSettingsDefaults() {
        let suiteName = "com.voltcontrol.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.chargeLimit == 80)
        #expect(settings.autoResetTopUp == true)
        #expect(settings.sailingDelta == 4)
        #expect(settings.showModerateEnergyApps == true)
        #expect(settings.showLowEnergyApps == false)
        #expect(settings.maxAllowedTempCelsius == 38.0)

        settings.chargeLimit = 75
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.chargeLimit == 75)
    }

    @Test("High Energy Service Fixed 3 Slots")
    @MainActor
    func testHighEnergyAppSlots() {
        let service = HighEnergyAppService.shared
        #expect(service.topThreeSlots.count == 3)
    }

    @Test("Formatting helpers")
    func testFormatting() {
        #expect(Formatting.watts(24.5, signed: true) == "+24,5 Вт")
        #expect(Formatting.watts(-5.6, signed: true) == "-5,6 Вт")
        #expect(Formatting.watts(12.3, signed: false) == "12,3 Вт")
        #expect(Formatting.celsius(nil) == "—")
        #expect(Formatting.celsius(29.5) == "29,5 °C")
        #expect(Formatting.volts(12.34) == "12,34 В")
        #expect(Formatting.duration(minutes: 150) == "2 ч 30 мин")
        #expect(Formatting.duration(minutes: 45) == "45 мин")
    }

    @Test("Telemetry parser handles nil temperature and two's complement Amperage")
    func testTelemetryParser() {
        let negativeAmps = UInt64(bitPattern: Int64(-1500))
        let battDict: [String: Any] = [
            "CurrentCapacity": 65,
            "ExternalConnected": false,
            "IsCharging": false,
            "Amperage": NSNumber(value: negativeAmps),
            "Voltage": 11500,
            "DesignCapacity": 6000,
            "AppleRawMaxCapacity": 5800,
            "AppleRawCurrentCapacity": 3770
        ]
        let reading = BatteryTelemetryParser.parse(
            battDict: battDict,
            packDict: [:],
            iops: IOPSPowerSnapshot(isACConnected: false, isCharging: false),
            sensors: SMCSensorReadings(),
            effectiveChargeLimit: 80,
            isTopUpActive: false
        )
        #expect(reading.temperatureCelsius == nil)
        #expect(reading.amperageMilliAmps == -1500)
        #expect(reading.currentPercentage == 65)
        #expect(reading.isACConnected == false)
    }
}

@Suite("ChargePolicy Tests")
struct ChargePolicyTests {
    @Test("1. Manual discharge returns .discharge above floor")
    func testManualDischargeAboveFloor() {
        let settings = ChargeSettingsSnapshot(isManualDischarge: true)
        let d = ChargePolicy.evaluate(
            level: 50, isACConnected: true, isFullyCharged: false, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: .normal, wasOverheatLatched: false
        )
        #expect(d.mode == .discharge)
        #expect(d.clearManualDischarge == false)
    }

    @Test("2. Manual discharge resets to .normal at 10% floor")
    func testManualDischargeFloor() {
        let settings = ChargeSettingsSnapshot(isManualDischarge: true)
        let d = ChargePolicy.evaluate(
            level: 10, isACConnected: true, isFullyCharged: false, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: .discharge, wasOverheatLatched: false
        )
        #expect(d.mode == .normal)
        #expect(d.clearManualDischarge == true)
        #expect(d.events.contains(.dischargeFloorReached))
    }

    @Test("3. Overheat hysteresis: triggers at 39, stays latched at 37.5, clears at 35.9")
    func testOverheatHysteresis() {
        let settings = ChargeSettingsSnapshot(tempProtectionEnabled: true, maxAllowedTempCelsius: 38.0)

        let d1 = ChargePolicy.evaluate(
            level: 50, isACConnected: true, isFullyCharged: false, temperatureCelsius: 39.0,
            settings: settings, systemChargeLimit: nil, previousMode: .normal, wasOverheatLatched: false
        )
        #expect(d1.mode == .inhibit)
        #expect(d1.overheatLatched == true)
        #expect(d1.events.contains(.overheat(39.0)))

        let d2 = ChargePolicy.evaluate(
            level: 50, isACConnected: true, isFullyCharged: false, temperatureCelsius: 37.5,
            settings: settings, systemChargeLimit: nil, previousMode: .inhibit, wasOverheatLatched: true
        )
        #expect(d2.mode == .inhibit)
        #expect(d2.overheatLatched == true)
        #expect(d2.events.isEmpty)

        let d3 = ChargePolicy.evaluate(
            level: 50, isACConnected: true, isFullyCharged: false, temperatureCelsius: 35.9,
            settings: settings, systemChargeLimit: nil, previousMode: .inhibit, wasOverheatLatched: true
        )
        #expect(d3.mode == .normal)
        #expect(d3.overheatLatched == false)
    }

    @Test("4. Nil temperature does not trigger overheat protection")
    func testNilTemperature() {
        let settings = ChargeSettingsSnapshot(tempProtectionEnabled: true, maxAllowedTempCelsius: 38.0)
        let d = ChargePolicy.evaluate(
            level: 50, isACConnected: true, isFullyCharged: false, temperatureCelsius: nil,
            settings: settings, systemChargeLimit: nil, previousMode: .normal, wasOverheatLatched: true
        )
        #expect(d.mode == .normal)
        #expect(d.overheatLatched == false)
    }

    @Test("5. Disconnected AC returns .normal")
    func testDisconnectedAC() {
        let settings = ChargeSettingsSnapshot(appChargeLimit: 80)
        let d = ChargePolicy.evaluate(
            level: 95, isACConnected: false, isFullyCharged: false, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: .inhibit, wasOverheatLatched: false
        )
        #expect(d.mode == .normal)
    }

    @Test("6. Top-up charges to 100%, autoReset returns to limit")
    func testTopUpWithAutoReset() {
        let settings = ChargeSettingsSnapshot(appChargeLimit: 80, isTopUpActive: true, autoResetTopUp: true)

        let charging = ChargePolicy.evaluate(
            level: 90, isACConnected: true, isFullyCharged: false, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: .inhibit, wasOverheatLatched: false
        )
        #expect(charging.mode == .normal)
        #expect(charging.clearTopUp == false)

        let done = ChargePolicy.evaluate(
            level: 100, isACConnected: true, isFullyCharged: true, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: .normal, wasOverheatLatched: false
        )
        #expect(done.mode == .inhibit)
        #expect(done.clearTopUp == true)
        #expect(done.events.contains(.topUpCompleted))
    }

    @Test("7. Top-up without autoReset stays .normal at 100%")
    func testTopUpWithoutAutoReset() {
        let settings = ChargeSettingsSnapshot(appChargeLimit: 80, isTopUpActive: true, autoResetTopUp: false)
        let d = ChargePolicy.evaluate(
            level: 100, isACConnected: true, isFullyCharged: true, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: .normal, wasOverheatLatched: false
        )
        #expect(d.mode == .normal)
        #expect(d.clearTopUp == false)
    }

    @Test("8. Sailing mode preserves previous mode in band and defaults to .normal when nil")
    func testSailingMode() {
        let settings = ChargeSettingsSnapshot(appChargeLimit: 80, sailingModeEnabled: true, sailingDelta: 4)

        let inBandNilPrev = ChargePolicy.evaluate(
            level: 78, isACConnected: true, isFullyCharged: false, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: nil, wasOverheatLatched: false
        )
        #expect(inBandNilPrev.mode == .normal)

        let inBandInhibitPrev = ChargePolicy.evaluate(
            level: 78, isACConnected: true, isFullyCharged: false, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: .inhibit, wasOverheatLatched: false
        )
        #expect(inBandInhibitPrev.mode == .inhibit)

        let belowThreshold = ChargePolicy.evaluate(
            level: 76, isACConnected: true, isFullyCharged: false, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: nil, previousMode: .inhibit, wasOverheatLatched: false
        )
        #expect(belowThreshold.mode == .normal)
    }

    @Test("9. System charge limit caps effective limit via min()")
    func testSystemLimitMin() {
        let settings = ChargeSettingsSnapshot(appChargeLimit: 80, sailingModeEnabled: false)
        let d = ChargePolicy.evaluate(
            level: 70, isACConnected: true, isFullyCharged: false, temperatureCelsius: 30,
            settings: settings, systemChargeLimit: 70, previousMode: .normal, wasOverheatLatched: false
        )
        #expect(d.mode == .inhibit)
        #expect(d.events.contains(.limitReached(70)))
    }

    @Test("10. Manual discharge overrides overheat inhibit")
    func testManualDischargeOverridesOverheat() {
        let settings = ChargeSettingsSnapshot(
            isManualDischarge: true,
            tempProtectionEnabled: true,
            maxAllowedTempCelsius: 38.0
        )
        let d = ChargePolicy.evaluate(
            level: 60, isACConnected: true, isFullyCharged: false, temperatureCelsius: 40.0,
            settings: settings, systemChargeLimit: nil, previousMode: .normal, wasOverheatLatched: false
        )
        #expect(d.mode == .discharge)
    }
}
