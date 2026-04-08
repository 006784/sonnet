import SwiftUI
import SwiftData

@Observable
final class StatisticsViewModel {
    var currentMonth: Date = Date()
    var categorySummaries: [CategorySummary] = []
    var monthlyTrends: [MonthlyTrend] = []
    var selectedType: RecordType = .expense
    var aiInsight: String = ""
    var isLoadingInsight: Bool = false

    func loadStatistics(from context: ModelContext, accountBook: AccountBook?) {
        aiInsight = ""
        isLoadingInsight = false
        let start = DateUtils.startOfMonth(currentMonth)
        let end   = DateUtils.endOfMonth(currentMonth)

        let descriptor = FetchDescriptor<Record>(
            predicate: #Predicate { $0.date >= start && $0.date <= end }
        )
        guard let records = try? context.fetch(descriptor) else { return }

        let filtered = (accountBook.map { book in
            records.filter { $0.accountBookId == book.id }
        } ?? records).filter { $0.type == selectedType.rawValue }

        let total = filtered.reduce(0) { $0 + $1.amount }

        let grouped = Dictionary(grouping: filtered) { $0.category?.id ?? UUID() }
        categorySummaries = grouped.compactMap { _, recs -> CategorySummary? in
            guard let cat = recs.first?.category else { return nil }
            let sum = recs.reduce(0) { $0 + $1.amount }
            return CategorySummary(
                category: cat,
                totalAmount: sum,
                percentage: total > 0 ? sum / total : 0,
                count: recs.count
            )
        }.sorted { $0.totalAmount > $1.totalAmount }

        loadTrends(context: context, accountBook: accountBook)
    }

    private func loadTrends(context: ModelContext, accountBook: AccountBook?) {
        monthlyTrends = (0..<6).compactMap { offset -> MonthlyTrend? in
            guard let month = Calendar.current.date(byAdding: .month, value: -offset, to: currentMonth) else { return nil }
            let start = DateUtils.startOfMonth(month)
            let end   = DateUtils.endOfMonth(month)
            let desc  = FetchDescriptor<Record>(predicate: #Predicate { $0.date >= start && $0.date <= end })
            guard let recs = try? context.fetch(desc) else { return nil }
            let f = accountBook.map { book in recs.filter { $0.accountBookId == book.id } } ?? recs
            return MonthlyTrend(
                month: month,
                totalIncome: f.filter { $0.type == 1 }.reduce(0) { $0 + $1.amount },
                totalExpense: f.filter { $0.type == 0 }.reduce(0) { $0 + $1.amount }
            )
        }.reversed()
    }

    func previousMonth() { currentMonth = DateUtils.previousMonth(currentMonth) }
    func nextMonth()     { currentMonth = DateUtils.nextMonth(currentMonth) }

    func loadAIInsight(service: AIService) async {
        guard !categorySummaries.isEmpty else {
            aiInsight = ""
            return
        }
        isLoadingInsight = true
        defer { isLoadingInsight = false }
        do {
            let expenseTotal = categorySummaries.reduce(0) { $0 + $1.totalAmount }
            aiInsight = try await service.generateInsight(
                monthExpense: expenseTotal,
                categories: categorySummaries
            )
        } catch {
            aiInsight = ""
        }
    }
}
