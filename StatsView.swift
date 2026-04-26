import SwiftUI

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var stats: StatsResponse? = nil
    @Published var earningsByDay: [(String, Int)] = []
    @Published var isLoading = false
    @Published var selectedPeriod: Period = .month

    enum Period: String, CaseIterable {
        case week = "Неделя"
        case month = "Месяц"
        case year = "Год"
    }

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        if let s = try? await api.request(.stats, as: StatsResponse.self) {
            stats = s
        } else {
            stats = MockData.stats
        }
        earningsByDay = MockData.earningsByDay
        isLoading = false
    }
}

struct StatsView: View {
    @StateObject private var vm = StatsViewModel()
    @Environment(\.theme) private var theme

    var body: some View {
        Color.clear
            .overlay {
                if vm.isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                } else {
                    content
                }
            }
            .task { await vm.load() }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection

                if let stats = vm.stats {
                    kpiGrid(stats: stats)
                    earningsChart
                    topProcedures
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            ambientGlow
            VStack(alignment: .leading, spacing: 4) {
                Text("Аналитика")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text("За последние 30 дней")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var ambientGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [glowColor, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 80
                )
            )
            .frame(width: 300, height: 200)
            .offset(x: -60, y: -40)
            .blur(radius: 80)
    }

    private var glowColor: Color {
        switch theme {
        case .pink: return theme.accent.opacity(0.15)
        case .platinum: return Color(hex: "#C9A84C").opacity(0.08)
        }
    }

    // MARK: - KPI Grid

    private func kpiGrid(stats: StatsResponse) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            KPICard(
                icon: "rublesign.circle",
                value: stats.monthEarnings.formatted,
                label: "Выручка",
                theme: theme
            )
            KPICard(
                icon: "calendar.circle",
                value: "\(stats.totalAppointments)",
                label: "Записей",
                theme: theme
            )
            KPICard(
                icon: "person.2.circle",
                value: "\(stats.totalClients)",
                label: "Клиентов",
                theme: theme
            )
            KPICard(
                icon: "chart.line.uptrend.xyaxis.circle",
                value: avgCheck.formatted,
                label: "Ср. чек",
                theme: theme
            )
        }
    }

    private var avgCheck: Int {
        guard let stats = vm.stats, stats.totalAppointments > 0 else { return 0 }
        return stats.monthEarnings / stats.totalAppointments
    }

    // MARK: - Earnings Chart

    private var earningsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Выручка по дням")

            BBGlassCard {
                BarChartView(data: vm.earningsByDay, theme: theme)
                    .frame(height: 140)
            }
        }
    }

    // MARK: - Top Procedures

    private var topProcedures: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Популярные услуги")

            if let stats = vm.stats {
                ForEach(Array(stats.topProcedures.prefix(5).enumerated()), id: \.offset) { index, proc in
                    TopProcedureRow(
                        index: index,
                        name: proc.procedure,
                        count: proc.count,
                        maxCount: stats.topProcedures.first?.count ?? 1,
                        theme: theme
                    )
                }
            }
        }
    }
}

// MARK: - KPI Card

struct KPICard: View {
    let icon: String
    let value: String
    let label: String
    let theme: AppTheme

    var body: some View {
        BBGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(theme.accent)
                    Spacer()
                }

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Text(label)
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textMuted)
            }
            .padding(16)
        }
    }
}

// MARK: - Top Procedure Row

struct TopProcedureRow: View {
    let index: Int
    let name: String
    let count: Int
    let maxCount: Int
    let theme: AppTheme

    private var ratio: CGFloat {
        maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0
    }

    var body: some View {
        HStack {
            Text("#\(index + 1)")
                .font(DS.labelSmall)
                .foregroundColor(theme.textMuted)
                .frame(width: 24)

            Text(name)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.backgroundInput)
                        .frame(height: 4)
                    Capsule()
                        .fill(theme.gradientPrimary)
                        .frame(width: geo.size.width * ratio, height: 4)
                }
            }
            .frame(width: 80, height: 4)

            Text("\(count)")
                .font(DS.labelSmall)
                .foregroundColor(theme.accent)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(14)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r12)
    }
}

// MARK: - Bar Chart View

struct BarChartView: View {
    let data: [(String, Int)]
    let theme: AppTheme

    private var maxValue: Int { data.map { $0.1 }.max() ?? 1 }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.enumerated()), id: \.offset) { idx, item in
                    VStack(spacing: 4) {
                        let ratio = maxValue > 0 ? CGFloat(item.1) / CGFloat(maxValue) : 0
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.1 > 0 ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                            .frame(height: max(4, geo.size.height * 0.8 * ratio))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(idx) * 0.03), value: ratio)
                        if idx % 3 == 0 {
                            Text(item.0)
                                .font(DS.caption)
                                .foregroundColor(theme.textMuted)
                                .lineLimit(1)
                        } else {
                            Text("").font(DS.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Int Extension

extension Int {
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

#Preview {
    StatsView()
        .environment(\.theme, .pink)
}