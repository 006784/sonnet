import SwiftUI
import SwiftData

struct DailyRecordGroupView: View {
    let group: DailyRecordGroup
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            // ── 日期标题行 ──
            HStack {
                Text(dayLabel(group.date))
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)

                Spacer()

                HStack(spacing: SonnetDimens.spacingS) {
                    if group.totalIncome > 0 {
                        Text("+¥\(CurrencyUtils.format(group.totalIncome))")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.jade)
                    }
                    if group.totalExpense > 0 {
                        Text("-¥\(CurrencyUtils.format(group.totalExpense))")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                    }
                }
            }
            .padding(.horizontal, SonnetDimens.spacingL)
            .padding(.vertical, SonnetDimens.spacingS)

            // ── 记录列表卡片 ──
            SonnetCard {
                VStack(spacing: 0) {
                    ForEach(Array(group.records.enumerated()), id: \.element.id) { idx, record in
                        RecordRow(
                            record: record,
                            index: idx,
                            onDelete: { deleteRecord(record) }
                        )
                        if idx < group.records.count - 1 {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
            }
        }
    }

    // 今天 / 昨天 / 日期
    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        return DateUtils.dayString(date)
    }

    private func deleteRecord(_ record: Record) {
        withAnimation(SonnetMotion.spring) {
            modelContext.delete(record)
            try? modelContext.save()
        }
        NotificationCenter.default.post(name: .sonnetRecordChanged, object: nil)
    }
}

#Preview {
    let cat = Category(name: "餐饮", icon: "fork.knife", type: 0, sortOrder: 0, colorName: "food")
    let rec = Record(amount: 38.5, categoryId: cat.id, note: "午饭", type: 0, accountBookId: UUID())
    rec.category = cat
    let grp = DailyRecordGroup(date: Date(), records: [rec])
    return DailyRecordGroupView(group: grp)
        .padding(.horizontal, 20)
        .background(SonnetColors.paper)
}
