import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthService.self) private var authService

    var body: some View {
        ZStack {
            if !appState.hasCompletedLaunch {
                SplashView(showMainApp: Binding(
                    get: { appState.hasCompletedLaunch },
                    set: { if $0 { appState.markLaunchFinished() } }
                ))
                    .transition(.opacity)
            } else if !appState.hasCompletedOnboarding {
                OnboardingView {
                    withAnimation(SonnetMotion.easeInOut) {
                        appState.markOnboardingCompleted()
                    }
                }
                .transition(SonnetMotion.pageTransition)
            } else if !authService.isAuthenticated {
                LoginView(authService: authService)
                    .transition(SonnetMotion.pageTransition)
            } else if !appState.hasSelectedRole {
                RoleSelectionView {
                }
                .transition(SonnetMotion.pageTransition)
            } else {
                MainTabView()
                    .transition(SonnetMotion.pageTransition)
            }
        }
        .onAppear {
            appState.syncAuthentication(
                isLoggedIn: authService.isAuthenticated,
                profile: authService.currentUser
            )
            appState.refreshAIConfiguration()
            appState.selectDefaultTabIfNeeded()
        }
        .animation(SonnetMotion.easeInOut, value: appState.hasCompletedLaunch)
        .animation(SonnetMotion.easeInOut, value: appState.hasCompletedOnboarding)
        .animation(SonnetMotion.easeInOut, value: authService.isAuthenticated)
        .animation(SonnetMotion.easeInOut, value: appState.hasSelectedRole)
    }
}
