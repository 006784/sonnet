import SwiftUI

struct TimerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var totalSeconds: Int

    // 持久化设置
    @AppStorage("timer_default_duration") private var defaultDuration = 1500
    @AppStorage("timer_short_break")      private var shortBreak      = 300
    @AppStorage("timer_long_break_after") private var longBreakAfter  = 4
    @AppStorage("timer_sound_enabled")    private var soundEnabled     = true

    private let focusPresets  = [(15, "15 分钟"), (25, "25 分钟"), (45, "45 分钟"), (60, "60 分钟")]
    private let breakPresets  = [(5,  "5 分钟"),  (10, "10 分钟")]
    private let intervalOpts  = [2, 3, 4, 5, 6]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SonnetDimens.spacingL) {
                    heroCard
                    focusSection
                    breakSection
                    alertSection
                }
                .padding(.horizontal, SonnetDimens.pageHorizontal)
                .padding(.top, SonnetDimens.spacingL)
                .padding(.bottom, SonnetDimens.spacingXXL)
            }
            .background(SonnetColors.paper)
            .navigationTitle("计时设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        HapticManager.medium()
                        dismiss()
                    }
                        .fontWeight(.semibold)
                        .foregroundStyle(SonnetColors.ink)
                }
            }
        }
    }

    private var heroCard: some View {
        StudentHeroCard(
            title: "把专注节奏调成适合自己的呼吸",
            subtitle: "专注、休息和提示会一起影响今天的学习韵律。",
            icon: "timer",
            colorName: "education"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "专注", value: "\(totalSeconds / 60) 分钟", tint: SonnetColors.ink)
                StudentMetricPill(title: "短休息", value: "\(shortBreak / 60) 分钟", tint: SonnetColors.jade)
                StudentMetricPill(title: "长休息间隔", value: "每 \(longBreakAfter) 个", tint: SonnetColors.amber)
            }
        }
    }

    private var focusSection: some View {
        StudentFormSection(
            title: "专注时长",
            subtitle: "给一次番茄钟一个清晰的长度。"
        ) {
            flexibleChipRow(items: focusPresets, selectedSeconds: totalSeconds) { minutes in
                let seconds = minutes * 60
                totalSeconds = seconds
                defaultDuration = seconds
                HapticManager.selection()
            }

            StudentFormDivider()

            Stepper(value: customFocusBinding, in: 5...120, step: 5) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("自定义")
                            .font(SonnetTypography.body)
                            .foregroundStyle(SonnetColors.textTitle)
                        Text("按 5 分钟递增微调")
                            .font(SonnetTypography.caption2)
                            .foregroundStyle(SonnetColors.textCaption)
                    }
                    Spacer()
                    Text("\(totalSeconds / 60) 分钟")
                        .font(SonnetTypography.amountBody)
                        .foregroundStyle(SonnetColors.ink)
                        .monospacedDigit()
                }
            }
            .tint(SonnetColors.ink)
        }
    }

    private var breakSection: some View {
        StudentFormSection(
            title: "休息节奏",
            subtitle: "短休息负责回气，长休息负责重置。"
        ) {
            VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                Text("短休息")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)

                flexibleChipRow(items: breakPresets, selectedSeconds: shortBreak) { minutes in
                    shortBreak = minutes * 60
                    HapticManager.selection()
                }
            }

            StudentFormDivider()

            VStack(alignment: .leading, spacing: SonnetDimens.spacingS) {
                Text("长休息间隔")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SonnetDimens.spacingS) {
                        ForEach(intervalOpts, id: \.self) { option in
                            StudentChoiceChip(
                                title: "每 \(option) 个",
                                systemImage: longBreakAfter == option ? "checkmark" : nil,
                                isSelected: longBreakAfter == option,
                                tint: SonnetColors.amber
                            ) {
                                longBreakAfter = option
                                HapticManager.selection()
                            }
                        }
                    }
                }
            }
        }
    }

    private var alertSection: some View {
        StudentFormSection(
            title: "提示设置",
            subtitle: "只保留真正有用的提醒，不打断节奏。"
        ) {
            HStack {
                Label("完成提示音", systemImage: "bell.fill")
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textBody)
                Spacer()
                Toggle("", isOn: $soundEnabled)
                    .labelsHidden()
                    .tint(SonnetColors.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(SonnetColors.paperWhite)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                    .stroke(SonnetColors.paperLine, lineWidth: 0.5)
            )

            HStack {
                Label("锁屏 Live Activity", systemImage: "lock.display")
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textBody)
                Spacer()
                Text("即将支持")
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textHint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SonnetColors.paperLight)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(SonnetColors.paperWhite)
            .clipShape(RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SonnetDimens.radiusMedium, style: .continuous)
                    .stroke(SonnetColors.paperLine, lineWidth: 0.5)
            )
        }
    }

    private var customFocusBinding: Binding<Int> {
        Binding(
            get: { totalSeconds / 60 },
            set: { newValue in
                totalSeconds = newValue * 60
                defaultDuration = totalSeconds
            }
        )
    }

    @ViewBuilder
    private func flexibleChipRow(
        items: [(Int, String)],
        selectedSeconds: Int,
        action: @escaping (Int) -> Void
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: SonnetDimens.spacingS), count: 2)

        LazyVGrid(columns: columns, spacing: SonnetDimens.spacingS) {
            ForEach(items, id: \.0) { minutes, label in
                StudentChoiceChip(
                    title: label,
                    systemImage: selectedSeconds == minutes * 60 ? "checkmark" : nil,
                    isSelected: selectedSeconds == minutes * 60,
                    tint: SonnetColors.ink
                ) {
                    action(minutes)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var seconds = 1500
    return TimerSettingsSheet(totalSeconds: $seconds)
}
