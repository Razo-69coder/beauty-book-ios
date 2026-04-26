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

    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(theme.backgroundDeep)
                .ignoresSafeArea(edges: .all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Контент с отступом снизу
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
            .padding(.bottom, 90)

            // Floating Pill Tab Bar
            floatingTabBar
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showNewAppointment) {
            NewAppointmentView(onCreated: nil)
                .environment(\.theme, theme)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach([Tab.schedule, Tab.clients], id: \.title) { tab in
                TabIconButton(
                    icon: selectedTab == tab ? tab.icon + ".fill" : tab.icon,
                    isSelected: selectedTab == tab,
                    theme: theme
                ) {
                    HapticManager.light()
                    withAnimation(DS.springSnappy) { selectedTab = tab }
                }
            }

            // FAB
            fabButton
                .frame(maxWidth: .infinity)

            ForEach([Tab.stats, Tab.settings], id: \.title) { tab in
                TabIconButton(
                    icon: selectedTab == tab ? tab.icon + ".fill" : tab.icon,
                    isSelected: selectedTab == tab,
                    theme: theme
                ) {
                    HapticManager.light()
                    withAnimation(DS.springSnappy) { selectedTab = tab }
                }
            }
        }
        .frame(width: screenWidth - 48)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(theme.backgroundCard.opacity(0.85))
            }
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: -4)
    }

    private var borderColor: Color {
        switch theme {
        case .pink: return theme.accent.opacity(0.2)
        case .platinum: return theme.accent.opacity(0.1)
        }
    }

    private var fabButton: some View {
        Button(action: {
            HapticManager.medium()
            showNewAppointment = true
        }) {
            ZStack {
                if theme == .pink {
                    Circle()
                        .stroke(theme.accent.opacity(0.5), lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .modifier(PulseRingModifier())
                }

                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 52, height: 52)
                    .shadow(color: theme.accentGlow, radius: 16, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .offset(y: -6)
    }
}

struct TabIconButton: View {
    let icon: String
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(theme.accent.opacity(0.15))
                }

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? theme.accent : theme.textMuted)
                    .scaleEffect(isPressed ? 1.1 : 1.0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(DS.springSnappy) { isPressed = false } }
        )
    }
}

struct PulseRingModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.5 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

#Preview {
    TabBarView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .environment(\.theme, .pink)
}