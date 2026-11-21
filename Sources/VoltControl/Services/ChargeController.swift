import Foundation
import VoltCore

@MainActor
@Observable
public final class ChargeController {
    public static let shared = ChargeController()

    public private(set) var controlStatus: ChargeControlStatus = .helperMissing
    public private(set) var currentMode: ChargeMode?

    @ObservationIgnored private var lastAppliedMode: ChargeMode?
    @ObservationIgnored private var lastFailureDate: Date?
    @ObservationIgnored private var isApplying = false
    @ObservationIgnored private let retryIntervalSeconds: TimeInterval = 30.0
    @ObservationIgnored private let helper: HelperClient

    init(helper: HelperClient = .shared) {
        self.helper = helper
    }

    public func syncStatusOnly() {
        helper.refreshStatus()
        switch helper.status {
        case .notRegistered, .notFound:
            controlStatus = .helperMissing
            lastAppliedMode = nil
        case .requiresApproval:
            controlStatus = .needsApproval
            lastAppliedMode = nil
        case .error(let msg):
            controlStatus = .failed(msg)
        case .enabled:
            switch controlStatus {
            case .unsupported, .failed:
                break
            default:
                controlStatus = .active(lastAppliedMode ?? .normal)
            }
        }
    }

    public func apply(_ mode: ChargeMode, force: Bool = false) async {
        helper.refreshStatus()
        switch helper.status {
        case .notRegistered, .notFound:
            controlStatus = .helperMissing
            lastAppliedMode = nil
            return
        case .requiresApproval:
            controlStatus = .needsApproval
            lastAppliedMode = nil
            return
        case .error(let msg):
            controlStatus = .failed(msg)
            return
        case .enabled:
            break
        }

        if let caps = helper.capabilities {
            if mode == .inhibit && !caps.canInhibit {
                controlStatus = .unsupported(.inhibit)
                return
            }
            if mode == .discharge && !caps.canDisableAdapter {
                controlStatus = .unsupported(.discharge)
                return
            }
        }

        if !force && lastAppliedMode == mode {
            controlStatus = .active(mode)
            return
        }

        if !force, let failDate = lastFailureDate, Date().timeIntervalSince(failDate) < retryIntervalSeconds {
            return
        }

        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        let result = await helper.apply(mode)
        switch result {
        case .success:
            lastAppliedMode = mode
            currentMode = mode
            lastFailureDate = nil
            controlStatus = .active(mode)
        case .failure(let error):
            lastFailureDate = Date()
            if error.message.contains("не поддерживается") {
                controlStatus = .unsupported(mode)
            } else {
                controlStatus = .failed(error.message)
            }
        }
    }

    public func resetOnTerminate() async {
        guard helper.status == .enabled else { return }
        _ = await helper.apply(.normal)
        lastAppliedMode = .normal
        currentMode = .normal
    }
}
