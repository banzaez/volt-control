import Foundation

public enum ChargeMode: Int, Codable, Sendable, Equatable {
    case normal = 0
    case inhibit = 1
    case discharge = 2

    public var localizedName: String {
        switch self {
        case .normal: return "Обычный режим"
        case .inhibit: return "Пауза зарядки"
        case .discharge: return "Работа от батареи"
        }
    }
}
