import SwiftUI

struct BudgetSettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var accountBook: AccountBook
    @State private var budgetInput: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Input card
                    SonnetCard {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("月预算金额")
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(SonnetColors.textCaption)
                                .padding(.horizontal, 18)
                                .padding(.top, 14)
                                .padding(.bottom, 8)

                            Rectangle()
                                .fill(SonnetColors.paperLine)
                                .frame(height: 0.5)
                                .padding(.leading, 18)

                            HStack(spacing: 8) {
                                Text("¥")
                                    .font(SonnetTypography.amountMedium)
                                    .foregroundStyle(SonnetColors.ink)

                                TextField("0", text: $budgetInput)
                                    .font(SonnetTypography.amountMedium)
                                    .foregroundStyle(SonnetColors.textTitle)
                                    .keyboardType(.decimalPad)
                                    .focused($inputFocused)

                                if !budgetInput.isEmpty {
                                    Button {
                                        budgetInput = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(SonnetColors.textHint)
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 64)
                        }
                    }

                    // Hint card
                    SonnetCard {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 15))
                                .foregroundStyle(SonnetColors.inkPale)
                                .padding(.top, 1)
                            Text("设置月预算后，当月支出超出预算时将收到提醒。输入 0 或留空表示不限预算。")
                                .font(SonnetTypography.footnote)
                                .foregroundStyle(SonnetColors.textCaption)
                                .lineSpacing(4)
                        }
                        .padding(16)
                    }

                    // Current budget display
                    if accountBook.budget > 0 {
                        HStack {
                            Text("当前预算")
                                .font(SonnetTypography.caption1)
                                .foregroundStyle(SonnetColors.textCaption)
                            Spacer()
                            Text("¥\(CurrencyUtils.format(accountBook.budget))")
                                .font(SonnetTypography.footnote)
                                .fontWeight(.medium)
                                .foregroundStyle(SonnetColors.ink)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(SonnetColors.paper)
            .navigationTitle("预算设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(SonnetColors.textSecond)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        accountBook.budget = Double(budgetInput) ?? 0
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(SonnetColors.ink)
                }
            }
            .onAppear {
                budgetInput = accountBook.budget > 0 ? String(Int(accountBook.budget)) : ""
                inputFocused = true
            }
        }
    }
}

// MARK: – Preview

#Preview {
    let book = AccountBook(name: "日常账本", budget: 3000)
    BudgetSettingSheet(accountBook: book)
}
