import AppIntents
import Foundation

struct RecordIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "记一笔收入"
    static var description = IntentDescription("快速记录一笔收入，支持金额、分类和备注")
    static var openAppWhenRun = true

    @Parameter(title: "金额", description: "收入金额")
    var amount: Double

    @Parameter(title: "分类", description: "收入分类", default: "工资")
    var category: String

    @Parameter(title: "备注", description: "备注信息", default: "")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("记录 \(\.$category) 收入 \(\.$amount) 元") {
            \.$note
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "金额需要大于 0，你可以再告诉我一次。")
        }

        await MainActor.run {
            AppShortcutStore.saveQuickRecordDraft(
                QuickRecordDraft(
                    amount: amount,
                    categoryName: normalizedCategory,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: 1,
                    createdAt: Date()
                )
            )
        }

        let amountStr = String(format: "%.2f", amount)
        let dialog = "我先为你写好一笔 \(normalizedCategory) 收入 ¥\(amountStr)，打开十四行诗确认后就会入账。"
        return .result(dialog: "\(dialog)")
    }

    private var normalizedCategory: String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "工资" : trimmed
    }
}
