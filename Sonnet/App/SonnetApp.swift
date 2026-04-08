import SwiftUI
import SwiftData

@main
struct SonnetApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer
    @State private var appState    = AppState()
    @State private var authService = AuthService()
    @State private var dataService: DataService

    // 监听 SettingsView 写入的 AppStorage 值，保持与 AppState 同步
    @AppStorage("app_theme") private var appTheme: String = "system"

    init() {
        let schema = Schema([
            Record.self,
            Category.self,
            AccountBook.self,
            // 学生功能模型
            Course.self,
            TodoItem.self,
            FocusSession.self,
            StudyNote.self,
            Note.self,
            StudyFile.self,
            Exam.self,
            GradeRecord.self,
            GPARecord.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let c = try ModelContainer(for: schema, configurations: [config])
            container = c
            // DataService 需要 MainActor context，在 @MainActor init 中获取
            _dataService = State(wrappedValue: DataService(modelContext: c.mainContext))
        } catch {
            fatalError("SwiftData 初始化失败: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(authService)
                .environment(dataService)
                .preferredColorScheme(appState.themeMode.colorScheme)
                .onChange(of: authService.isAuthenticated) { _, newValue in
                    appState.syncAuthentication(
                        isLoggedIn: newValue,
                        profile: authService.currentUser
                    )
                }
                .onChange(of: appTheme) { _, newValue in
                    appState.setTheme(rawValue: newValue)
                }
                .task {
                    dataService.seedDefaultDataIfNeeded()
                    if appState.selectedRole == .student {
                        dataService.seedStudentCategories()
                    }
                    syncCurrentBook()
                    dataService.refreshShortcutSnapshot()
                    appState.refreshAIConfiguration()
                    SiriService.updateShortcuts()
                    appState.syncAuthentication(
                        isLoggedIn: authService.isAuthenticated,
                        profile: authService.currentUser
                    )
                }
                .task(id: authService.currentUser?.userId) {
                    appState.syncAuthentication(
                        isLoggedIn: authService.isAuthenticated,
                        profile: authService.currentUser
                    )
                }
                .task(id: appState.selectedRole?.rawValue) {
                    if appState.selectedRole == .student {
                        dataService.seedStudentCategories()
                    }
                    appState.selectDefaultTabIfNeeded()
                    syncCurrentBook()
                    dataService.refreshShortcutSnapshot()
                }
                .onChange(of: scenePhase) { _, newValue in
                    guard newValue == .active else { return }
                    syncCurrentBook()
                    dataService.refreshShortcutSnapshot()
                    syncPendingShortcutRequests()
                }
        }
        .modelContainer(container)
    }

    // MARK: - 内部工具

    @MainActor
    private func syncCurrentBook() {
        appState.syncCurrentBook(dataService.getCurrentBook())
    }

    @MainActor
    private func syncPendingShortcutRequests() {
        guard AppShortcutStore.peekQuickRecordDraft() != nil else { return }
        appState.selectedTab = .home
        appState.showingAddRecord = true
    }
}
