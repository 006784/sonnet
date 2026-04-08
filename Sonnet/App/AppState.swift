import SwiftUI
import SwiftData

@Observable
final class AppState {

    static let onboardingKey = "hasSeenOnboarding"
    static let roleKey = "sonnet_user_role"
    static let themeKey = "app_theme"
    static let aiEnabledKey = "ai_enabled"

    struct AIConfiguration {
        var isEnabled: Bool
        var selectedModel: String
        var hasAPIKey: Bool

        var isAvailable: Bool {
            isEnabled && hasAPIKey
        }
    }

    // MARK: - 启动 / 引导 / 认证

    var hasCompletedLaunch: Bool = false
    var hasCompletedOnboarding: Bool
    var isLoggedIn: Bool = false
    var currentUserProfile: UserProfile?

    // MARK: - 当前账本

    var currentBookId: UUID?
    var currentAccountBook: AccountBook?

    // MARK: - 主题

    var themeMode: ThemeMode = .system

    enum ThemeMode: String, CaseIterable {
        case light  = "浅色"
        case dark   = "深色"
        case system = "跟随系统"

        var colorScheme: ColorScheme? {
            switch self {
            case .light:  return .light
            case .dark:   return .dark
            case .system: return nil
            }
        }
    }

    // MARK: - 角色 / AI

    var selectedRole: UserRole? = nil
    var hasSelectedRole: Bool { selectedRole != nil }
    var aiConfiguration: AIConfiguration

    // MARK: - 导航

    var selectedTab: Tab = .home
    var showingAddRecord: Bool = false

    enum Tab: Int, CaseIterable {
        case home       = 0
        case roleTab    = 1   // 角色专属 Tab（学生=学习，其他角色类推）
        case statistics = 2
        case settings   = 3

        var label: String {
            switch self {
            case .home:       return "账本"
            case .roleTab:    return "学习"   // 由 MainTabView 按角色覆盖
            case .statistics: return "统计"
            case .settings:   return "我的"
            }
        }

        var icon: String {
            switch self {
            case .home:       return "house.fill"
            case .roleTab:    return "book.fill"
            case .statistics: return "chart.bar.fill"
            case .settings:   return "person.fill"
            }
        }
    }

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        themeMode = Self.themeMode(for: UserDefaults.standard.string(forKey: Self.themeKey) ?? "system")

        if let raw = UserDefaults.standard.string(forKey: Self.roleKey),
           let role = UserRole(rawValue: raw) {
            selectedRole = role
        }

        aiConfiguration = AIConfiguration(
            isEnabled: UserDefaults.standard.object(forKey: Self.aiEnabledKey) as? Bool ?? true,
            selectedModel: UserDefaults.standard.string(forKey: OpenRouterClient.modelUserDefaultsKey) ?? OpenRouterClient.defaultModel,
            hasAPIKey: !KeychainManager.loadAPIKey().isEmpty
        )
    }

    // MARK: - Sync helpers

    func markLaunchFinished() {
        hasCompletedLaunch = true
    }

    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }

    func syncAuthentication(isLoggedIn: Bool, profile: UserProfile?) {
        self.isLoggedIn = isLoggedIn
        currentUserProfile = profile
        if !isLoggedIn {
            selectedTab = .home
        }
    }

    func syncCurrentBook(_ book: AccountBook?) {
        currentAccountBook = book
        currentBookId = book?.id
    }

    func refreshAIConfiguration() {
        aiConfiguration = AIConfiguration(
            isEnabled: UserDefaults.standard.object(forKey: Self.aiEnabledKey) as? Bool ?? true,
            selectedModel: UserDefaults.standard.string(forKey: OpenRouterClient.modelUserDefaultsKey) ?? OpenRouterClient.defaultModel,
            hasAPIKey: !KeychainManager.loadAPIKey().isEmpty
        )
    }

    func setAIEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.aiEnabledKey)
        aiConfiguration.isEnabled = enabled
    }

    func setAIModel(_ model: String) {
        UserDefaults.standard.set(model, forKey: OpenRouterClient.modelUserDefaultsKey)
        aiConfiguration.selectedModel = model
    }

    func setTheme(rawValue: String) {
        themeMode = Self.themeMode(for: rawValue)
    }

    func selectDefaultTabIfNeeded() {
        if selectedRole != .student && selectedTab == .roleTab {
            selectedTab = .home
        }
    }

    func saveRole(_ role: UserRole) {
        selectedRole = role
        UserDefaults.standard.set(role.rawValue, forKey: Self.roleKey)
        selectDefaultTabIfNeeded()
    }

    private static func themeMode(for rawValue: String) -> ThemeMode {
        switch rawValue {
        case "light": return .light
        case "dark": return .dark
        default: return .system
        }
    }
}

extension Notification.Name {
    static let sonnetRecordChanged = Notification.Name("sonnetRecordChanged")
}
