import Foundation

// MARK: - 课程表辅助类型（视图层）

/// 时间段文字映射（节次 → 时间区间）
struct PeriodInfo {
    let period: Int
    let timeRange: String

    static let defaultPeriods: [PeriodInfo] = [
        PeriodInfo(period: 1, timeRange: "08:00–08:45"),
        PeriodInfo(period: 2, timeRange: "08:55–09:40"),
        PeriodInfo(period: 3, timeRange: "10:00–10:45"),
        PeriodInfo(period: 4, timeRange: "10:55–11:40"),
        PeriodInfo(period: 5, timeRange: "14:00–14:45"),
        PeriodInfo(period: 6, timeRange: "14:55–15:40"),
        PeriodInfo(period: 7, timeRange: "16:00–16:45"),
        PeriodInfo(period: 8, timeRange: "16:55–17:40"),
        PeriodInfo(period: 9, timeRange: "19:00–19:45"),
        PeriodInfo(period: 10, timeRange: "19:55–20:40"),
    ]

    static func timeRange(for period: Int) -> String {
        defaultPeriods.first { $0.period == period }?.timeRange ?? "--"
    }
}

/// 每周星期标签
enum Weekday: Int, CaseIterable, Identifiable {
    case mon = 1, tue, wed, thu, fri, sat, sun
    var id: Int { rawValue }
    var label: String { ["", "周一","周二","周三","周四","周五","周六","周日"][rawValue] }
    var shortLabel: String { ["", "一","二","三","四","五","六","日"][rawValue] }
}
