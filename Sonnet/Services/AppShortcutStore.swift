import Foundation

struct QuickRecordDraft: Codable, Equatable {
    var amount: Double
    var categoryName: String
    var note: String
    var type: Int
    var createdAt: Date
}

struct MonthlyBalanceSnapshot: Codable, Equatable {
    var monthKey: String
    var income: Double
    var expense: Double
    var balance: Double
    var bookName: String
    var updatedAt: Date

    nonisolated var isCurrentMonth: Bool {
        monthKey == Self.monthKey(for: Date())
    }

    nonisolated static func monthKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }
}

enum AppShortcutStore {
    private static let quickRecordKey = "sonnet.quickRecordDraft"
    private static let monthlySnapshotKey = "sonnet.monthlyBalanceSnapshot"

    static func saveQuickRecordDraft(_ draft: QuickRecordDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: quickRecordKey)
    }

    static func peekQuickRecordDraft() -> QuickRecordDraft? {
        guard let data = UserDefaults.standard.data(forKey: quickRecordKey) else { return nil }
        return try? JSONDecoder().decode(QuickRecordDraft.self, from: data)
    }

    static func clearQuickRecordDraft() {
        UserDefaults.standard.removeObject(forKey: quickRecordKey)
    }

    static func saveMonthlyBalanceSnapshot(
        income: Double,
        expense: Double,
        bookName: String,
        referenceDate: Date = Date()
    ) {
        let snapshot = MonthlyBalanceSnapshot(
            monthKey: MonthlyBalanceSnapshot.monthKey(for: referenceDate),
            income: income,
            expense: expense,
            balance: income - expense,
            bookName: bookName,
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: monthlySnapshotKey)
    }

    static func loadMonthlyBalanceSnapshot() -> MonthlyBalanceSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: monthlySnapshotKey) else { return nil }
        return try? JSONDecoder().decode(MonthlyBalanceSnapshot.self, from: data)
    }

    static func clearMonthlyBalanceSnapshot() {
        UserDefaults.standard.removeObject(forKey: monthlySnapshotKey)
    }
}
