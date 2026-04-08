import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        let role = appState.selectedRole ?? .worker
        let isStudent = role == .student

        TabView(selection: $state.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("账本", systemImage: "house.fill") }
                .tag(AppState.Tab.home)

            if isStudent {
                NavigationStack { StudyView() }
                    .tabItem { Label(role.studyTabLabel, systemImage: role.studyTabIcon) }
                    .tag(AppState.Tab.roleTab)
            }

            NavigationStack { StatisticsView() }
                .tabItem { Label("统计", systemImage: "chart.bar.fill") }
                .tag(AppState.Tab.statistics)

            NavigationStack { SettingsView() }
                .tabItem { Label("我的", systemImage: "person.fill") }
                .tag(AppState.Tab.settings)
        }
        .tint(SonnetColors.ink)
        .onAppear {
            appState.selectDefaultTabIfNeeded()
        }
    }
}
