import Foundation

enum Formatters {
    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let monthDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MMMM 'de' yyyy"
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    static func currency(fromCents cents: Int) -> String {
        let value = Decimal(cents) / 100
        return currencyFormatter.string(from: value as NSDecimalNumber) ?? "R$ 0,00"
    }

    static func displayDate(fromISO iso: String) -> String {
        guard let date = isoDateFormatter.date(from: iso) else { return iso }
        return displayDateFormatter.string(from: date)
    }

    static func isoDateString(from date: Date) -> String {
        isoDateFormatter.string(from: date)
    }

    static func monthKey(from date: Date = Date()) -> String {
        monthKeyFormatter.string(from: date)
    }

    static func date(fromISO iso: String) -> Date? {
        isoDateFormatter.date(from: iso)
    }

    /// "1550" cents -> "15,50": the plain text a form field starts with when editing.
    static func amountText(fromCents cents: Int) -> String {
        String(format: "%d,%02d", cents / 100, cents % 100)
    }

    static func parseAmountToCents(_ text: String) -> Int? {
        var normalized = text.trimmingCharacters(in: .whitespaces)
        // With a decimal comma, dots can only be thousands separators: "1.234,56".
        if normalized.contains(",") {
            normalized = normalized.replacingOccurrences(of: ".", with: "")
        }
        normalized = normalized.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else { return nil }
        return Int((value * 100).rounded())
    }

    static func shiftMonth(_ monthKey: String, by delta: Int) -> String {
        guard let date = monthKeyFormatter.date(from: monthKey),
              let shifted = Calendar.current.date(byAdding: .month, value: delta, to: date) else {
            return monthKey
        }
        return monthKeyFormatter.string(from: shifted)
    }

    static func displayMonth(_ monthKey: String) -> String {
        guard let date = monthKeyFormatter.date(from: monthKey) else { return monthKey }
        return monthDisplayFormatter.string(from: date)
    }
}
