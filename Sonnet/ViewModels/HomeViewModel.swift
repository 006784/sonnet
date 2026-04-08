import SwiftUI
import SwiftData

@Observable
final class HomeViewModel {
    var currentMonth: Date = Date()
    var dailyGroups: [DailyRecordGroup] = []
    var monthlyIncome: Double = 0
    var monthlyExpense: Double = 0
    var isLoading: Bool = false
    var errorMessage: String?

    var monthBalance: Double { monthlyIncome - monthlyExpense }

    func loadRecords(from context: ModelContext, accountBook: AccountBook?) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let start = DateUtils.startOfMonth(currentMonth)
        let end   = DateUtils.endOfMonth(currentMonth)

        let descriptor = FetchDescriptor<Record>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        guard let records = try? context.fetch(descriptor) else {
            dailyGroups = []
            monthlyIncome = 0
            monthlyExpense = 0
            errorMessage = "暂时无法读取账本，请稍后再试。"
            return
        }

        let filtered = accountBook.map { book in
            records.filter { $0.accountBookId == book.id }
        } ?? records

        monthlyIncome  = filtered.filter { $0.type == 1 }.reduce(0) { $0 + $1.amount }
        monthlyExpense = filtered.filter { $0.type == 0 }.reduce(0) { $0 + $1.amount }

        let grouped = Dictionary(grouping: filtered) { record in
            Calendar.current.startOfDay(for: record.date)
        }
        dailyGroups = grouped
            .map { DailyRecordGroup(date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    func previousMonth() { currentMonth = DateUtils.previousMonth(currentMonth) }
    func nextMonth()     { currentMonth = DateUtils.nextMonth(currentMonth) }
}
