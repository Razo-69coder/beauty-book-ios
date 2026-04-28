import SwiftUI

@main
struct BeautyBookApp: App {
    @StateObject private var appState     = AppState()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showSplash         = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView(theme: themeManager.current)
                        .transition(.opacity)
                } else if appState.isAuthenticated {
                    TabBarView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .environment(\.theme, themeManager.current)
                        .preferredColorScheme(.dark)
                        .transition(.opacity)
                } else {
                    AuthView()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .environment(\.theme, themeManager.current)
                        .preferredColorScheme(.dark)
                        .transition(.opacity)
                }
            }
            .animation(DS.springSmooth, value: showSplash)
            .task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                showSplash = false
            }
        }
    }
}

struct SplashView: View {
    let theme: AppTheme
    @State private var scale: CGFloat  = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                        .shadow(color: theme.accentGlow, radius: 30, x: 0, y: 10)
                    Group {
                        if let path = Bundle.main.path(forResource: "solva_logo", ofType: "png"),
                           let uiImg = UIImage(contentsOfFile: path) {
                            Image(uiImage: uiImg)
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
                .scaleEffect(scale)

                VStack(spacing: 6) {
                    Text("Solva Beauty")
                        .font(DS.titleLarge)
                        .foregroundColor(theme.textPrimary)
                    Text("CRM для бьюти-мастера")
                        .font(DS.body)
                        .foregroundColor(theme.textSecondary)
                }
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                opacity = 1.0
            }
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
