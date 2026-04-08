import Foundation

enum CurrencyUtils {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func format(_ amount: Double, showSign: Bool = false) -> String {
        let str = formatter.string(from: NSNumber(value: abs(amount))) ?? "0.00"
        if showSign && amount > 0 { return "+\(str)" }
        return str
    }

    static func formatWithSymbol(_ amount: Double) -> String {
        "¥\(format(amount))"
    }

    static func parseInput(_ input: String) -> Double {
        Double(input.replacingOccurrences(of: ",", with: "")) ?? 0
    }
}
