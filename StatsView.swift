import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var statsOpacity: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                summaryCards
                
                topProceduresSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(hex: "#080810"))
        .onAppear {
            Task { await viewModel.loadStats() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                statsOpacity = 1.0
            }
        }
        .opacity(statsOpacity)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Статистика")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("За всё время")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#A0A0C0"))
            }
            Spacer()
            
            Button {
                Task { await viewModel.loadStats() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#FF2D78"))
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
            }
        }
    }
    
    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            SummaryCard(
                title: "Клиентов",
                value: "\(viewModel.totalClients)",
                icon: "person.2.fill",
                color: Color(hex: "#FF2D78")
            )
            
            SummaryCard(
                title: "Записей",
                value: "\(viewModel.totalAppointments)",
                icon: "calendar.badge.checkmark",
                color: Color(hex: "#4ECDC4")
            )
            
            SummaryCard(
                title: "Выручка",
                value: "\(viewModel.totalEarnings.formatted())₽",
                icon: "banknote.fill",
                color: Color(hex: "#00E5A0")
            )
            
            SummaryCard(
                title: "За месяц",
                value: "\(viewModel.monthEarnings.formatted())₽",
                icon: "chart.line.uptrend.xyaxis",
                color: Color(hex: "#FFD166")
            )
        }
    }
    
    private var topProceduresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Топ услуг")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#5A5A7A"))
                .textCase(.uppercase)
            
            if viewModel.topProcedures.isEmpty {
                Text("Пока нет данных")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#5A5A7A"))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(viewModel.topProcedures) { procedure in
                    ProcedureRow(procedure: procedure, maxCount: viewModel.maxProcedureCount)
                }
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#5A5A7A"))
            }
        }
        .padding(16)
        .background(Color(hex: "#11111E"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ProcedureRow: View {
    let procedure: TopProcedure
    let maxCount: Int
    
    private var progressWidth: CGFloat {
        guard maxCount > 0 else { return 0 }
        return CGFloat(procedure.count) / CGFloat(maxCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(procedure.procedure)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(procedure.count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#FF2D78"))
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#1A1A2E"))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF2D78"), Color(hex: "#FF006E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressWidth, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(hex: "#11111E"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var totalClients: Int = 0
    @Published var totalAppointments: Int = 0
    @Published var totalEarnings: Int = 0
    @Published var monthEarnings: Int = 0
    @Published var topProcedures: [TopProcedure] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let api = APIClient.shared
    
    var maxProcedureCount: Int {
        topProcedures.map(\.count).max() ?? 0
    }
    
    func loadStats() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await api.getStats()
            totalClients = response.totalClients
            totalAppointments = response.totalAppointments
            totalEarnings = response.totalEarnings
            monthEarnings = response.monthEarnings
            topProcedures = response.topProcedures
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    StatsView()
        .preferredColorScheme(.dark)
}