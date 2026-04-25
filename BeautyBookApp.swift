import SwiftUI

@main
struct BeautyBookApp: App {
    @StateObject private var appState    = AppState()
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    TabBarView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .environment(\.theme, themeManager.current)
                } else {
                    AuthView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .environment(\.theme, themeManager.current)
                }
            }
            .preferredColorScheme(.dark)
            .animation(DS.springSmooth, value: appState.isAuthenticated)
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = KeychainManager.shared.isAuthenticated
    @Published var currentMaster: MasterProfile? = nil

    init() {
        NotificationCenter.default.addObserver(
            forName: .tokenExpired, object: nil, queue: .main
        ) { [weak self] _ in self?.logout() }
    }

    func login(master: MasterProfile, token: String) {
        KeychainManager.shared.saveToken(token)
        KeychainManager.shared.saveMasterId(master.id)
        currentMaster = master
        withAnimation(DS.springSmooth) { isAuthenticated = true }
    }

    func logout() {
        KeychainManager.shared.deleteToken()
        currentMaster = nil
        withAnimation(DS.springSmooth) { isAuthenticated = false }
    }
}

extension Notification.Name {
    static let tokenExpired = Notification.Name("tokenExpired")
}
