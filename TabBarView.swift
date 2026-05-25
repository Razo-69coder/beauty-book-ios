import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Tab = .schedule
    @State private var tabOpacity: Double = 0
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.current }
    @StateObject private var notifVM = NotificationsViewModel()
    @State private var showNotifications = false
    @Environment(\.scenePhase) private var scenePhase
    
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
                .opacity(tabOpacity)

            customTabBar
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                tabOpacity = 1.0
            }
        }
        .task {
            BeautyPushRegistrar.requestPermission()
            await BeautyPushRegistrar.sendSavedTokenIfNeeded()
            await notifVM.refreshUnread()
        }
        .overlay(alignment: .topLeading) {
            FeedbackButton()
                .environment(\.theme, theme)
        }
        .overlay(alignment: .topTrailing) {
            NotificationBellButton(vm: notifVM, isPresented: $showNotifications)
                .environment(\.theme, theme)
                .padding(.top, 56)
                .padding(.trailing, 20)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet(vm: notifVM)
                .environment(\.theme, theme)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await notifVM.refreshUnread() }
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task { await notifVM.refreshUnread() }
        }
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