import SwiftUI

@main
struct BeautyBookApp: App {
    @StateObject private var appState         = AppState()
    @StateObject private var themeManager    = ThemeManager.shared
    @State private var showSplash           = true
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

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
                        .fullScreenCover(
                            isPresented: Binding<Bool>(
                                get: { appState.isAuthenticated && !onboardingCompleted },
                                set: { _ in }
                            )
                        ) {
                            OnboardingView(isPreview: false, onFinish: {
                                onboardingCompleted = true
                            })
                            .environmentObject(themeManager)
                            .environment(\.theme, themeManager.current)
                            .interactiveDismissDisabled()
                        }
//                        .fullScreenCover(isPresented: $appState.subscriptionRequired) {
//                            SubscriptionView()
//                                .environmentObject(themeManager)
//                                .environment(\.theme, themeManager.current)
//                                .interactiveDismissDisabled()
//                        }
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
    @State private var scale: CGFloat    = 0.5
    @State private var opacity: Double   = 0
    @State private var glowRadius: CGFloat = 10
    @State private var textOffset: CGFloat = 20

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(theme.accentGlow)
                        .frame(width: 130, height: 130)
                        .blur(radius: glowRadius)

                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                        .shadow(color: theme.accentGlow, radius: 24, x: 0, y: 8)

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
                .offset(y: textOffset)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                opacity = 1.0
                textOffset = 0
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                glowRadius = 30
            }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = KeychainManager.shared.isAuthenticated
    @Published var currentMaster: MasterProfile? = nil
    @Published var subscriptionRequired: Bool = false

    init() {
        NotificationCenter.default.addObserver(
            forName: .tokenExpired, object: nil, queue: .main
        ) { [weak self] _ in self?.logout() }
        NotificationCenter.default.addObserver(
            forName: .subscriptionRequired, object: nil, queue: .main
        ) { [weak self] _ in self?.requireSubscription() }
        NotificationCenter.default.addObserver(
            forName: .subscriptionActivated, object: nil, queue: .main
        ) { [weak self] _ in self?.activateSubscription() }
    }

    func login(master: MasterProfile, token: String) {
        KeychainManager.shared.saveToken(token)
        KeychainManager.shared.saveMasterId(master.id)
        currentMaster = master
        subscriptionRequired = false
        withAnimation(DS.springSmooth) { isAuthenticated = true }
    }

    func logout() {
        KeychainManager.shared.deleteToken()
        currentMaster = nil
        withAnimation(DS.springSmooth) { isAuthenticated = false }
    }

    func requireSubscription() {
        // BETA: disabled
        // withAnimation(DS.springSmooth) { subscriptionRequired = true }
    }

    func activateSubscription() {
        withAnimation(DS.springSmooth) { subscriptionRequired = false }
    }
}

extension Notification.Name {
    static let tokenExpired = Notification.Name("tokenExpired")
    static let subscriptionRequired = Notification.Name("subscriptionRequired")
    static let subscriptionActivated = Notification.Name("subscriptionActivated")
}
