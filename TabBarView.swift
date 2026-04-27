import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Tab = .schedule
    @State private var tabOpacity: Double = 0
    @ObservedObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.current }
    
    enum Tab: String, CaseIterable {
        case schedule = "Расписание"
        case clients = "Клиенты"
        case services = "Услуги"
        case stats = "Статистика"
        case settings = "Настройки"
        
        var icon: String {
            switch self {
            case .schedule: return "calendar"
            case .clients: return "person.2"
            case .services: return "scissors"
            case .stats: return "chart.bar"
            case .settings: return "gearshape"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            theme.backgroundDeep.ignoresSafeArea()
            
            TabContent(selectedTab: selectedTab)
                .opacity(tabOpacity)
            
            customTabBar
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                tabOpacity = 1.0
            }
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
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.accent : theme.textMuted)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.accent : theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3)) { isPressed = false } }
        )
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
                SettingsView()
            }
        }
    }
}

#Preview {
    TabBarView()
        .preferredColorScheme(.dark)
}