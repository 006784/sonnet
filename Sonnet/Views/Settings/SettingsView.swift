import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(AppState.self) private var appState
    @Environment(DataService.self) private var dataService

    @Query(filter: #Predicate<AccountBook> { $0.isSelected })
    private var selectedBooks: [AccountBook]

    @AppStorage("budget_alert_enabled") private var budgetAlertEnabled: Bool = true
    @AppStorage("notifications_enabled") private var notificationsEnabled: Bool = false
    @AppStorage("app_theme") private var appTheme: String = "system"

    @State private var showingBudget = false
    @State private var showingClearConfirm = false
    @State private var showingExport = false
    @State private var exportURL: URL? = nil
    @State private var isExporting = false
    @State private var exportErrorMessage: String?

    private let exportService = ExportService()

    private var currentBook: AccountBook? { selectedBooks.first }
    private var profile: UserProfile? { authService.currentProfile }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ── 个人信息卡片 ──────────────────────────
                profileCard

                // ── 账本管理 ─────────────────────────────
                settingGroup {
                    NavigationLink {
                        RoleSelectionView()
                    } label: {
                        settingRow(
                            title: "当前身份",
                            value: appState.selectedRole?.displayName ?? "未选择"
                        )
                    }
                    .buttonStyle(.plain)

                    dividerLine

                    NavigationLink {
                        AccountBookListView()
                    } label: {
                        settingRow(
                            title: "当前账本",
                            value: currentBook?.name ?? "未选择"
                        )
                    }
                    .buttonStyle(.plain)
                }

                // ── 预算设置 ─────────────────────────────
                settingGroup {
                    Button {
                        showingBudget = true
                    } label: {
                        settingRow(
                            title: "月预算",
                            value: currentBook.map {
                                $0.budget > 0 ? "¥\(CurrencyUtils.format($0.budget))" : "不限"
                            } ?? "—"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(currentBook == nil)

                    dividerLine

                    settingToggleRow(title: "超支提醒", binding: $budgetAlertEnabled)
                }

                // ── AI 功能 ──────────────────────────────
                settingGroup {
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        settingRow(title: "AI 功能", value: currentAIModel)
                    }
                    .buttonStyle(.plain)
                }

                settingGroup {
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        settingRow(title: "通知", value: notificationsEnabled ? "已开启" : "未开启")
                    }
                    .buttonStyle(.plain)

                    dividerLine

                    NavigationLink {
                        SiriShortcutsGuideView()
                    } label: {
                        settingRow(title: "Siri 快捷指令", value: SiriService.isSiriAvailable ? "可使用" : "当前不可用")
                    }
                    .buttonStyle(.plain)
                }

                // ── 外观 ──────────────────────────────────
                settingGroup {
                    HStack {
                        Text("主题")
                            .font(SonnetTypography.body)
                            .foregroundStyle(SonnetColors.textTitle)
                        Spacer()
                        Picker("主题", selection: $appTheme) {
                            Text("浅色").tag("light")
                            Text("深色").tag("dark")
                            Text("自动").tag("system")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                }

                // ── 数据 ─────────────────────────────────
                settingGroup {
                    Button {
                        exportCSV()
                    } label: {
                        HStack {
                            Text("导出 CSV")
                                .font(SonnetTypography.body)
                                .foregroundStyle(SonnetColors.textTitle)
                            Spacer()
                            if isExporting {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15))
                                    .foregroundStyle(SonnetColors.textHint)
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)

                    dividerLine

                    Button {
                        showingClearConfirm = true
                    } label: {
                        HStack {
                            Text("清除所有数据")
                                .font(SonnetTypography.body)
                                .foregroundStyle(SonnetColors.vermilion)
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                }

                // ── 关于 ─────────────────────────────────
                settingGroup {
                    HStack {
                        Text("版本")
                            .font(SonnetTypography.body)
                            .foregroundStyle(SonnetColors.textTitle)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .font(SonnetTypography.body)
                            .foregroundStyle(SonnetColors.textHint)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 52)

                    dividerLine

                    settingSimpleRow(title: "开源许可")
                        .padding(.horizontal, 18)
                        .frame(height: 52)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(SonnetColors.paper)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingBudget) {
            if let book = currentBook {
                BudgetSettingSheet(accountBook: book)
            }
        }
        .sheet(isPresented: $showingExport) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .confirmationDialog("清除所有数据", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("确认清除", role: .destructive) { clearAllData() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可恢复，所有记账数据将被永久删除。")
        }
        .alert("导出失败", isPresented: .init(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "请稍后再试。")
        }
    }

    // MARK: – Profile card

    private var profileCard: some View {
        SonnetCard {
            NavigationLink {
                if let p = profile {
                    ProfileView(profile: p, onSignOut: { authService.signOut() })
                }
            } label: {
                HStack(spacing: 14) {
                    // Avatar initials
                    ZStack {
                        Circle()
                            .fill(SonnetColors.ink)
                            .frame(width: 60, height: 60)
                        Text(avatarInitial)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile?.displayName ?? "游客")
                            .font(SonnetTypography.title3)
                            .foregroundStyle(SonnetColors.textTitle)
                        Text(profile?.email ?? "游客模式")
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                        loginBadge
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SonnetColors.textHint)
                }
                .padding(18)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var loginBadge: some View {
        let method = profile?.loginMethod ?? .guest
        Text(method == .apple ? "Apple ID" : "游客")
            .font(SonnetTypography.caption2)
            .foregroundStyle(method == .apple ? SonnetColors.ink : SonnetColors.textHint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(method == .apple ? SonnetColors.inkWash : SonnetColors.paperCream)
            .clipShape(Capsule())
    }

    private var avatarInitial: String {
        (profile?.displayName.first.map(String.init)) ?? "G"
    }

    // MARK: – Setting group helpers

    @ViewBuilder
    private func settingGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        SonnetCard {
            VStack(spacing: 0) {
                content()
            }
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(SonnetTypography.body)
                .foregroundStyle(SonnetColors.textTitle)
            Spacer()
            Text(value)
                .font(SonnetTypography.body)
                .foregroundStyle(SonnetColors.textHint)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SonnetColors.textHint)
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
    }

    private func settingSimpleRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(SonnetTypography.body)
                .foregroundStyle(SonnetColors.textTitle)
            Spacer()
        }
    }

    private func settingToggleRow(title: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(SonnetTypography.body)
                .foregroundStyle(SonnetColors.textTitle)
            Spacer()
            Toggle("", isOn: binding)
                .tint(SonnetColors.ink)
                .labelsHidden()
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(SonnetColors.paperLine)
            .frame(height: 0.5)
            .padding(.leading, 18)
    }

    private var currentAIModel: String {
        let key = appState.aiConfiguration.selectedModel
        return key.components(separatedBy: "/").last ?? "未配置"
    }

    // MARK: – Actions

    private func exportCSV() {
        isExporting = true
        Task {
            let desc = FetchDescriptor<Record>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            let records = (try? modelContext.fetch(desc)) ?? []
            do {
                let url = try await exportService.exportCSV(records: records)
                await MainActor.run {
                    exportURL = url
                    isExporting = false
                    showingExport = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportErrorMessage = "未能生成导出文件，请稍后再试。"
                }
            }
        }
    }

    private func clearAllData() {
        try? modelContext.delete(model: Record.self)
        try? modelContext.delete(model: Category.self)
        try? modelContext.delete(model: AccountBook.self)
        try? modelContext.save()
        dataService.seedDefaultDataIfNeeded()
        if appState.selectedRole == .student {
            dataService.seedStudentCategories()
        }
        appState.syncCurrentBook(dataService.getCurrentBook())
        NotificationCenter.default.post(name: .sonnetRecordChanged, object: nil)
    }
}

// MARK: – ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: – Preview

#Preview {
    let container = try! ModelContainer(
        for: AccountBook.self, Record.self, Category.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    return NavigationStack {
        SettingsView()
    }
    .modelContainer(container)
    .environment(AppState())
    .environment(AuthService())
    .environment(DataService(modelContext: container.mainContext))
}
