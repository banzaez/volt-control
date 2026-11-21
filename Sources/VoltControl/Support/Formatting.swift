import Foundation

public enum Formatting {
    private static let ruLocale = Locale(identifier: "ru_RU")

    private static let oneDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = ruLocale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    private static let signedOneDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = ruLocale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        f.positivePrefix = "+"
        f.negativePrefix = "-"
        return f
    }()

    private static let twoDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = ruLocale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let zeroDecimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = ruLocale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    public static func watts(_ value: Double, signed: Bool = false) -> String {
        let formatter = signed ? signedOneDecimalFormatter : oneDecimalFormatter
        let number = NSNumber(value: value)
        let str = formatter.string(from: number) ?? "0,0"
        return "\(str) Вт"
    }

    public static func celsius(_ value: Double?) -> String {
        guard let value else { return "—" }
        let str = oneDecimalFormatter.string(from: NSNumber(value: value)) ?? "0,0"
        return "\(str) °C"
    }

    public static func celsiusCompact(_ value: Double?) -> String {
        guard let value else { return "—" }
        let str = oneDecimalFormatter.string(from: NSNumber(value: value)) ?? "0,0"
        return "\(str)°C"
    }

    public static func volts(_ value: Double) -> String {
        let str = twoDecimalFormatter.string(from: NSNumber(value: value)) ?? "0,00"
        return "\(str) В"
    }

    public static func percent(_ value: Double, digits: Int = 0) -> String {
        let formatter = digits == 1 ? oneDecimalFormatter : zeroDecimalFormatter
        let str = formatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(str)%"
    }

    public static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours) ч \(mins) мин"
        } else {
            return "\(mins) мин"
        }
    }

    public static func duration(seconds: Int) -> String {
        guard seconds > 0 else { return "0 мин" }
        return duration(minutes: seconds / 60)
    }
}
