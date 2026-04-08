import Foundation

enum DateUtils {
    static let shared = Calendar.current

    static func startOfMonth(_ date: Date = Date()) -> Date {
        let comps = shared.dateComponents([.year, .month], from: date)
        return shared.date(from: comps) ?? date
    }

    static func endOfMonth(_ date: Date = Date()) -> Date {
        guard let start = shared.date(from: shared.dateComponents([.year, .month], from: date)),
              let nextMonth = shared.date(byAdding: .month, value: 1, to: start),
              let end = shared.date(byAdding: .second, value: -1, to: nextMonth)
        else { return date }
        return end
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        shared.isDate(a, inSameDayAs: b)
    }

    static func monthString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: date)
    }

    static func dayString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日 EEEE"
        fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: date)
    }

    static func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    static func previousMonth(_ date: Date) -> Date {
        shared.date(byAdding: .month, value: -1, to: date) ?? date
    }

    static func nextMonth(_ date: Date) -> Date {
        shared.date(byAdding: .month, value: 1, to: date) ?? date
    }
}
