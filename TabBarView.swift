import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Tab = .schedule
    @State private var tabOpacity: Double = 0
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.current }
    @StateObject private var notifVM = NotificationsViewModel()
    @State private var showNotifications = false
    @Environment(\.scenePhase) private var scenePhase
    // Следим за офлайн-режимом, чтобы показать плашку
    @ObservedObject private var OFFApi = APIClient.shared
    // Реальное состояние сети: показывает плашку даже до первого запроса
    @ObservedObject private var NMMonitor = NMNetworkMonitor.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Сеть вернулась — один раз обновляем данные
    @State private var wasOffline: Bool = false
    
    enum Tab: String, CaseIterable {
        case schedule = "Расписание"
        case clients = "Клиенты"
        case services = "Услуги"
        case stats = "Статистика"
        case settings = "Настройки"
        
        var icon: String {
            switch self {
            case .schedule: return "tab_schedule"
            case .clients:  return "tab_clients"
            case .services: return "tab_services"
            case .stats:    return "tab_stats"
            case .settings: return "tab_settings"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground(theme: theme).ignoresSafeArea()

            TabContent(selectedTab: selectedTab)
                .environmentObject(notifVM)
                .opacity(tabOpacity)

            customTabBar
        }
        // Плашка офлайна — поверх контента, под статус-баром, чтобы её не перекрыли экраны
        .overlay(alignment: .top) {
            if showOfflineBanner {
                GeometryReader { geo in
                    offlineBanner
                        .padding(.top, geo.safeAreaInsets.top + 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                // Плашка ничего не принимает по нажатию — контент под ней остаётся кликабельным
                .allowsHitTesting(false)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : DS.springSmooth, value: showOfflineBanner)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                tabOpacity = 1.0
            }
            // Запоминаем стартовое состояние, чтобы поймать момент возврата сети
            wasOffline = showOfflineBanner
        }
        .task {
            BeautyPushRegistrar.requestPermission()
            await BeautyPushRegistrar.sendSavedTokenIfNeeded()
            await notifVM.refreshUnread()
            // Виджет и Live Activity при появлении — сразу свежие
            await SBWidgetSync.shared.refresh(force: true)
        }
        .overlay(alignment: .topLeading) {
            FeedbackButton()
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet(vm: notifVM)
                .environment(\.theme, theme)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await notifVM.refreshUnread() }
                Task { await SBWidgetSync.shared.refresh() }
            }
        }
        .onChange(of: NMMonitor.isConnected) { _, isConnected in
            if !isConnected {
                wasOffline = true
            } else {
                handleConnectionRestored()
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task { await notifVM.refreshUnread() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNotificationsSheet)) { _ in
            showNotifications = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .stOpenClientsAway)) { _ in
            withAnimation(DS.springSnappy) {
                selectedTab = .clients
            }
        }
    }
    
    /// Плашка нужна, если сети нет по монитору или запросы уже падали с офлайн-ошибкой
    private var showOfflineBanner: Bool {
        !NMMonitor.isConnected || OFFApi.isOffline
    }

    /// Сеть только что вернулась — обновляем данные один раз
    private func handleConnectionRestored() {
        guard wasOffline, NMMonitor.isConnected else { return }
        wasOffline = false
        Task { await notifVM.refreshUnread() }
        Task { await SBWidgetSync.shared.refresh() }
        NotificationCenter.default.post(name: NSNotification.Name("ClientUpdated"), object: nil)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
            Text("Нет интернета — показываю сохранённые данные")
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundColor(theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    theme: theme
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(theme.borderSubtle, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

struct TabButton: View {
    let tab: TabBarView.Tab
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                theme == .platinum
                                ? AnyShapeStyle(Color(hex: "#C9A96E").opacity(0.15))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color(hex: "#FF2D78").opacity(0.25), Color(hex: "#CC00FF").opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                  ))
                            )
                            .frame(width: 44, height: 32)
                    }
                    Image(tab.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(
                            isSelected
                            ? (theme == .platinum
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color(hex: "#C9A96E"), Color(hex: "#E8C99A")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color(hex: "#FF2D78"), Color(hex: "#CC00FF")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)))
                            : AnyShapeStyle(theme.textMuted)
                        )
                        .scaleEffect(isPressed ? 0.85 : (isSelected ? 1.05 : 1.0))
                        .shadow(
                            color: isSelected ? theme.accentGlow : .clear,
                            radius: 6, x: 0, y: 2
                        )
                }
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? theme.accent : theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3)) { isPressed = false } }
        )
        .animation(DS.springSnappy, value: isSelected)
    }
}

struct TabContent: View {
    let selectedTab: TabBarView.Tab
    
    var body: some View {
        Group {
            switch selectedTab {
            case .schedule:
                ScheduleView()
            case .clients:
                ClientsListView()
            case .services:
                ServicesView()
            case .stats:
                StatsView()
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    TabBarView()
        .preferredColorScheme(.dark)
}