import SwiftUI

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var stats: StatsResponse? = nil
    @Published var earningsByDay: [(String, Int)] = []
    @Published var isLoading = false
    @Published var selectedPeriod: Period = .month
    @Published var expenses: [Expense] = []
    @Published var showAddExpense = false

    enum Period: String, CaseIterable {
        case week = "Неделя"
        case month = "Месяц"
        case year = "Год"
    }

    private let api = APIClient.shared

    var totalExpenses: Int { expenses.reduce(0) { $0 + $1.amount } }
    var netProfit: Int { (stats?.monthEarnings ?? 0) - totalExpenses }

    func load() async {
        isLoading = true
        if let s = try? await api.request(.stats, as: StatsResponse.self) {
            stats = s
        } else {
            stats = MockData.stats
        }
        earningsByDay = MockData.earningsByDay
        expenses = (try? await api.fetchExpenses()) ?? []
        isLoading = false
    }
    
    func addExpense(category: String, amount: Int, description: String, date: String = "") async {
        let req = ExpenseCreateRequest(
            category: category,
            amount: amount,
            description: description,
            date: date.isEmpty ? {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f.string(from: Date())
            }() : date
        )
        _ = try? await api.addExpense(req)
        await load()
    }
    
    func deleteExpense(id: Int) async {
        try? await api.deleteExpense(id: id)
        expenses.removeAll { $0.id == id }
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
                    profitCard(stats: stats)
                    earningsChart
                    expensesSection
                    topProcedures
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $vm.showAddExpense) {
            AddExpenseSheet(vm: vm).environment(\.theme, theme)
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
            .padding(.top, 8)
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

    // MARK: - Profit Card

    private func profitCard(stats: StatsResponse) -> some View {
        BBGlassCard {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Выручка")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                        Text(stats.monthEarnings.formatted + " ₽")
                            .font(DS.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "minus")
                        .foregroundColor(theme.textMuted)
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Расходы")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                        Text(vm.totalExpenses.formatted + " ₽")
                            .font(DS.headline)
                            .foregroundColor(theme.statusRed)
                    }
                    Spacer()
                    Image(systemName: "equal")
                        .foregroundColor(theme.textMuted)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Прибыль")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                        Text(vm.netProfit.formatted + " ₽")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(vm.netProfit >= 0 ? theme.statusGreen : theme.statusRed)
                    }
                }
                .padding(.horizontal, 4)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.backgroundInput).frame(height: 6)
                        let ratio = stats.monthEarnings > 0 ? CGFloat(vm.totalExpenses) / CGFloat(stats.monthEarnings) : 0
                        Capsule()
                            .fill(LinearGradient(colors: [theme.statusRed, Color(hex: "#FF6B6B")], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(ratio, 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Расходы", action: { vm.showAddExpense = true }, actionTitle: "Добавить")

            if vm.expenses.isEmpty {
                BBGlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "tray").font(.system(size: 28)).foregroundColor(theme.accent.opacity(0.4))
                        Text("Нет расходов").font(DS.body).foregroundColor(theme.textMuted)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
            } else {
                ForEach(vm.expenses) { expense in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(theme.backgroundInput).frame(width: 40, height: 40)
                            Image(systemName: ExpenseCategory(rawValue: expense.category)?.icon ?? "ellipsis.circle")
                                .font(.system(size: 16)).foregroundColor(theme.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.description).font(DS.body).foregroundColor(theme.textPrimary)
                            Text(expense.category).font(DS.bodySmall).foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Text("−\(expense.amount.formatted) ₽")
                            .font(DS.label).foregroundColor(theme.statusRed)
                    }
                    .padding(14)
                    .background(theme.backgroundCard)
                    .cornerRadius(DS.r12)
                    .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.borderSubtle, lineWidth: 1))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Удалить") {
                            Task { await vm.deleteExpense(id: expense.id) }
                        }
                        .tint(theme.statusRed)
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

struct AddExpenseSheet: View {
    @ObservedObject var vm: StatsViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var description = ""
    @State private var selectedCategory = ExpenseCategory.materials
    private var isValid: Bool { !amount.isEmpty && !description.isEmpty }

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            VStack(spacing: DS.s12) {
                BBSectionHeader(title: "Категория").padding(.horizontal, 4)
                HStack(spacing: 8) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        VStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 20))
                                .foregroundColor(selectedCategory == cat ? .white : theme.textMuted)
                                .frame(width: 44, height: 44)
                                .background(selectedCategory == cat ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                .cornerRadius(DS.r12)
                            Text(cat.rawValue)
                                .font(DS.caption)
                                .foregroundColor(selectedCategory == cat ? theme.accent : theme.textMuted)
                        }
                        .onTapGesture { selectedCategory = cat }
                        .frame(maxWidth: .infinity)
                    }
                }

                BBTextField(placeholder: "Сумма (₽)", text: $amount, keyboardType: .numberPad)
                    .environment(\.theme, theme)
                BBTextField(placeholder: "Описание (гель-лак, аренда...)", text: $description)
                    .environment(\.theme, theme)

                BBPrimaryButton(title: "Добавить расход", isDisabled: !isValid) {
                    Task {
                        await vm.addExpense(
                            category: selectedCategory.rawValue,
                            amount: Int(amount) ?? 0,
                            description: description
                        )
                        dismiss()
                    }
                }
                .environment(\.theme, theme)
                Spacer()
            }
            .padding(DS.s20)
            .padding(.top, 24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}