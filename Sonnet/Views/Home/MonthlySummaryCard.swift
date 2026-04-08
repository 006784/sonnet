import SwiftUI

struct MonthlySummaryCard: View {
    let income: Double
    let expense: Double
    let balance: Double
    let month: Date
    var bookName: String = "日常账本"
    var budgetUsedPercent: Double = 0   // 0 = 不显示预算行
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var slideDirection: Int = 0  // -1=向左, 1=向右

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── 行 1：月份 + 账本胶囊 ──
            HStack(alignment: .center) {
                Text(DateUtils.monthString(month))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .contentTransition(.identity)

                Spacer()

                Text(bookName)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }

            // ── 行 2：三列（支出 / 收入 / 结余）──
            HStack(spacing: 0) {
                summaryCol(label: "支出", amount: expense)
                summaryCol(label: "收入", amount: income)
                summaryCol(label: "结余", amount: balance)
            }

            // ── 行 3：PoetryDivider ──
            PoetryDivider(isWhite: true)

            // ── 行 4：预算 ──
            if budgetUsedPercent > 0 {
                Text("预算已使用 \(Int(budgetUsedPercent))%")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [SonnetColors.ink, SonnetColors.inkLight, SonnetColors.inkPale],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // 左右滑动切换月份
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let dx = value.translation.width
                    if dx < -50 {
                        withAnimation(SonnetMotion.spring) { onNext() }
                    } else if dx > 50 {
                        withAnimation(SonnetMotion.spring) { onPrevious() }
                    }
                }
        )
    }

    private func summaryCol(label: String, amount: Double) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.60))

            Text("¥\(CurrencyUtils.format(amount))")
                .font(SonnetTypography.amountLarge)
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .tracking(-0.8)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MonthlySummaryCard(
        income: 8500,
        expense: 3260,
        balance: 5240,
        month: Date(),
        bookName: "日常账本",
        budgetUsedPercent: 30,
        onPrevious: {},
        onNext: {}
    )
    .padding(.horizontal, 20)
    .background(SonnetColors.paper)
}
