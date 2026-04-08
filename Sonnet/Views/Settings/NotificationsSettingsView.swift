import SwiftUI

struct NotificationsSettingsView: View {
    @AppStorage("notifications_enabled") private var notificationsEnabled = false
    @AppStorage("budget_alert_enabled") private var budgetAlertEnabled = true
    @State private var courseReminderEnabled = true

    var body: some View {
        ScrollView {
            VStack(spacing: SonnetDimens.spacingL) {
                SonnetCard {
                    VStack(spacing: 0) {
                        settingsToggle(
                            title: "允许应用通知",
                            subtitle: "用于预算提醒、课程提醒和关键状态提示",
                            isOn: $notificationsEnabled
                        ) { enabled in
                            if enabled {
                                NotificationService.shared.requestPermission()
                            }
                        }

                        divider

                        settingsToggle(
                            title: "预算提醒",
                            subtitle: "当本月预算接近或超出时提醒你",
                            isOn: $budgetAlertEnabled
                        ) { _ in }

                        divider

                        settingsToggle(
                            title: "课程提醒",
                            subtitle: "学生模式下可为课程安排上课前提醒",
                            isOn: $courseReminderEnabled
                        ) { enabled in
                            if enabled && notificationsEnabled {
                                NotificationService.shared.requestPermission()
                            }
                        }
                    }
                }

                SonnetCard {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 15))
                            .foregroundStyle(SonnetColors.ink)
                            .padding(.top, 2)

                        Text("课程提醒是否真正送达，还取决于系统通知权限与专注模式设置。你可以先在这里开启，再到系统设置里进一步调整。")
                            .font(SonnetTypography.footnote)
                            .foregroundStyle(SonnetColors.textCaption)
                            .lineSpacing(4)
                    }
                    .padding(SonnetDimens.cardPadding)
                }
            }
            .padding(.horizontal, SonnetDimens.pageHorizontal)
            .padding(.top, SonnetDimens.spacingL)
        }
        .background(SonnetColors.paper)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var divider: some View {
        Rectangle()
            .fill(SonnetColors.paperLine)
            .frame(height: 0.5)
            .padding(.leading, SonnetDimens.cardPadding)
    }

    private func settingsToggle(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SonnetTypography.body)
                        .foregroundStyle(SonnetColors.textTitle)
                    Text(subtitle)
                        .font(SonnetTypography.caption2)
                        .foregroundStyle(SonnetColors.textCaption)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(SonnetColors.ink)
            }
            .padding(.horizontal, SonnetDimens.cardPadding)
            .padding(.vertical, 16)
            .onChange(of: isOn.wrappedValue) { _, newValue in
                onChange(newValue)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
