import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Tab = .schedule
    @State private var tabOpacity: Double = 0
    
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
    @State private var showNewAppointment: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
            
            if selectedTab == .schedule || selectedTab == .clients || selectedTab == .services {
                fabButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
            }
        }
    }
    
    private var fabButton: some View {
        Button {
            showNewAppointment = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF2D78"), Color(hex: "#FF006E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: Color(hex: "#FF2D78").opacity(0.5), radius: 12, x: 0, y: 6)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showNewAppointment) {
            NewAppointmentView()
        }
    }
}

#Preview {
    TabBarView()
        .preferredColorScheme(.dark)
}