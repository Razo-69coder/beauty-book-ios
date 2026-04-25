import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Tab = .schedule
    @State private var showNewAppointment = false
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    enum Tab: CaseIterable {
        case schedule, clients, stats, settings

        var title: String {
            switch self {
            case .schedule:  return "Расписание"
            case .clients:   return "Клиенты"
            case .stats:     return "Статистика"
            case .settings:  return "Настройки"
            }
        }
        var icon: String {
            switch self {
            case .schedule:  return "calendar"
            case .clients:   return "person.2"
            case .stats:     return "chart.bar"
            case .settings:  return "gearshape"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.backgroundDeep.ignoresSafeArea()

            // Контент
            Group {
                switch selectedTab {
                case .schedule: ScheduleView()
                case .clients:  ClientsListView()
                case .stats:    StatsView()
                case .settings: SettingsView()
                }
            }
            .environment(\.theme, theme)
            .environmentObject(appState)
            .environmentObject(themeManager)

            // Tab Bar
            VStack(spacing: 0) {
                Divider().background(theme.borderSubtle)
                HStack(spacing: 0) {
                    // Первые 2 вкладки
                    ForEach([Tab.schedule, Tab.clients], id: \.title) { tab in
                        TabButton(tab: tab, isSelected: selectedTab == tab, theme: theme) {
                            withAnimation(DS.springSnappy) { selectedTab = tab }
                        }
                    }

                    // Центральная кнопка + (Новая запись)
                    Button(action: { showNewAppointment = true }) {
                        ZStack {
                            Circle()
                                .fill(theme.gradientPrimary)
                                .frame(width: 56, height: 56)
                                .shadow(color: theme.accentGlow, radius: 12, x: 0, y: 4)
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(y: -12)
                    .frame(maxWidth: .infinity)

                    // Последние 2 вкладки
                    ForEach([Tab.stats, Tab.settings], id: \.title) { tab in
                        TabButton(tab: tab, isSelected: selectedTab == tab, theme: theme) {
                            withAnimation(DS.springSnappy) { selectedTab = tab }
                        }
                    }
                }
                .padding(.horizontal, DS.s8)
                .padding(.top, DS.s8)
                .padding(.bottom, DS.s20)
                .background(
                    theme.backgroundCard
                        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: -4)
                )
            }
        }
        .sheet(isPresented: $showNewAppointment) {
            NewAppointmentView(onCreated: nil)
                .environment(\.theme, theme)
        }
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
                Image(systemName: isSelected ? tab.icon + ".fill" : tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.accent : theme.textMuted)
                    .scaleEffect(isPressed ? 0.88 : 1.0)
                Text(tab.title)
                    .font(DS.caption)
                    .foregroundColor(isSelected ? theme.accent : theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.s4)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(DS.springSnappy) { isPressed = false } }
        )
    }
}

#Preview {
    TabBarView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .environment(\.theme, .pink)
}
