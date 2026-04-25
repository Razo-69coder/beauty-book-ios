import SwiftUI

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var stats: StatsResponse?     = nil
    @Published var earningsByDay: [(String, Int)] = []
    @Published var isLoading                 = false
    @Published var selectedPeriod: Period    = .month

    enum Period: String, CaseIterable {
        case week  = "Неделя"
        case month = "Месяц"
        case year  = "Год"
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
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
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
            VStack(spacing: DS.s20) {
                header

                if let stats = vm.stats {
                    // Главные цифры
                    mainMetrics(stats: stats)
                    // График
                    earningsChart
                    // Топ услуг
                    topProcedures(stats: stats)
                }
            }
            .padding(.horizontal, DS.s20)
            .padding(.bottom, 100)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Статистика").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text("Общая картина").font(DS.body).foregroundColor(theme.textSecondary)
            }
            Spacer()
            // Period Picker
            HStack(spacing: 0) {
                ForEach(StatsViewModel.Period.allCases, id: \.self) { p in
                    Text(p.rawValue)
                        .font(DS.labelSmall)
                        .foregroundColor(vm.selectedPeriod == p ? .white : theme.textMuted)
                        .padding(.horizontal, DS.s12)
                        .padding(.vertical, DS.s8)
                        .background(vm.selectedPeriod == p ? theme.accent : Color.clear)
                        .cornerRadius(DS.r8)
                        .onTapGesture { withAnimation(DS.springSnappy) { vm.selectedPeriod = p } }
                }
            }
            .background(theme.backgroundInput).cornerRadius(DS.r8)
        }
        .padding(.top, DS.s16)
    }

    private func mainMetrics(stats: StatsResponse) -> some View {
        VStack(spacing: DS.s12) {
            // Главная карточка — месячная выручка
            ZStack {
                RoundedRectangle(cornerRadius: DS.r16)
                    .fill(theme.gradientPrimary)
                    .shadow(color: theme.accentGlow, radius: 20, x: 0, y: 8)
                VStack(spacing: DS.s8) {
                    Text("Выручка за месяц")
                        .font(DS.body).foregroundColor(.white.opacity(0.8))
                    Text("\(stats.monthEarnings.formatted)₽")
                        .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text("Всего: \(stats.totalEarnings.formatted)₽")
                        .font(DS.bodySmall).foregroundColor(.white.opacity(0.7))
                }
                .padding(DS.s24)
            }

            // Мелкие метрики
            HStack(spacing: DS.s12) {
                MetricCard(
                    icon: "person.2.fill", label: "Клиентов",
                    value: "\(stats.totalClients)", theme: theme
                )
                MetricCard(
                    icon: "calendar.badge.checkmark", label: "Записей",
                    value: "\(stats.totalAppointments)", theme: theme
                )
            }
        }
    }

    private var earningsChart: some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: "Выручка за 14 дней").environment(\.theme, theme)
            BBCard {
                BarChart(data: vm.earningsByDay, theme: theme)
                    .frame(height: 140)
            }.environment(\.theme, theme)
        }
    }

    private func topProcedures(stats: StatsResponse) -> some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: "Топ услуг").environment(\.theme, theme)
            VStack(spacing: DS.s8) {
                ForEach(Array(stats.topProcedures.prefix(5).enumerated()), id: \.offset) { index, proc in
                    HStack(spacing: DS.s12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(index == 0 ? theme.accent : theme.textMuted)
                            .frame(width: 20)
                        Text(proc.procedure).font(DS.body).foregroundColor(theme.textPrimary)
                        Spacer()
                        Text("\(proc.count) раз")
                            .font(DS.labelSmall).foregroundColor(theme.textSecondary)
                    }
                    .padding(.horizontal, DS.s12)
                    .padding(.vertical, DS.s8)
                    .background(theme.backgroundCard)
                    .cornerRadius(DS.r8)
                }
            }
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let icon: String; let label: String; let value: String; let theme: AppTheme
    var body: some View {
        VStack(spacing: DS.s8) {
            Image(systemName: icon).font(.system(size: 22)).foregroundColor(theme.accent)
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(theme.textPrimary)
            Text(label).font(DS.caption).foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.s16)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r16)
        .overlay(RoundedRectangle(cornerRadius: DS.r16).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

// MARK: - Bar Chart

struct BarChart: View {
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
                            .fill(item.1 > 0
                                  ? AnyShapeStyle(theme.gradientPrimary)
                                  : AnyShapeStyle(theme.backgroundInput))
                            .frame(height: max(4, geo.size.height * 0.8 * ratio))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(idx) * 0.03), value: ratio)
                        if idx % 3 == 0 {
                            Text(item.0)
                                .font(.system(size: 8))
                                .foregroundColor(theme.textMuted)
                                .lineLimit(1)
                        } else {
                            Text("").font(.system(size: 8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

extension Int {
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

#Preview {
    StatsView().environment(\.theme, .pink)
}
