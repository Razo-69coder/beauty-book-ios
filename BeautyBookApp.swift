import SwiftUI

@main
struct BeautyBookApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.isAuthenticated {
                    TabBarView()
                        .transition(.opacity)
                } else {
                    AuthView()
                        .transition(.opacity)
                }
            }
            .environmentObject(appState)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.isAuthenticated)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = KeychainManager.shared.isAuthenticated
    
    init() {
        NotificationCenter.default.addObserver(
            forName: .tokenExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logout()
        }
    }
    
    func logout() {
        KeychainManager.shared.deleteToken()
        withAnimation {
            isAuthenticated = false
        }
    }
}