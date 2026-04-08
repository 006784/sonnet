import SwiftUI

struct CategoryIcon: View {
    let category: Category
    var size: CGFloat = 40
    var cornerRadius: CGFloat = 12
    var isSelected: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var iconSize: CGFloat { size * 0.46 }

    var body: some View {
        let colors = SonnetColors.categoryColors(category.colorName)
        let bgColor: Color = colorScheme == .dark
            ? colors.icon.opacity(0.12)
            : colors.bg

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(bgColor)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(colors.icon, lineWidth: isSelected ? 2 : 0)
                )

            Image(systemName: category.icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(colors.icon)
        }
        .scaleEffect(isSelected ? 1.06 : 1)
        .animation(SonnetMotion.spring, value: isSelected)
    }
}

#Preview {
    let cat = Category(name: "餐饮", icon: "fork.knife", type: 0, sortOrder: 0, colorName: "food")
    return HStack(spacing: 16) {
        CategoryIcon(category: cat, size: 40, cornerRadius: 12)
        CategoryIcon(category: cat, size: 40, cornerRadius: 12, isSelected: true)
        CategoryIcon(category: cat, size: 48, cornerRadius: 14)
        CategoryIcon(category: cat, size: 48, cornerRadius: 14, isSelected: true)
    }
    .padding()
    .background(SonnetColors.paper)
}
