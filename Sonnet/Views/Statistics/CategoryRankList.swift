import SwiftUI

struct CategoryRankList: View {
    let summaries: [CategorySummary]

    @State private var visibleCount: Int = 0

    private var capped: [CategorySummary] { Array(summaries.prefix(8)) }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(capped.enumerated()), id: \.element.id) { idx, summary in
                rowView(idx: idx, summary: summary)
                if idx < capped.count - 1 {
                    Rectangle()
                        .fill(SonnetColors.paperLine)
                        .frame(height: 0.5)
                        .padding(.leading, 18)
                }
            }
        }
        .onAppear { triggerAnimation() }
        .onChange(of: capped.count) { _, _ in
            visibleCount = 0
            triggerAnimation()
        }
    }

    private func triggerAnimation() {
        for i in 0..<capped.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.07) {
                withAnimation(SonnetMotion.spring) { visibleCount = i + 1 }
            }
        }
    }

    @ViewBuilder
    private func rowView(idx: Int, summary: CategorySummary) -> some View {
        let isVisible = idx < visibleCount
        let colors = SonnetColors.categoryColors(summary.category.colorName)

        HStack(spacing: 0) {
            // Rank badge
            rankBadge(idx: idx)
                .frame(width: 20)

            Spacer().frame(width: 8)

            // Category icon 32pt r10
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors.bg)
                    .frame(width: 32, height: 32)
                Image(systemName: summary.category.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(colors.icon)
            }

            Spacer().frame(width: 8)

            // Name + progress bar
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.category.name)
                    .font(.system(size: 14))
                    .foregroundStyle(SonnetColors.textBody)
                    .lineLimit(1)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(SonnetColors.paperCream)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colors.icon)
                            .frame(width: isVisible ? max(geo.size.width * summary.percentage, 4) : 0,
                                   height: 6)
                    }
                }
                .frame(height: 6)
                .animation(SonnetMotion.springSlow.delay(Double(idx) * 0.07), value: isVisible)
            }

            Spacer(minLength: 12)

            // Amount + percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(CurrencyUtils.format(summary.totalAmount))")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(SonnetColors.textBody)
                Text("\(Int((summary.percentage * 100).rounded()))%")
                    .font(.system(size: 11))
                    .foregroundStyle(SonnetColors.textHint)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 6)
        .animation(SonnetMotion.spring.delay(Double(idx) * 0.07), value: isVisible)
    }

    @ViewBuilder
    private func rankBadge(idx: Int) -> some View {
        switch idx {
        case 0:
            Text("①")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SonnetColors.ink)
        case 1:
            Text("②")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SonnetColors.inkLight)
        case 2:
            Text("③")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SonnetColors.inkPale)
        default:
            Text("\(idx + 1)")
                .font(SonnetTypography.caption1)
                .foregroundStyle(SonnetColors.textHint)
        }
    }
}

// MARK: – Preview

#Preview {
    let categories: [(String, String, String)] = [
        ("餐饮", "fork.knife", "food"),
        ("交通", "car.fill", "transport"),
        ("购物", "bag.fill", "shopping"),
        ("娱乐", "gamecontroller.fill", "entertain")
    ]

    let summaries = categories.enumerated().map { idx, info in
        let cat = Category(name: info.0, icon: info.1, type: 0, sortOrder: idx, colorName: info.2)
        let pct = [0.42, 0.28, 0.18, 0.12][idx]
        return CategorySummary(category: cat, totalAmount: Double([1260, 840, 540, 360][idx]),
                               percentage: pct, count: idx + 2)
    }

    SonnetCard {
        CategoryRankList(summaries: summaries)
    }
    .padding()
    .background(SonnetColors.paper)
}
