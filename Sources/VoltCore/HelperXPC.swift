import Foundation

public enum VoltHelperConstants {
    public static let machServiceName = "com.voltcontrol.helper"
    public static let plistName = "com.voltcontrol.helper.plist"
    public static let appBundleID = "com.voltcontrol.app"
    public static let legacyHelperPath = "/Library/PrivilegedHelperTools/com.voltcontrol.helper"
    public static let protocolVersion = 2
}

@objc public protocol VoltHelperProtocol {
    func protocolVersion(reply: @escaping @Sendable (Int) -> Void)
    func capabilities(reply: @escaping @Sendable (Data) -> Void)
    func setMode(_ raw: Int, reply: @escaping @Sendable (Bool, String?) -> Void)
    func diagnose(reply: @escaping @Sendable (String) -> Void)
}
