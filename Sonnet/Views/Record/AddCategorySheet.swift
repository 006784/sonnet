import SwiftUI
import SwiftData

struct AddCategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: RecordType = .expense

    init(initialType: RecordType = .expense) {
        _type = State(initialValue: initialType)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    SonnetCard {
                        VStack(spacing: 0) {
                            Picker("类型", selection: $type) {
                                ForEach(RecordType.allCases, id: \.rawValue) {
                                    Text($0.label).tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(SonnetDimens.cardPadding)

                            Rectangle()
                                .fill(SonnetColors.paperLine)
                                .frame(height: 0.5)
                                .padding(.leading, SonnetDimens.cardPadding)

                            SonnetTextField(placeholder: "分类名称", text: $name, icon: "tag")
                                .padding(SonnetDimens.cardPadding)
                        }
                    }

                    Text("新分类会出现在当前类型列表的末尾，并自动沿用 Sonnet 的配色体系。")
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textCaption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)
            }
            .background(SonnetColors.paper)
            .navigationTitle("添加分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { save() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let selectedType = type.rawValue
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate<Category> { category in
            category.type == selectedType
        })
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        let icon = type == .expense ? "tag.fill" : "banknote.fill"
        let cat = Category(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            type: type.rawValue,
            sortOrder: count + 1000,
            colorName: "other"
        )
        modelContext.insert(cat)
        try? modelContext.save()
        dismiss()
    }
}
