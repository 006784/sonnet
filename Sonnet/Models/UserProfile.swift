import Foundation

// 用户信息不存 SwiftData，存 Keychain
struct UserProfile: Codable {
    var userId: String
    var displayName: String
    var email: String?
    var avatarData: Data?
    var loginMethod: LoginMethod
    var createdAt: Date

    enum LoginMethod: String, Codable {
        case apple
        case guest
    }
}

// UI 层数据模型
struct DailyRecordGroup: Identifiable {
    let id = UUID()
    let date: Date
    let records: [Record]
    var totalIncome: Double { records.filter { $0.type == 1 }.reduce(0) { $0 + $1.amount } }
    var totalExpense: Double { records.filter { $0.type == 0 }.reduce(0) { $0 + $1.amount } }
}

struct CategorySummary: Identifiable {
    let id = UUID()
    let category: Category
    let totalAmount: Double
    let percentage: Double
    let count: Int
}

struct MonthlyTrend: Identifiable {
    let id = UUID()
    let month: Date
    let totalIncome: Double
    let totalExpense: Double
}

enum RecordType: Int, CaseIterable {
    case expense = 0
    case income = 1

    var label: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        }
    }
}
