import SwiftUI
import AppIntents

struct SiriShortcutsGuideView: View {
    private let examples = [
        ("快速记账", "“用十四行诗记一笔”"),
        ("记录收入", "“十四行诗记一笔收入”"),
        ("查看本月", "“用十四行诗查余额”")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: SonnetDimens.spacingL) {
                SonnetCard {
                    VStack(alignment: .leading, spacing: SonnetDimens.spacingL) {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.badge.mic")
                                .font(.system(size: 18))
                                .foregroundStyle(SonnetColors.ink)
                            Text("把 Sonnet 交给 Siri")
                                .font(SonnetTypography.titleSection)
                                .foregroundStyle(SonnetColors.textTitle)
                        }

                        Text("你可以在 Siri 或快捷指令里直接发起记账、记录收入和查询本月支出。")
                            .font(SonnetTypography.body)
                            .foregroundStyle(SonnetColors.textCaption)
                            .lineSpacing(4)

                        InkButton(
                            title: "刷新快捷指令",
                            action: refreshShortcuts,
                            style: .primary
                        )
                    }
                    .padding(SonnetDimens.cardPadding)
                }

                SonnetCard {
                    VStack(spacing: 0) {
                        ForEach(Array(examples.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.0)
                                        .font(SonnetTypography.bodyBold)
                                        .foregroundStyle(SonnetColors.textTitle)
                                    Text(item.1)
                                        .font(SonnetTypography.caption1)
                                        .foregroundStyle(SonnetColors.textCaption)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, SonnetDimens.cardPadding)
                            .padding(.vertical, 16)

                            if index < examples.count - 1 {
                                Rectangle()
                                    .fill(SonnetColors.paperLine)
                                    .frame(height: 0.5)
                                    .padding(.leading, SonnetDimens.cardPadding)
                            }
                        }
                    }
                }

                SonnetCard {
                    Text("如果 Siri 没有立即识别到这些短语，先点击上方刷新，再打开“快捷指令”App 搜索 Sonnet。")
                        .font(SonnetTypography.footnote)
                        .foregroundStyle(SonnetColors.textCaption)
                        .lineSpacing(4)
                        .padding(SonnetDimens.cardPadding)
                }
            }
            .padding(.horizontal, SonnetDimens.pageHorizontal)
            .padding(.top, SonnetDimens.spacingL)
        }
        .background(SonnetColors.paper)
        .navigationTitle("Siri 快捷指令")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func refreshShortcuts() {
        SiriService.updateShortcuts()
        SonnetShortcuts.updateAppShortcutParameters()
        HapticManager.success()
    }
}

#Preview {
    NavigationStack {
        SiriShortcutsGuideView()
    }
}
