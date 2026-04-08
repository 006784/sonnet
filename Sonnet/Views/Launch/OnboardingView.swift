import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var appeared = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            keyword: "Paper",
            title: "每一笔，都值得被认真写下",
            subtitle: "像翻开一本安静的诗集，记录生活的收支与日常。",
            footnote: "留白、秩序和呼吸感，会贯穿你看到的每一页。",
            accent: SonnetColors.ink
        ),
        OnboardingPage(
            keyword: "Intelligence",
            title: "AI 帮你少输一点",
            subtitle: "支持 OCR 小票识别、语音记账和月度洞察，但始终保留确认与编辑。",
            footnote: "所有 AI 结果都可以确认、修改，再决定是否入账。",
            accent: SonnetColors.jade
        ),
        OnboardingPage(
            keyword: "Rhythm",
            title: "按角色延展你的生活节奏",
            subtitle: "学生模式会把课表、待办、专注与生活费管理自然接进来。",
            footnote: "首页、学习与统计会跟着你的角色一起变化。",
            accent: SonnetColors.amber
        )
    ]

    var body: some View {
        ZStack {
            SonnetColors.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 0) {
                            Spacer()

                            pageArtwork(index: index, accent: page.accent)
                                .frame(width: 132, height: 132)
                                .padding(.bottom, 36)

                            VStack(spacing: SonnetDimens.spacingM) {
                                Text(page.keyword)
                                    .font(SonnetTypography.label)
                                    .foregroundStyle(page.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(page.accent.opacity(0.10))
                                    .clipShape(Capsule())

                                Text(page.title)
                                    .font(SonnetTypography.titlePage)
                                    .foregroundStyle(SonnetColors.textTitle)
                                    .multilineTextAlignment(.center)

                                Text(page.subtitle)
                                    .font(SonnetTypography.body)
                                    .foregroundStyle(SonnetColors.textCaption)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(6)

                                Text(page.footnote)
                                    .font(SonnetTypography.caption1)
                                    .foregroundStyle(SonnetColors.textHint)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 36)

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                VStack(spacing: SonnetDimens.spacingL) {
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? SonnetColors.ink : SonnetColors.paperLine)
                                .frame(width: index == currentPage ? 20 : 8, height: 8)
                                .animation(SonnetMotion.spring, value: currentPage)
                        }
                    }

                    InkButton(
                        title: currentPage == pages.count - 1 ? "开始使用" : "继续",
                        action: advance
                    )
                    .frame(width: 280)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(SonnetMotion.springSlow) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func pageArtwork(index: Int, accent: Color) -> some View {
        ZStack {
            Circle()
                .fill(SonnetColors.paperWhite)
                .frame(width: 132, height: 132)
                .overlay(
                    Circle()
                        .stroke(SonnetColors.paperLine, lineWidth: 1)
                )

            Circle()
                .fill(accent.opacity(0.08))
                .frame(width: 104, height: 104)

            switch index {
            case 0:
                AppIconSymbol()
                    .frame(width: 72, height: 72)
            case 1:
                Image(systemName: "waveform.and.magnifyingglass")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(accent)
            default:
                Image(systemName: "graduationcap.and.pencil")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(accent)
            }
        }
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation(SonnetMotion.spring) {
                currentPage += 1
            }
        } else {
            onComplete()
        }
    }
}

private struct OnboardingPage {
    let keyword: String
    let title: String
    let subtitle: String
    let footnote: String
    let accent: Color
}
