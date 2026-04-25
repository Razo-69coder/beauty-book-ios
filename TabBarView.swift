import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Tab = .schedule
    @State private var tabOpacity: Double = 0
    
    enum Tab: String, CaseIterable {
        case schedule = "Расписание"
        case clients = "Клиенты"
        case add = "Запись"
        case stats = "Статистика"
        case settings = "Настройки"
        
        var icon: String {
            switch self {
            case .schedule: return "calendar"
            case .clients: return "person.2"
            case .add: return "plus.circle.fill"
            case .stats: return "chart.bar"
            case .settings: return "gearshape"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#080810").ignoresSafeArea()
            
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
                    isSelected: selectedTab == tab
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
                .fill(Color(hex: "#11111E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

struct TabButton: View {
    let tab: TabBarView.Tab
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "#FF2D78") : Color(hex: "#5A5A7A"))
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "#FF2D78") : Color(hex: "#5A5A7A"))
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
                ClientsListPlaceholder()
            case .add:
                NewAppointmentPlaceholder()
            case .stats:
                StatsPlaceholder()
            case .settings:
                SettingsPlaceholder()
            }
        }
    }
}

struct ClientsListPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#5A5A7A"))
            Text("Клиенты")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Скоро")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#5A5A7A"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NewAppointmentPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#FF2D78"))
            Text("Новая запись")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Скоро")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#5A5A7A"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatsPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#4ECDC4"))
            Text("Статистика")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Скоро")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#5A5A7A"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#A0A0C0"))
            Text("Настройки")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Скоро")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#5A5A7A"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TabBarView()
        .preferredColorScheme(.dark)
}