import Foundation
import ServiceManagement
import VoltCore

public enum HelperServiceStatus: Sendable, Equatable {
    case notRegistered
    case requiresApproval
    case enabled
    case notFound
    case error(String)

    public var isReady: Bool {
        self == .enabled
    }

    public var localizedTitle: String {
        switch self {
        case .notRegistered: return "Демон не установлен"
        case .requiresApproval: return "Требуется разрешение в Настройках"
        case .enabled: return "Активен"
        case .notFound: return "Демон не найден в бандле"
        case .error(let msg): return "Ошибка: \(msg)"
        }
    }
}

public struct HelperError: Error, Sendable, Equatable {
    public let message: String
    public init(_ message: String) {
        self.message = message
    }
}

private final class OnceResume<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        let cont: CheckedContinuation<T, Never>? = lock.withLock {
            let c = continuation
            continuation = nil
            return c
        }
        cont?.resume(returning: value)
    }
}

@MainActor
@Observable
public final class HelperClient {
    public static let shared = HelperClient()

    public private(set) var status: HelperServiceStatus = .notRegistered
    public private(set) var capabilities: ChargeCapabilities?
    public private(set) var diagnostics: String = ""

    @ObservationIgnored private var connection: NSXPCConnection?
    @ObservationIgnored private let daemonService = SMAppService.daemon(plistName: VoltHelperConstants.plistName)

    private init() {}

    public func refreshStatus() {
        switch daemonService.status {
        case .notRegistered:
            status = .notRegistered
        case .requiresApproval:
            status = .requiresApproval
        case .enabled:
            status = .enabled
        case .notFound:
            status = .notFound
        @unknown default:
            status = .error("Неизвестный статус SMAppService")
        }
    }

    public func register() {
        do {
            try daemonService.register()
            refreshStatus()
            if status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            } else if status == .enabled {
                Task {
                    await connectAndProbe()
                }
            }
        } catch {
            refreshStatus()
            if status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            } else {
                status = .error(error.localizedDescription)
            }
        }
    }

    public func unregister() async {
        disconnect()
        capabilities = nil
        diagnostics = ""
        do {
            try await daemonService.unregister()
            refreshStatus()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    public func connectAndProbe() async {
        refreshStatus()
        guard status == .enabled else { return }

        let version = await fetchProtocolVersion()
        if let version, version != VoltHelperConstants.protocolVersion {
            await unregister()
            register()
            return
        }

        if let caps = await fetchCapabilities() {
            self.capabilities = caps
        }
        let diag = await fetchDiagnostics()
        if !diag.isEmpty {
            self.diagnostics = diag
        }
    }

    public func apply(_ mode: ChargeMode) async -> Result<Void, HelperError> {
        refreshStatus()
        guard status == .enabled else {
            return .failure(HelperError(status.localizedTitle))
        }

        let conn = ensureConnection()
        return await withCheckedContinuation { continuation in
            let once = OnceResume(continuation)
            let proxy = conn.remoteObjectProxyWithErrorHandler { error in
                once.resume(returning: .failure(HelperError(error.localizedDescription)))
            } as? VoltHelperProtocol

            guard let proxy else {
                once.resume(returning: .failure(HelperError("Не удалось создать XPC proxy")))
                return
            }

            proxy.setMode(mode.rawValue) { success, errorMessage in
                if success {
                    once.resume(returning: .success(()))
                } else {
                    once.resume(returning: .failure(HelperError(errorMessage ?? "Неизвестная ошибка демона")))
                }
            }
        }
    }

    public func refreshDiagnostics() async {
        refreshStatus()
        guard status == .enabled else { return }
        if let caps = await fetchCapabilities() {
            self.capabilities = caps
        }
        let diag = await fetchDiagnostics()
        if !diag.isEmpty {
            self.diagnostics = diag
        }
    }

    private func ensureConnection() -> NSXPCConnection {
        if let existing = connection {
            return existing
        }
        let conn = NSXPCConnection(machServiceName: VoltHelperConstants.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: VoltHelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.connection = nil
            }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.connection = nil
            }
        }
        conn.resume()
        connection = conn
        return conn
    }

    private func disconnect() {
        connection?.invalidate()
        connection = nil
    }

    private func fetchProtocolVersion() async -> Int? {
        let conn = ensureConnection()
        return await withCheckedContinuation { continuation in
            let once = OnceResume(continuation)
            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ _ in
                once.resume(returning: nil)
            }) as? VoltHelperProtocol else {
                once.resume(returning: nil)
                return
            }
            proxy.protocolVersion { version in
                once.resume(returning: version)
            }
        }
    }

    private func fetchCapabilities() async -> ChargeCapabilities? {
        let conn = ensureConnection()
        return await withCheckedContinuation { continuation in
            let once = OnceResume(continuation)
            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ _ in
                once.resume(returning: nil)
            }) as? VoltHelperProtocol else {
                once.resume(returning: nil)
                return
            }
            proxy.capabilities { data in
                let decoded = try? JSONDecoder().decode(ChargeCapabilities.self, from: data)
                once.resume(returning: decoded)
            }
        }
    }

    private func fetchDiagnostics() async -> String {
        let conn = ensureConnection()
        return await withCheckedContinuation { continuation in
            let once = OnceResume(continuation)
            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ _ in
                once.resume(returning: "")
            }) as? VoltHelperProtocol else {
                once.resume(returning: "")
                return
            }
            proxy.diagnose { text in
                once.resume(returning: text)
            }
        }
    }
}
