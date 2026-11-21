import AppKit
import Foundation
import OSLog
import Sparkle

public enum UpdateCheckResult: Equatable, Sendable {
    case idle
    case checking
    case upToDate(version: String)
    case updateAvailable(version: String, releaseNotes: String, releaseURL: URL, downloadURL: URL?)
    case failed(message: String)
}

@MainActor
@Observable
public final class AppUpdateService: NSObject, SPUUpdaterDelegate {
    public static let shared = AppUpdateService()

    @ObservationIgnored private let logger = Logger(subsystem: "com.voltcontrol.app", category: "AppUpdateService")

    public private(set) var status: UpdateCheckResult = .idle
    public private(set) var isChecking: Bool = false

    @ObservationIgnored private var updaterController: SPUStandardUpdaterController?

    override private init() {
        super.init()
        if Bundle.main.bundleIdentifier != nil,
           Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            self.updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: self,
                userDriverDelegate: nil
            )
        }
    }

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public func setAutoCheckEnabled(_ enabled: Bool) {
        updaterController?.updater.automaticallyChecksForUpdates = enabled
    }

    @discardableResult
    public func checkForUpdates(isUserInitiated: Bool = true) -> UpdateCheckResult {
        guard !isChecking else { return status }
        guard let updaterController else {
            logger.warning("Sparkle не инициализирован (запуск вне .app бандла).")
            return .idle
        }

        isChecking = true
        status = .checking

        if isUserInitiated {
            NSApp.activate(ignoringOtherApps: true)
            updaterController.checkForUpdates(nil)
        } else {
            updaterController.updater.checkForUpdatesInBackground()
        }

        return status
    }

    // MARK: - SPUUpdaterDelegate
    public nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        let notes = item.itemDescription ?? ""
        let releaseURL = item.infoURL ?? URL(string: "https://github.com/banzaez/volt-control/releases")!
        let fileURL = item.fileURL
        Task { @MainActor in
            self.isChecking = false
            self.status = .updateAvailable(
                version: version,
                releaseNotes: notes,
                releaseURL: releaseURL,
                downloadURL: fileURL
            )
        }
    }

    public nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            self.isChecking = false
            self.status = .upToDate(version: self.currentVersion)
        }
    }

    public nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        Task { @MainActor in
            self.isChecking = false
            if nsError.domain == SUSparkleErrorDomain {
                if nsError.code == 1001 {
                    self.status = .upToDate(version: self.currentVersion)
                    return
                }
                if nsError.code == 4002 {
                    self.status = .idle
                    return
                }
            }
            self.logger.error("Sparkle прервал проверку обновлений: \(error.localizedDescription)")
            self.status = .failed(message: error.localizedDescription)
        }
    }

    public nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        Task { @MainActor in
            self.isChecking = false
        }
    }
}
