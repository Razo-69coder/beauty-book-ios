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

    enum Period: String, CaseIterable {
        case week = "week"
        case month = "month"
        case year = "year"

        var displayName: String {
            switch self {
            case .week:  return "Неделя"
            case .month: return "Месяц"
            case .year:  return "Год"
            }
        }
    }

    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var yearlyStats: YearlyStatsResponse? = nil
    @Published var selectedWeek: Int? = nil
    private var rawEarnings: [EarningsDay] = []
    var monthWeekOrder: [Int] = []

    var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 3)...current)
    }

    private let api = APIClient.shared

    var totalExpenses: Int { expenses.reduce(0) { $0 + $1.amount } }
    var netProfit: Int { (stats?.monthEarnings ?? 0) - totalExpenses }

    func load() async {
        isLoading = true
        if let s = try? await api.request(.stats, as: StatsResponse.self) {
            stats = s
        } else {
            stats = StatsResponse(totalClients: 0, totalAppointments: 0, totalEarnings: 0, monthEarnings: 0, topProcedures: [])
        }
        let daysCount: Int
        switch selectedPeriod {
        case .week:  daysCount = 30
        case .month: daysCount = 30
        case .year:  daysCount = 365
        }
        do {
            rawEarnings = try await api.earningsByDay(days: daysCount)
        } catch {
            print("earningsByDay error: \(error)")
            rawEarnings = []
        }
        print("earningsByDay count: \(rawEarnings.count), days param: \(daysCount), period: \(selectedPeriod), first 3: \(rawEarnings.prefix(3).map { "\($0.date)=\($0.total)" })")
        selectedWeek = nil
        recomputeEarnings()
        expenses = (try? await api.fetchExpenses()) ?? []
        await loadYearlyStats()
        isLoading = false
    }

    private func groupEarnings(_ raw: [EarningsDay], period: Period, daysCount: Int) -> [(String, Int)] {
        let calendar = Calendar.current
        let today = Date()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        switch period {
        case .week:
            let dayNames = ["","Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
            return raw.enumerated().map { (dayNames[$0.offset + 1], $0.element.total) }
        case .month:
            let monthDays = raw.compactMap { d -> (String, Int)? in
                guard let date = f.date(from: d.date) else { return nil }
                return (d.date, d.total)
            }
            var weeks: [Int: Int] = [:]
            for (dateStr, total) in monthDays {
                guard let date = f.date(from: dateStr) else { continue }
                let w = calendar.component(.weekOfMonth, from: date)
                weeks[w, default: 0] += total
            }
            monthWeekOrder = weeks.keys.sorted()
            return monthWeekOrder.map { ("Нед \($0)", weeks[$0] ?? 0) }
        case .year:
            let year = selectedYear
            let monthNames = ["","Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]
            var months: [Int: Int] = [:]
            for d in raw {
                guard let date = f.date(from: d.date),
                      calendar.component(.year, from: date) == year
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
        print("Loading yearly stats for year: \(selectedYear)")
        if let s = try? await api.request(.statsYearly(year: selectedYear), as: YearlyStatsResponse.self) {
            yearlyStats = s
            print("Yearly stats loaded for year: \(selectedYear), revenue: \(s.totalRevenue)")
        } else {
            print("Failed to load yearly stats for year: \(selectedYear)")
        }
    }

    func recomputeEarnings() {
        if let week = selectedWeek {
            earningsByDay = daysForWeek(week)
        } else if selectedPeriod == .week {
            earningsByDay = []
        } else {
            earningsByDay = groupEarnings(rawEarnings, period: selectedPeriod, daysCount: selectedPeriod == .year ? 365 : 30)
        }
    }

    func daysForWeek(_ weekNumber: Int) -> [(String, Int)] {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        let pf = DateFormatter()
        pf.dateFormat = "yyyy-MM-dd"
        let df = DateFormatter()
        df.dateFormat = "EEE"
        df.locale = Locale(identifier: "ru_RU")
        return rawEarnings.compactMap { d in
            guard let date = pf.date(from: d.date),
                  calendar.component(.weekOfMonth, from: date) == weekNumber,
                  calendar.component(.month, from: date) == month,
                  calendar.component(.year, from: date) == year
            else { return nil }
            let label = df.string(from: date).capitalized.prefix(2).uppercased()
            return (String(label), d.total)
        }
    }

    var weekOptions: [(number: Int, label: String)] {
        let calendar = Calendar.current
        let today = Date()
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        let df = DateFormatter()
        df.dateFormat = "d MMM"
        df.locale = Locale(identifier: "ru_RU")
        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }
        var weekDays: [Int: [Int]] = [:]
        for day in 1...range.count {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
            weekDays[calendar.component(.weekOfMonth, from: date), default: []].append(day)
        }
        return weekDays.keys.sorted().map { w in
            let days = weekDays[w]!
            let monthName = df.string(from: firstOfMonth).split(separator: " ").last ?? ""
            let label: String
            if days.count == 1 {
                label = "\(days.first!) \(monthName)"
            } else {
                label = "\(days.first!)–\(days.last!) \(monthName)"
            }
            return (w, label)
        }
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
                    profitRow(stats: stats)
                    if let ys = vm.yearlyStats {
                        yearlyStatsSection(ys)
                    }
                    earningsChart
                    twoColumnSection
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Аналитика")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            HStack {
                Text("За последние 30 дней")
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textMuted)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        if vm.selectedYear > vm.availableYears.first! {
                            vm.selectedYear -= 1
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
                        .frame(minWidth: 50)
                    Button {
                        if vm.selectedYear < vm.availableYears.last! {
                            vm.selectedYear += 1
                            Task { await vm.load() }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(vm.selectedYear < vm.availableYears.last! ? theme.accent : theme.textMuted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - KPI Grid

    private func kpiGrid(stats: StatsResponse) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            KpiCell(value: stats.monthEarnings.formatted, label: "Выручка", accentBorder: true, theme: theme)
            KpiCell(value: "\(stats.totalAppointments)", label: "Записей", accentBorder: false, theme: theme)
            KpiCell(value: "\(stats.totalClients)", label: "Клиентов", accentBorder: false, theme: theme)
            KpiCell(value: avgCheck.formatted, label: "Ср. чек", accentBorder: true, theme: theme)
        }
    }

    private var avgCheck: Int {
        guard let stats = vm.stats, stats.totalAppointments > 0 else { return 0 }
        return stats.monthEarnings / stats.totalAppointments
    }

    // MARK: - Profit Row

    private func profitRow(stats: StatsResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Выручка")
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
                Text(stats.monthEarnings.formatted + " ₽")
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
            }
            Spacer()
            Text("−")
                .font(DS.titleSmall)
                .foregroundColor(theme.textMuted)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Расходы")
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
                Text(vm.totalExpenses.formatted + " ₽")
                    .font(DS.body)
                    .foregroundColor(theme.statusRed)
            }
            Spacer()
            Text("=")
                .font(DS.titleSmall)
                .foregroundColor(theme.textMuted)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Прибыль")
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
                Text(vm.netProfit.formatted + " ₽")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(vm.netProfit >= 0 ? theme.statusGreen : theme.statusRed)
            }
        }
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r12)
        .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.borderSubtle, lineWidth: 1))
    }

    // MARK: - Yearly Stats

    private func yearlyStatsSection(_ ys: YearlyStatsResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "За \(String(vm.selectedYear)) год")
            
            HStack(spacing: 12) {
                KpiCell(value: ys.totalRevenue.formatted, label: "Выручка за год", accentBorder: true, theme: theme)
                KpiCell(value: "\(ys.totalAppointments)", label: "Записей за год", accentBorder: false, theme: theme)
            }
            
            if !ys.topServices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Топ услуг за год")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                    ForEach(Array(ys.topServices.prefix(5).enumerated()), id: \.offset) { index, svc in
                        HStack {
                            Text("#\(index + 1)")
                                .font(DS.caption)
                                .foregroundColor(theme.textMuted)
                                .frame(width: 20)
                            Text(svc.procedure)
                                .font(DS.caption)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text("\(svc.count)")
                                .font(DS.caption)
                                .foregroundColor(theme.accent)
                        }
                        .padding(8)
                        .background(theme.backgroundCard)
                        .cornerRadius(DS.r8)
                    }
                }
            }
        }
    }

    // MARK: - Earnings Chart

    private var earningsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BBSectionHeader(title: "Выручка по дням")
                if vm.selectedWeek != nil {
                    Button {
                        vm.selectedWeek = nil
                        vm.recomputeEarnings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Назад")
                        }
                        .font(DS.bodySmall)
                        .foregroundColor(theme.accent)
                    }
                    .padding(.leading, 8)
                }
                Spacer()
                Picker("", selection: $vm.selectedPeriod) {
                    ForEach(StatsViewModel.Period.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .onChange(of: vm.selectedPeriod) { _ in
                    Task { await vm.load() }
                }
            }

            BBGlassCard {
                if vm.selectedWeek == nil && vm.selectedPeriod == .week {
                    weekSelector
                } else if vm.earningsByDay.isEmpty {
                    Text("Данные появятся после первых записей 💅")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                } else {
                    BarChartView(
                        data: vm.earningsByDay,
                        theme: theme,
                        onTap: vm.selectedPeriod == .month && vm.selectedWeek == nil ? { idx in
                            guard idx < vm.monthWeekOrder.count else { return }
                            vm.selectedWeek = vm.monthWeekOrder[idx]
                            vm.recomputeEarnings()
                        } : nil
                    )
                    .frame(height: 140)
                }
            }
        }
    }

    private var weekSelector: some View {
        let options = vm.weekOptions
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.number) { opt in
                    Button {
                        vm.selectedWeek = opt.number
                        vm.recomputeEarnings()
                    } label: {
                        Text(opt.label)
                            .font(DS.caption)
                            .foregroundColor(theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.backgroundCard)
                            .cornerRadius(DS.r8)
                            .overlay(RoundedRectangle(cornerRadius: DS.r8).stroke(theme.borderSubtle, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 60)
    }

    // MARK: - Two Column Section

    private var twoColumnSection: some View {
        HStack(alignment: .top, spacing: 12) {
            expensesColumn
            topProceduresColumn
        }
    }

    private var expensesColumn: some View {
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
        .frame(maxWidth: .infinity)
    }

    private var topProceduresColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Топ услуг")

            if let stats = vm.stats, !stats.topProcedures.isEmpty {
                ForEach(Array(stats.topProcedures.prefix(5).enumerated()), id: \.offset) { index, proc in
                    TopProcedureRow(
                        index: index,
                        name: proc.procedure,
                        count: proc.count,
                        maxCount: stats.topProcedures.first?.count ?? 1,
                        theme: theme
                    )
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
        .frame(maxWidth: .infinity)
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
