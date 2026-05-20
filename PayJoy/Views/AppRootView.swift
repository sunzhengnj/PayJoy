import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                AppTheme.paper.ignoresSafeArea()

                Group {
                    switch appState.selectedTab {
                    case .home:
                        NavigationStack { HomeView() }
                    case .stats:
                        NavigationStack { StatsView() }
                    case .profile:
                        NavigationStack { ProfileView() }
                    }
                }
                .padding(.bottom, appState.isTabBarHidden ? 0 : 92)

                if !appState.isTabBarHidden {
                    ComicTabBar(selectedTab: $appState.selectedTab)
                        .padding(.bottom, max(-22, -proxy.safeAreaInsets.bottom + 8))
                        .ignoresSafeArea(.container, edges: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: appState.isTabBarHidden)
        }
        .task {
            while !Task.isCancelled {
                appState.updateClock()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
