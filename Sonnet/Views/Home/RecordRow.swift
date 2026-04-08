import SwiftUI
import SwiftData

struct RecordRow: View {
    let record: Record
    var index: Int = 0
    var onDelete: (() -> Void)? = nil

    @State private var showEdit = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: SonnetDimens.spacingM) {
            // 分类图标
            if let category = record.category {
                CategoryIcon(category: category, size: 40, cornerRadius: 12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(SonnetColors.paperCream)
                    .frame(width: 40, height: 40)
            }

            // 名称 + 备注
            VStack(alignment: .leading, spacing: 2) {
                Text(record.category?.name ?? "未分类")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SonnetColors.textBody)

                if !record.note.isEmpty {
                    Text(record.note)
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textHint)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 金额 + 时间
            VStack(alignment: .trailing, spacing: 2) {
                let prefix = record.type == 0 ? "-" : "+"
                let amtColor = record.type == 0 ? SonnetColors.vermilion : SonnetColors.jade
                Text("\(prefix)¥\(CurrencyUtils.format(record.amount))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(amtColor)

                Text(DateUtils.timeString(record.date))
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(SonnetColors.textHint)
            }
        }
        .frame(minHeight: 64)
        .padding(.horizontal, SonnetDimens.spacingL)
        .padding(.vertical, SonnetDimens.spacingS)
        .contentShape(Rectangle())
        .onTapGesture { showEdit = true }
        // 左滑删除
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let del = onDelete {
                Button(role: .destructive, action: del) {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        // 入场动画
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 20)
        .onAppear {
            withAnimation(
                Animation.spring(response: 0.4, dampingFraction: 0.75)
                    .delay(Double(index) * 0.035)
            ) {
                appeared = true
            }
        }
        .sheet(isPresented: $showEdit) {
            RecordView(editingRecord: record)
        }
    }
}

#Preview {
    let cat = Category(name: "餐饮", icon: "fork.knife", type: 0, sortOrder: 0, colorName: "food")
    let rec = Record(amount: 35, categoryId: cat.id, note: "午饭", type: 0, accountBookId: UUID())
    rec.category = cat
    return List {
        RecordRow(record: rec, index: 0)
        RecordRow(record: rec, index: 1, onDelete: {})
    }
    .listStyle(.plain)
}
