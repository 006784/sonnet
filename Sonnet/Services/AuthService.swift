import AuthenticationServices
import Foundation

// MARK: - 认证错误

enum AuthError: Error, LocalizedError {
    case credentialRevoked
    case keychainFailed(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .credentialRevoked:      return "Apple ID 授权已被撤销，请重新登录"
        case .keychainFailed(let e):  return "存储失败：\(e.localizedDescription)"
        case .unknown(let e):         return e.localizedDescription
        }
    }
}

// MARK: - AuthService

@Observable
final class AuthService: NSObject {

    // MARK: 状态属性（Views 使用）
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var currentUser: UserProfile?          // 主属性（替代旧 currentProfile）
    var errorMessage: String?

    /// 向后兼容 alias
    var currentProfile: UserProfile? { currentUser }

    // MARK: - 初始化

    override init() {
        super.init()
        checkAuthState()
    }

    // MARK: - 公开方法

    /// App 启动时检查登录状态（同步，从 Keychain 恢复）
    func checkAuthState() {
        do {
            let profile = try KeychainManager.loadUserProfile()
            // Apple 登录需额外验证授权状态是否仍有效
            if profile.loginMethod == .apple {
                verifyAppleCredential(userId: profile.userId, profile: profile)
            } else {
                setAuthenticated(profile: profile)
            }
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
    }

    /// Sign in with Apple（同步接口，Views/AuthViewModel 直接调用）
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) {
        isLoading = true
        errorMessage = nil

        // 组装显示名：优先 fullName，否则用 email 前缀，否则 "用户"
        let givenName  = credential.fullName?.givenName  ?? ""
        let familyName = credential.fullName?.familyName ?? ""
        var displayName = (familyName + givenName).trimmingCharacters(in: .whitespaces)
        if displayName.isEmpty {
            displayName = credential.email.flatMap { $0.components(separatedBy: "@").first } ?? "用户"
        }

        let profile = UserProfile(
            userId:      credential.user,
            displayName: displayName,
            email:       credential.email,
            avatarData:  nil,
            loginMethod: .apple,
            createdAt:   Date()
        )
        persistAndAuthenticate(profile: profile)
    }

    /// 游客模式（同步）
    func continueAsGuest() {
        let profile = UserProfile(
            userId:      UUID().uuidString,
            displayName: "游客",
            email:       nil,
            avatarData:  nil,
            loginMethod: .guest,
            createdAt:   Date()
        )
        persistAndAuthenticate(profile: profile)
    }

    /// 退出登录
    func signOut() {
        KeychainManager.deleteUserProfile()
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
    }

    /// 删除账号（仅 Apple 登录可用）
    func deleteAccount() async throws {
        guard currentUser?.loginMethod == .apple else { return }
        // 撤销 Apple 授权（需要 Apple 提供 authorizationCode 做服务端撤销，此处清理本地数据）
        KeychainManager.deleteUserProfile()
        KeychainManager.deleteAPIKey()
        await MainActor.run {
            currentUser = nil
            isAuthenticated = false
        }
    }

    /// 游客升级为 Apple 登录（保留数据）
    func upgradeGuestToApple(credential: ASAuthorizationAppleIDCredential) {
        guard let guest = currentUser, guest.loginMethod == .guest else { return }
        let givenName  = credential.fullName?.givenName  ?? ""
        let familyName = credential.fullName?.familyName ?? ""
        var displayName = (familyName + givenName).trimmingCharacters(in: .whitespaces)
        if displayName.isEmpty { displayName = "用户" }

        let profile = UserProfile(
            userId:      credential.user,
            displayName: displayName,
            email:       credential.email,
            avatarData:  guest.avatarData,
            loginMethod: .apple,
            createdAt:   guest.createdAt       // 保留原始创建时间
        )
        persistAndAuthenticate(profile: profile)
    }

    // MARK: - 内部实现

    private func persistAndAuthenticate(profile: UserProfile) {
        do {
            try KeychainManager.saveUserProfile(profile)
            setAuthenticated(profile: profile)
        } catch {
            errorMessage = AuthError.keychainFailed(error).localizedDescription
        }
        isLoading = false
    }

    private func setAuthenticated(profile: UserProfile) {
        currentUser = profile
        isAuthenticated = true
    }

    /// 异步验证 Apple 凭证是否仍有效
    private func verifyAppleCredential(userId: String, profile: UserProfile) {
        Task { @MainActor in
            let provider = ASAuthorizationAppleIDProvider()
            let state = try? await provider.credentialState(forUserID: userId)
            if state == .revoked || state == .notFound {
                // 凭证已失效，清除登录状态（不强制退出，提示重新登录）
                self.errorMessage = "Apple ID 状态异常，建议重新登录以确保数据安全。"
                // 仍然允许进入 App 使用本地数据
                self.setAuthenticated(profile: profile)
            } else {
                self.setAuthenticated(profile: profile)
            }
        }
    }
}
