import AppIntents
import Foundation

struct QueryBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "查看本月余额"
    static var description = IntentDescription("查询本月收支情况和结余金额")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = await MainActor.run {
            AppShortcutStore.loadMonthlyBalanceSnapshot()
        }
        let dialog = buildDialog(snapshot: snapshot)
        return .result(dialog: "\(dialog)")
    }

    private func buildDialog(snapshot: MonthlyBalanceSnapshot?) -> String {
        guard let snapshot,
              snapshot.isCurrentMonth else {
            return "我还没拿到最新的本月摘要，先打开一次十四行诗，我就能继续为你播报。"
        }

        let expense = format(snapshot.expense)
        let income = format(snapshot.income)
        let balance = format(snapshot.balance)
        return "《\(snapshot.bookName)》本月支出 ¥\(expense)，收入 ¥\(income)，当前结余 ¥\(balance)。"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
