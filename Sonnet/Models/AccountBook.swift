import SwiftData
import Foundation

@Model
final class AccountBook {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "book"
    var budget: Double = 0.0       // 月预算（0=不限）
    var createdAt: Date = Date()
    var isSelected: Bool = false   // 当前选中

    init(name: String, icon: String = "book", budget: Double = 0.0, isSelected: Bool = false) {
        self.name = name
        self.icon = icon
        self.budget = budget
        self.isSelected = isSelected
    }
}
