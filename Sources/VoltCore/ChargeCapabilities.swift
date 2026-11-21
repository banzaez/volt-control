import Foundation

public enum InhibitMethod: String, Codable, Sendable, Equatable {
    case chte
    case ch0bc
}

public enum AdapterMethod: String, Codable, Sendable, Equatable {
    case chie
    case ch0i
}

public struct ChargeCapabilities: Codable, Sendable, Equatable {
    public var inhibitMethod: InhibitMethod?
    public var adapterMethod: AdapterMethod?
    public var diagnostics: [String: String]

    public var canInhibit: Bool { inhibitMethod != nil }
    public var canDisableAdapter: Bool { adapterMethod != nil }

    public init(
        inhibitMethod: InhibitMethod? = nil,
        adapterMethod: AdapterMethod? = nil,
        diagnostics: [String: String] = [:]
    ) {
        self.inhibitMethod = inhibitMethod
        self.adapterMethod = adapterMethod
        self.diagnostics = diagnostics
    }
}
