import SwiftUI
import SwiftData

struct CategoryGrid: View {
    let type: RecordType
    @Binding var selected: Category?
    @State private var showAddCategory = false

    @Query private var categories: [Category]

    private var filtered: [Category] {
        categories.filter { $0.type == type.rawValue }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 4),
            spacing: SonnetDimens.spacingL
        ) {
            ForEach(filtered) { category in
                categoryCell(category)
            }

            // "+" 添加分类
            addCategoryCell
        }
        .padding(.horizontal, SonnetDimens.spacingL)
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(initialType: type)
        }
    }

    private func categoryCell(_ category: Category) -> some View {
        let isSelected = selected?.id == category.id
        return Button {
            withAnimation(SonnetMotion.spring) { selected = category }
            HapticManager.selection()
        } label: {
            VStack(spacing: SonnetDimens.spacingXS) {
                CategoryIcon(
                    category: category,
                    size: 48,
                    cornerRadius: 14,
                    isSelected: isSelected
                )
                Text(category.name)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? SonnetColors.ink : SonnetColors.textCaption)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 44, minHeight: 44)
    }

    private var addCategoryCell: some View {
        Button { showAddCategory = true } label: {
            VStack(spacing: SonnetDimens.spacingXS) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            SonnetColors.paperLine,
                            style: StrokeStyle(lineWidth: 1, dash: [4])
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SonnetColors.textHint)
                }

                Text("添加")
                    .font(.system(size: 10))
                    .foregroundStyle(SonnetColors.textHint)
            }
        }
        .frame(minWidth: 44, minHeight: 44)
    }
}

#Preview {
    @Previewable @State var selected: Category? = nil
    return CategoryGrid(type: .expense, selected: $selected)
        .modelContainer(for: [Category.self], inMemory: true)
}
