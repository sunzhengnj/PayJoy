import SwiftUI

@main
struct PayJoyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
    }
}
