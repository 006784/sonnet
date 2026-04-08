import SwiftData
import Foundation

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = ""          // SF Symbol 名
    var type: Int = 0              // 0=支出, 1=收入
    var sortOrder: Int = 0
    var isDefault: Bool = true
    var colorName: String = ""     // 色彩标识（"food","transport"等）

    init(
        name: String,
        icon: String,
        type: Int,
        sortOrder: Int,
        isDefault: Bool = true,
        colorName: String
    ) {
        self.name = name
        self.icon = icon
        self.type = type
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.colorName = colorName
    }
}
