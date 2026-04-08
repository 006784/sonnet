import SwiftData
import Foundation

@Model
final class Record {
    var id: UUID = UUID()
    var amount: Double = 0.0
    var categoryId: UUID = UUID()
    var note: String = ""
    var date: Date = Date()
    var type: Int = 0              // 0=支出, 1=收入
    var accountBookId: UUID = UUID()
    var createdAt: Date = Date()

    @Relationship var category: Category?
    @Relationship var accountBook: AccountBook?

    init(
        amount: Double,
        categoryId: UUID,
        note: String = "",
        date: Date = Date(),
        type: Int = 0,
        accountBookId: UUID
    ) {
        self.amount = amount
        self.categoryId = categoryId
        self.note = note
        self.date = date
        self.type = type
        self.accountBookId = accountBookId
    }
}
