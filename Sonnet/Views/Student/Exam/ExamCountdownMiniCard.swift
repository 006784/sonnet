import SwiftUI
import SwiftData

// MARK: - 考试倒计时迷你卡（HomeView 嵌入用）

struct ExamCountdownMiniCard: View {
    @Query(sort: [SortDescriptor(\Exam.date)])
    private var exams: [Exam]

    private var now: Date { Date() }

    /// 7 天内即将到来的考试
    private var upcoming: [Exam] {
        let limit = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return exams.filter {
            !$0.isCompleted && $0.date >= now && $0.date <= limit
        }
    }

    var body: some View {
        if upcoming.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 8) {
                Label("近期考试", systemImage: "calendar.badge.exclamationmark")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)

                ForEach(upcoming) { exam in
                    miniRow(exam)
                }
            }
            .padding(SonnetDimens.spacingL)
            .background(SonnetColors.paperCream)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge))
        }
    }

    private func miniRow(_ exam: Exam) -> some View {
        let days = Calendar.current.dateComponents([.day], from: now, to: exam.date).day ?? 0
        let isUrgent = days <= 3

        return HStack(spacing: 10) {
            // 倒计时数字
            VStack(spacing: 0) {
                Text("\(max(0, days))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(isUrgent ? SonnetColors.vermilion : SonnetColors.amber)
                Text("天")
                    .font(.system(size: 10))
                    .foregroundStyle(SonnetColors.textCaption)
            }
            .frame(width: 32)

            // 文案
            VStack(alignment: .leading, spacing: 2) {
                Text("距 \(exam.name.isEmpty ? exam.courseName : exam.name)")
                    .font(SonnetTypography.bodyBold)
                    .foregroundStyle(SonnetColors.textTitle)
                    .lineLimit(1)
                Text(DateUtils.dayString(exam.date))
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(SonnetColors.textHint)
            }

            Spacer()

            if isUrgent {
                PulsingDot()
            }
        }
    }
}

#Preview {
    ExamCountdownMiniCard()
        .padding()
        .modelContainer(for: Exam.self, inMemory: true)
}
