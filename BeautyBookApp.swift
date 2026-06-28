import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[APNs] Device token: \(token)")
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        Task { await BeautyPushRegistrar.send(token: token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Failed to register: \(error)")
    }

    // Показывать уведомления даже когда приложение открыто
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

struct BeautyPushRegistrar {
    static func requestPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    static func sendSavedTokenIfNeeded() async {
        // Принудительно перерегистрируем токен при каждом запуске
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        guard let token = UserDefaults.standard.string(forKey: "apns_device_token") else { return }
        await send(token: token)
    }

    static func send(token: String) async {
        guard let apiToken = KeychainManager.shared.getToken() else {
            print("[APNs] No JWT token in keychain, skipping device token registration")
            return
        }
        let baseURL = "https://beauty-bot-44ou.onrender.com/api/v1"
        guard let url = URL(string: baseURL + "/device/token") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "token=\(token)".data(using: .utf8)
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[APNs] Device token registration status: \(status)")
        } catch {
            print("[APNs] Device token registration error: \(error)")
        }
    }
}

@main
struct BeautyBookApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                        .preferredColorScheme(themeManager.current == .platinum ? .light : .dark)
                        .transition(.opacity)
                        .fullScreenCover(
                            isPresented: Binding<Bool>(
                                get: { appState.isAuthenticated && !onboardingCompleted },
                                set: { _ in }
                            )
                        ) {
                            OnboardingView(onFinish: {
                                onboardingCompleted = true
                            }, isPreview: false)
                            .environmentObject(themeManager)
                            .environment(\.theme, themeManager.current)
                            .interactiveDismissDisabled()
                        }
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
                BeautyPushRegistrar.requestPermission()
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

@MainActor final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = KeychainManager.shared.isAuthenticated
    @Published var currentMaster: MasterProfile? = nil

    init() {
        NotificationCenter.default.addObserver(
            forName: .tokenExpired, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.logout() } }
    }

    func login(master: MasterProfile, token: String) {
        KeychainManager.shared.saveToken(token)
        KeychainManager.shared.saveMasterId(master.id)
        currentMaster = master
        withAnimation(DS.springSmooth) { isAuthenticated = true }
        Task { await mergeDuplicates() }
    }

    private func mergeDuplicates() async {
        do {
            let _: MergeDuplicatesResponse = try await APIClient.shared.request(.mergeDuplicates)
            print("[MERGE] Duplicate clients merged successfully")
        } catch {
            print("[MERGE] Failed to merge duplicates: \(error)")
        }
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
