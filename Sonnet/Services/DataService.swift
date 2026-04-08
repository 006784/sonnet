import SwiftData
import Foundation

// MARK: - DataService：所有 SwiftData 操作的统一封装

@Observable
@MainActor
final class DataService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: ── 记录 CRUD ──────────────────────────────────

    func insertRecord(_ record: Record) {
        modelContext.insert(record)
        save()
        refreshShortcutSnapshot()
    }

    func updateRecord(_ record: Record) {
        save()
        refreshShortcutSnapshot()
    }

    func deleteRecord(_ record: Record) {
        modelContext.delete(record)
        save()
        refreshShortcutSnapshot()
    }

    func getRecord(by id: UUID) -> Record? {
        let descriptor = FetchDescriptor<Record>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first
    }

    // MARK: ── 查询 ──────────────────────────────────────

    /// 获取指定月份 + 账本的所有记录（按日期倒序）
    func getRecords(for month: Date, bookId: UUID) -> [Record] {
        let start = DateUtils.startOfMonth(month)
        let end   = DateUtils.endOfMonth(month)
        let descriptor = FetchDescriptor<Record>(
            predicate: #Predicate {
                $0.date >= start && $0.date <= end && $0.accountBookId == bookId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 获取按天分组的记录列表
    func getDailyGroups(for month: Date, bookId: UUID) -> [DailyRecordGroup] {
        let records = getRecords(for: month, bookId: bookId)
        let grouped = Dictionary(grouping: records) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped
            .map { DailyRecordGroup(date: $0.key, records: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// 获取分类汇总（用于统计饼图）
    func getCategorySummary(for month: Date, type: RecordType, bookId: UUID) -> [CategorySummary] {
        let records = getRecords(for: month, bookId: bookId)
            .filter { $0.type == type.rawValue }
        let total = records.reduce(0.0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: records) { $0.category?.id ?? UUID() }
        return grouped.compactMap { _, recs -> CategorySummary? in
            guard let cat = recs.first?.category else { return nil }
            let sum = recs.reduce(0.0) { $0 + $1.amount }
            return CategorySummary(
                category:    cat,
                totalAmount: sum,
                percentage:  sum / total,
                count:       recs.count
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    /// 获取最近 N 个月的收支趋势
    func getMonthlyTrend(months: Int, bookId: UUID) -> [MonthlyTrend] {
        (0..<months).compactMap { offset -> MonthlyTrend? in
            guard let month = Calendar.current.date(
                byAdding: .month, value: -offset, to: Date()
            ) else { return nil }

            let records = getRecords(for: month, bookId: bookId)
            return MonthlyTrend(
                month:        month,
                totalIncome:  records.filter { $0.type == 1 }.reduce(0) { $0 + $1.amount },
                totalExpense: records.filter { $0.type == 0 }.reduce(0) { $0 + $1.amount }
            )
        }
        .reversed()
    }

    /// 获取月度收入/支出合计
    func getMonthTotal(for month: Date, bookId: UUID) -> (income: Double, expense: Double) {
        let records = getRecords(for: month, bookId: bookId)
        let income  = records.filter { $0.type == 1 }.reduce(0) { $0 + $1.amount }
        let expense = records.filter { $0.type == 0 }.reduce(0) { $0 + $1.amount }
        return (income, expense)
    }

    /// 全文搜索（备注 + 分类名）
    func searchRecords(query: String, bookId: UUID) -> [Record] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        let descriptor = FetchDescriptor<Record>(
            predicate: #Predicate {
                $0.accountBookId == bookId &&
                ($0.note.localizedStandardContains(q))
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: ── 分类 ──────────────────────────────────────

    func getCategories(type: RecordType) -> [Category] {
        let t = type.rawValue
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.type == t },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getAllCategories() -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.type), SortDescriptor(\.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func insertCategory(_ category: Category) {
        modelContext.insert(category)
        save()
    }

    func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        save()
    }

    // MARK: ── 账本 ──────────────────────────────────────

    func getAllBooks() -> [AccountBook] {
        let descriptor = FetchDescriptor<AccountBook>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getCurrentBook() -> AccountBook? {
        let descriptor = FetchDescriptor<AccountBook>(
            predicate: #Predicate { $0.isSelected }
        )
        if let current = (try? modelContext.fetch(descriptor))?.first {
            return current
        }

        let fallback = getAllBooks().first
        if let fallback {
            fallback.isSelected = true
            save()
        }
        return fallback
    }

    func setCurrentBook(_ book: AccountBook) {
        getAllBooks().forEach { $0.isSelected = false }
        book.isSelected = true
        save()
        refreshShortcutSnapshot()
    }

    func insertBook(_ book: AccountBook) {
        modelContext.insert(book)
        save()
        refreshShortcutSnapshot()
    }

    func deleteBook(_ book: AccountBook) {
        let deletingSelectedBook = book.isSelected
        modelContext.delete(book)

        if deletingSelectedBook {
            let fallback = getAllBooks().first { $0.id != book.id }
            fallback?.isSelected = true
        }
        save()
        refreshShortcutSnapshot()
    }

    // MARK: ── 数据初始化 ─────────────────────────────────

    /// 首次启动时插入默认分类和账本（幂等，已有数据时跳过）
    func seedDefaultDataIfNeeded() {
        let bookCount = (try? modelContext.fetchCount(FetchDescriptor<AccountBook>())) ?? 0
        let categoryCount = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0

        if bookCount == 0 {
            let defaultBook = AccountBook(name: "日常账本", icon: "book", budget: 0, isSelected: true)
            modelContext.insert(defaultBook)
        } else if getCurrentBook() == nil, let firstBook = getAllBooks().first {
            firstBook.isSelected = true
        }

        guard categoryCount == 0 else {
            save()
            refreshShortcutSnapshot()
            return
        }

        let expenseCategories: [(String, String, String)] = [
            ("餐饮", "fork.knife",                  "food"),
            ("交通", "bus.fill",                    "transport"),
            ("购物", "bag.fill",                    "shopping"),
            ("日用", "house.fill",                  "daily"),
            ("娱乐", "gamecontroller.fill",          "entertain"),
            ("医疗", "heart.text.square.fill",       "medical"),
            ("教育", "book.fill",                   "education"),
            ("通讯", "iphone",                      "comm"),
            ("其他", "ellipsis.circle",             "other"),
        ]
        for (idx, item) in expenseCategories.enumerated() {
            modelContext.insert(Category(
                name: item.0, icon: item.1, type: 0,
                sortOrder: idx, isDefault: true, colorName: item.2
            ))
        }

        let incomeCategories: [(String, String, String)] = [
            ("工资", "banknote.fill",               "salary"),
            ("兼职", "briefcase.fill",              "parttime"),
            ("理财", "chart.line.uptrend.xyaxis",   "invest"),
            ("红包", "giftcard.fill",               "gift"),
            ("其他", "ellipsis.circle",             "other"),
        ]
        for (idx, item) in incomeCategories.enumerated() {
            modelContext.insert(Category(
                name: item.0, icon: item.1, type: 1,
                sortOrder: idx, isDefault: true, colorName: item.2
            ))
        }

        save()
        refreshShortcutSnapshot()
    }

    /// 学生角色专属分类（幂等）
    func seedStudentCategories() {
        let existing = getCategories(type: .expense)
        let existingColorNames = Set(existing.map { $0.colorName })
        guard !existingColorNames.contains("canteen") else { return }

        let studentCategories: [(String, String, String, Int)] = [
            ("食堂", "tray.fill",            "canteen",    100),
            ("奶茶", "cup.and.saucer.fill",  "boba",       101),
            ("文具", "pencil.and.ruler",     "stationery", 102),
            ("打印", "printer.fill",         "printing",   103),
            ("社团", "person.3.fill",        "club",       104),
        ]
        for item in studentCategories {
            modelContext.insert(Category(
                name: item.0, icon: item.1, type: 0,
                sortOrder: item.3, isDefault: false, colorName: item.2
            ))
        }
        save()
    }

    // MARK: ── 内部工具 ───────────────────────────────────

    func refreshShortcutSnapshot(referenceDate: Date = Date()) {
        guard let currentBook = getCurrentBook() else {
            AppShortcutStore.clearMonthlyBalanceSnapshot()
            return
        }

        let totals = getMonthTotal(for: referenceDate, bookId: currentBook.id)
        AppShortcutStore.saveMonthlyBalanceSnapshot(
            income: totals.income,
            expense: totals.expense,
            bookName: currentBook.name,
            referenceDate: referenceDate
        )
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }
}
