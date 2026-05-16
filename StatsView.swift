import SwiftUI

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var stats: StatsResponse? = nil
    @Published var earningsByDay: [(String, Int)] = []
    @Published var isLoading = false
    @Published var selectedPeriod: Period = .month
    @Published var expenses: [Expense] = []
    @Published var showAddExpense = false
    @Published var expenseError: String? = nil
    @Published var isAddingExpense = false
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var selectedMonth: Int? = nil
    @Published var yearlyStats: YearlyStatsResponse? = nil

    enum Period: String, CaseIterable {
        case week, month, year

        var displayName: String {
            switch self {
            case .week:  return "Неделя"
            case .month: return "Месяц"
            case .year:  return "Год"
            }
        }
    }

    var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 3)...current)
    }

    private let api = APIClient.shared
    @Published private var rawEarnings: [EarningsDay] = []

    var totalExpenses: Int { expenses.reduce(0) { $0 + $1.amount } }

    var currentRevenue: Int {
        if selectedPeriod == .year && selectedMonth != nil {
            return rawEarnings.reduce(0) { $0 + $1.total }
        }
        switch selectedPeriod {
        case .week:  return rawEarnings.reduce(0) { $0 + $1.total }
        case .month: return stats?.monthEarnings ?? 0
        case .year:  return yearlyStats?.totalRevenue ?? 0
        }
    }

    var currentAppointments: Int {
        if selectedPeriod == .year && selectedMonth != nil {
            return rawEarnings.reduce(0) { $0 + $1.count }
        }
        switch selectedPeriod {
        case .week:  return rawEarnings.reduce(0) { $0 + $1.count }
        case .month: return rawEarnings.reduce(0) { $0 + $1.count }
        case .year:  return yearlyStats?.totalAppointments ?? 0
        }
    }

    var currentClients: Int {
        stats?.totalClients ?? 0
    }

    var avgCheck: Int {
        let apps = currentAppointments
        guard apps > 0 else { return 0 }
        return currentRevenue / apps
    }

    func load() async {
        isLoading = true
        async let statsLoad = api.request(.stats, as: StatsResponse.self)
        async let expensesLoad = api.fetchExpenses()
        stats = (try? await statsLoad) ?? StatsResponse(totalClients: 0, totalAppointments: 0, totalEarnings: 0, monthEarnings: 0, topProcedures: [])
        expenses = (try? await expensesLoad) ?? []

        if selectedPeriod == .year && selectedMonth != nil {
            await loadMonthInYear()
        } else {
            let daysCount: Int
            switch selectedPeriod {
            case .week:  daysCount = 7
            case .month: daysCount = 30
            case .year:  daysCount = 365
            }
            rawEarnings = (try? await api.earningsByDay(days: daysCount)) ?? []
            earningsByDay = groupEarnings(rawEarnings, period: selectedPeriod)
            if selectedPeriod == .year {
                await loadYearlyStats()
            }
        }
        isLoading = false
    }

    private func loadMonthInYear() async {
        guard let month = selectedMonth else { return }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let comps = DateComponents(year: selectedYear, month: month, day: 1)
        let cal = Calendar(identifier: .gregorian)
        guard let firstDay = cal.date(from: comps) else { return }
        let lastDay = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) ?? firstDay
        let start = f.string(from: firstDay)
        let end = f.string(from: lastDay)
        rawEarnings = (try? await api.earningsByRange(start: start, end: end)) ?? []
        earningsByDay = rawEarnings.compactMap { d in
            guard let date = f.date(from: d.date) else { return nil }
            return ("\(cal.component(.day, from: date))", d.total)
        }
    }

    private func groupEarnings(_ raw: [EarningsDay], period: Period) -> [(String, Int)] {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        switch period {
        case .week:
            let dayNames = ["", "Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
            let weekday = calendar.component(.weekday, from: today)
            let daysToMonday = weekday == 1 ? -6 : 2 - weekday
            guard let monday = calendar.date(byAdding: .day, value: daysToMonday, to: today) else { return [] }
            var byWeekday: [Int: Int] = [:]
            for d in raw {
                guard let date = f.date(from: d.date),
                      date >= monday,
                      date < calendar.date(byAdding: .day, value: 7, to: monday)!
                else { continue }
                let wd = calendar.component(.weekday, from: date)
                byWeekday[wd, default: 0] += d.total
            }
            return (2...7).compactMap { wd in
                (dayNames[wd], byWeekday[wd] ?? 0)
            }
        case .month:
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "d"
            return raw.compactMap { d in
                guard let date = f.date(from: d.date) else { return nil }
                return (df.string(from: date), d.total)
            }
        case .year:
            let monthNames = ["","Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]
            var months: [Int: Int] = [:]
            for d in raw {
                guard let date = f.date(from: d.date),
                      calendar.component(.year, from: date) == selectedYear
                else { continue }
                let m = calendar.component(.month, from: date)
                months[m, default: 0] += d.total
            }
            return (1...12).compactMap { m in
                guard let total = months[m], total > 0 else { return nil }
                return (monthNames[m], total)
            }
        }
    }

    func addExpense(category: String, amount: Int, description: String, date: String = "") async -> Bool {
        isAddingExpense = true
        expenseError = nil
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let req = ExpenseCreateRequest(
            category: category,
            amount: amount,
            description: description,
            date: date.isEmpty ? f.string(from: Date()) : date
        )
        do {
            _ = try await api.addExpense(req)
            await load()
            isAddingExpense = false
            return true
        } catch {
            if (error as? URLError) != nil {
                expenseError = "Сервер недоступен. Попробуйте ещё раз через несколько секунд."
            } else {
                expenseError = error.localizedDescription
            }
            isAddingExpense = false
            return false
        }
    }

    func deleteExpense(id: Int) async {
        try? await api.deleteExpense(id: id)
        expenses.removeAll { $0.id == id }
    }

    func loadYearlyStats() async {
        yearlyStats = try? await api.request(.statsYearly(year: selectedYear), as: YearlyStatsResponse.self)
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
                if vm.stats != nil {
                    kpiGrid
                    earningsChart
                    topProceduresSection
                    expensesSection
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Аналитика")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Picker("", selection: $vm.selectedPeriod) {
                ForEach(StatsViewModel.Period.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.selectedPeriod) { _, _ in
                vm.selectedMonth = nil
                Task { await vm.load() }
            }

            if vm.selectedPeriod == .year {
                yearPickerRow
                monthGridRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var yearPickerRow: some View {
        HStack {
            Spacer()
            Button {
                if vm.selectedYear > vm.availableYears.first! {
                    vm.selectedYear -= 1
                    vm.selectedMonth = nil
                    Task { await vm.load() }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(vm.selectedYear > vm.availableYears.first! ? theme.accent : theme.textMuted)
            }
            Text("\(String(vm.selectedYear))")
                .font(DS.headline)
                .foregroundColor(theme.textPrimary)
                .frame(minWidth: 60)
                .multilineTextAlignment(.center)
            Button {
                if vm.selectedYear < vm.availableYears.last! {
                    vm.selectedYear += 1
                    vm.selectedMonth = nil
                    Task { await vm.load() }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(vm.selectedYear < vm.availableYears.last! ? theme.accent : theme.textMuted)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var monthGridRow: some View {
        let monthNames = ["Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(1...12, id: \.self) { m in
                let isFuture = vm.selectedYear == currentYear && m > currentMonth
                let isSelected = vm.selectedMonth == m
                Text(monthNames[m - 1])
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isFuture ? theme.textMuted.opacity(0.4) : (isSelected ? .white : theme.textMuted))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                    .cornerRadius(8)
                    .onTapGesture {
                        guard !isFuture else { return }
                        if vm.selectedMonth == m {
                            vm.selectedMonth = nil
                        } else {
                            vm.selectedMonth = m
                        }
                        Task { await vm.load() }
                    }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - KPI

    private var kpiGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            KpiCell(value: vm.currentRevenue.formatted, label: "Выручка", accentBorder: true, theme: theme)
            KpiCell(value: "\(vm.currentAppointments)", label: "Записей", accentBorder: false, theme: theme)
            KpiCell(value: "\(vm.currentClients)", label: "Клиентов", accentBorder: false, theme: theme)
            KpiCell(value: vm.avgCheck.formatted, label: "Ср. чек", accentBorder: true, theme: theme)
        }
    }

    // MARK: - Earnings Chart

    private var earningsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Выручка")

            BBGlassCard {
                if vm.earningsByDay.isEmpty {
                    Text("Данные появятся после первых записей 💅")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                } else {
                    BarChartView(data: vm.earningsByDay, theme: theme)
                        .frame(height: 140)
                }
            }
        }
    }

    // MARK: - Top Procedures

    private var topProceduresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Топ услуг")

            if let stats = vm.stats, !stats.topProcedures.isEmpty {
                BBGlassCard {
                    VStack(spacing: 8) {
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
                    .padding(8)
                }
            } else {
                BBGlassCard {
                    Text("Нет данных")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
    }

    // MARK: - Expenses

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Расходы", action: { vm.showAddExpense = true }, actionTitle: "Добавить")

            if vm.expenses.isEmpty {
                BBGlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundColor(theme.accent.opacity(0.4))
                        Text("Нет расходов")
                            .font(DS.body)
                            .foregroundColor(theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                ForEach(vm.expenses) { expense in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(theme.backgroundInput)
                                .frame(width: 36, height: 36)
                            Image(systemName: ExpenseCategory(rawValue: expense.category)?.icon ?? "ellipsis.circle")
                                .font(.system(size: 14))
                                .foregroundColor(theme.accent)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(expense.description)
                                .font(DS.caption)
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)
                            Text(expense.category)
                                .font(DS.caption)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer(minLength: 4)
                        Text("−\(expense.amount.formatted)")
                            .font(DS.caption)
                            .foregroundColor(theme.statusRed)
                    }
                    .padding(10)
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
}

// MARK: - KPI Cell

struct KpiCell: View {
    let value: String
    let label: String
    let accentBorder: Bool
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(DS.bodySmall)
                .foregroundColor(theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentBorder ? theme.accent : theme.borderSubtle, lineWidth: accentBorder ? 1 : 0.5)
        )
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
        HStack(spacing: 6) {
            Text("#\(index + 1)")
                .font(DS.caption)
                .foregroundColor(theme.textMuted)
                .frame(width: 20)

            Text(name)
                .font(DS.caption)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

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
            .frame(width: 50, height: 4)

            Text("\(count)")
                .font(DS.caption)
                .foregroundColor(theme.accent)
                .frame(width: 24, alignment: .trailing)
        }
        .padding(10)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r12)
    }
}

// MARK: - Bar Chart View

struct BarChartView: View {
    let data: [(String, Int)]
    let theme: AppTheme
    var onTap: ((Int) -> Void)? = nil

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
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(idx) }
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

// MARK: - AddExpenseSheet

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

                if let err = vm.expenseError {
                    Text(err)
                        .font(DS.bodySmall)
                        .foregroundColor(theme.statusRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                BBPrimaryButton(title: "Добавить расход", isLoading: vm.isAddingExpense, isDisabled: !isValid) {
                    Task {
                        let ok = await vm.addExpense(
                            category: selectedCategory.rawValue,
                            amount: Int(amount) ?? 0,
                            description: description
                        )
                        if ok { dismiss() }
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
        .onAppear { vm.expenseError = nil }
    }
}

#Preview {
    StatsView()
        .environment(\.theme, .pink)
}
