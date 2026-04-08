import SwiftUI

struct AIInsightCard: View {
    let insight: String
    let isLoading: Bool
    let onRefresh: () -> Void

    @State private var isExpanded: Bool = true

    var body: some View {
        SonnetCard {
            VStack(alignment: .leading, spacing: 0) {
                // Header – always visible
                headerRow

                // Expandable body
                if isExpanded {
                    Rectangle()
                        .fill(SonnetColors.paperLine)
                        .frame(height: 0.5)
                        .padding(.horizontal, SonnetDimens.spacingL)

                    bodyContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(SonnetColors.inkWash)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusLarge))
        }
    }

    // MARK: – Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("✦")
                .font(.system(size: 16))
                .foregroundStyle(SonnetColors.ink)

            Text("AI 消费洞察")
                .font(SonnetTypography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(SonnetColors.textTitle)

            Spacer()

            if !insight.isEmpty && !isLoading {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundStyle(SonnetColors.textHint)
                }
                .padding(.trailing, 2)
            }

            Button {
                withAnimation(SonnetMotion.spring) { isExpanded.toggle() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SonnetColors.textHint)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(SonnetMotion.spring, value: isExpanded)
            }
        }
        .padding(SonnetDimens.spacingL)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(SonnetMotion.spring) { isExpanded.toggle() }
        }
    }

    // MARK: – Body

    @ViewBuilder
    private var bodyContent: some View {
        if isLoading {
            HStack(spacing: SonnetDimens.spacingS) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(SonnetColors.ink)
                Text("正在分析消费数据…")
                    .font(SonnetTypography.footnote)
                    .foregroundStyle(SonnetColors.textCaption)
            }
            .padding(SonnetDimens.spacingL)
        } else if insight.isEmpty {
            VStack(spacing: SonnetDimens.spacingS) {
                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                        Text("生成本月洞察")
                            .font(SonnetTypography.footnote)
                    }
                    .foregroundStyle(SonnetColors.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(SonnetColors.paperWhite.opacity(0.7))
                    .clipShape(Capsule())
                }

                Text("记录更多数据后，AI 将为你生成消费洞察")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textHint)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(SonnetDimens.spacingL)
        } else {
            Text(insight)
                .font(SonnetTypography.footnote)
                .foregroundStyle(SonnetColors.textBody)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SonnetDimens.spacingL)
        }
    }
}

// MARK: – Preview

#Preview {
    VStack(spacing: 16) {
        AIInsightCard(
            insight: "本月餐饮支出占比最高，达 42%，比上月增加 15%。建议适当减少外卖频率，尝试自炊以节省开支。交通费用保持稳定，表现良好。",
            isLoading: false,
            onRefresh: {}
        )

        AIInsightCard(insight: "", isLoading: false, onRefresh: {})

        AIInsightCard(insight: "", isLoading: true, onRefresh: {})
    }
    .padding(20)
    .background(SonnetColors.paper)
}
