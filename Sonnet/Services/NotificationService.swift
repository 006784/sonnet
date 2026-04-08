import Foundation
import UserNotifications

// MARK: - NotificationService：课程提醒

final class NotificationService {
    static let shared = NotificationService()
    private init() {}
    private let budgetWarningDefaultsKey = "student_budget_warning_last_key"

    // MARK: - 权限

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - 调度课程提醒

    /// 为单门课程调度每周重复提醒（在上课前 minutesBefore 分钟触发）
    func scheduleClassReminder(course: Course, minutesBefore: Int = 15) {
        cancelReminder(courseId: course.id)

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = course.name
        content.body = "\(minutesBefore) 分钟后上课" + (course.location.isEmpty ? "" : "，地点：\(course.location)")
        content.sound = .default

        guard let startTime = PeriodInfo.startTime(for: course.startPeriod) else { return }

        var components = DateComponents()
        components.weekday = isoWeekdayToCalendar(course.weekday)
        components.hour    = startTime.hour
        components.minute  = max(0, startTime.minute - minutesBefore)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationId(courseId: course.id),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// 取消指定课程的提醒
    func cancelReminder(courseId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationId(courseId: courseId)])
    }

    /// 批量重新调度所有课程提醒
    func rescheduleAll(courses: [Course], minutesBefore: Int = 15) {
        courses.forEach { scheduleClassReminder(course: $0, minutesBefore: minutesBefore) }
    }

    func scheduleBudgetWarningIfNeeded(
        monthlyBudget: Double,
        usedPercent: Double,
        remainingBudget: Double,
        remainingDays: Int
    ) {
        let tier: String
        let title: String
        let body: String

        if remainingBudget < 0 {
            tier = "over"
            title = "本月生活费已经超支"
            body = "目前超支 ¥\(CurrencyUtils.format(-remainingBudget))，接下来 \(remainingDays) 天最好更克制一点。"
        } else if usedPercent >= 0.85 {
            tier = "warning"
            title = "生活费快到提醒线了"
            body = "本月已使用 \(Int(min(usedPercent, 1) * 100))%，还剩 ¥\(CurrencyUtils.format(remainingBudget))。"
        } else {
            return
        }

        let monthKey = monthIdentifier() + "_" + tier
        guard UserDefaults.standard.string(forKey: budgetWarningDefaultsKey) != monthKey else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "student_budget_\(monthKey)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )

            UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(monthKey, forKey: self.budgetWarningDefaultsKey)
        }
    }

    // MARK: - 内部工具

    private func notificationId(courseId: UUID) -> String {
        "course_reminder_\(courseId.uuidString)"
    }

    private func monthIdentifier(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMM"
        return formatter.string(from: date)
    }

    /// ISO 星期（1=周一）→ Calendar.weekday（1=周日）
    private func isoWeekdayToCalendar(_ iso: Int) -> Int {
        iso == 7 ? 1 : iso + 1
    }
}

// MARK: - PeriodInfo 时间扩展

extension PeriodInfo {
    struct HourMinute { let hour: Int; let minute: Int }

    static func startTime(for period: Int) -> HourMinute? {
        let times: [Int: HourMinute] = [
            1: HourMinute(hour: 8,  minute: 0),
            2: HourMinute(hour: 8,  minute: 55),
            3: HourMinute(hour: 10, minute: 0),
            4: HourMinute(hour: 10, minute: 55),
            5: HourMinute(hour: 14, minute: 0),
            6: HourMinute(hour: 14, minute: 55),
            7: HourMinute(hour: 16, minute: 0),
            8: HourMinute(hour: 16, minute: 55),
            9: HourMinute(hour: 19, minute: 0),
            10: HourMinute(hour: 19, minute: 55),
        ]
        return times[period]
    }
}
