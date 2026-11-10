import Testing
@testable import VoltControl

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
        info.isChargingInhibited = true
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

    @Test("Time Remaining Formatter")
    func testTimeRemaining() {
        var info = BatteryInfo()
        info.isCharging = true
        info.timeRemainingMinutes = 75
        #expect(info.timeRemainingFormatted == "1 ч 15 мин")

        info.isCharging = false
        info.timeRemainingMinutes = 150
        #expect(info.timeRemainingFormatted == "2 ч 30 мин")

        info.isFullyCharged = true
        info.timeRemainingMinutes = nil
        #expect(info.timeRemainingFormatted == "Полностью заряжен")
    }

    @Test("Settings Defaults")
    @MainActor
    func testSettingsDefaults() {
        let settings = AppSettings.shared
        #expect(settings.chargeLimit >= 50 && settings.chargeLimit <= 100)
        #expect(settings.autoResetTopUp == true)
        #expect(settings.sailingDelta >= 2)
        #expect(settings.showModerateEnergyApps == true)
        #expect(settings.showLowEnergyApps == false)
    }

    @Test("High Energy Service Fixed 3 Slots")
    @MainActor
    func testHighEnergyAppSlots() {
        let service = HighEnergyAppService.shared
        #expect(service.topThreeSlots.count == 3)
    }
}
