import SwiftUI

// MARK: - Переход «Показать список» → Клиенты с фильтром «Давно не были»

extension Notification.Name {
    static let stOpenClientsAway = Notification.Name("stOpenClientsAway")
}

/// Флаг-переходчик: Статистика просит Клиенты открыться с фильтром «Давно не были»
enum STPendingClientsFilter {
    static var away: Bool = false
}

// MARK: - Данные экрана

/// День диапазона в формате сервера
struct STDayEarning: Identifiable {
    let date: String
    let total: Int
    let count: Int

    var id: String { date }
}

/// Столбик графика
struct STBar: Identifiable {
    let index: Int
    /// Короткая подпись снизу: «Пн», «6», «Я»
    let label: String
    /// Полная подпись для шапки графика: «Пт, 25 сентября»
    let fullLabel: String
    let value: Int
    let isFuture: Bool

    var id: Int { index }
}

/// Услуга в блоке «Популярные»
struct STTopItem: Identifiable {
    let name: String
    let count: Int
    /// Выручка по услуге, если цену удалось найти
    let revenue: Int?

    var id: String { name }
}

/// Период в виде двух дат (обе — начало суток)
struct STDateRange {
    let start: Date
    let end: Date

    var startKey: String { STFormat.key(start) }
    var endKey: String { STFormat.key(end) }
}

/// Категории расходов. В Models.swift есть свой ExpenseCategory из 4 пунктов,
/// здесь нужны все 6 из макета — поэтому свой набор с иконками строк.
enum STExpenseKind: String, CaseIterable {
    case materials = "Материалы"
    case rent = "Аренда"
    case ads = "Реклама"
    case education = "Обучение"
    case tools = "Инструменты"
    case other = "Другое"

    static let fallback: STExpenseKind = .other

    /// Название категории — совпадает с тем, что приходит с сервера
    var title: String { return rawValue }

    var icon: String {
        switch self {
        case .materials: return "cart.fill"
        case .rent: return "house.fill"
        case .ads: return "megaphone.fill"
        case .education: return "graduationcap.fill"
        case .tools: return "scissors"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// Иконка по названию категории из расхода; неизвестная — «Другое»
    static func icon(for raw: String) -> String {
        let kind: STExpenseKind = STExpenseKind(rawValue: raw) ?? .fallback
        return kind.icon
    }
}

// MARK: - Форматирование дат и месяцев

enum STFormat {
    static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// «2026-09-25»
    static func key(_ date: Date) -> String {
        return isoFormatter.string(from: date)
    }

    /// Разбор «2026-09-25» (первые 10 символов)
    static func date(fromKey key: String) -> Date? {
        let trimmed: String = key.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 10 else { return nil }
        return isoFormatter.date(from: String(trimmed.prefix(10)))
    }

    /// Правильная форма «25 сентября» в родительном падеже
    static func dayWithMonth(_ date: Date) -> String {
        let day: Int = STPeriodMath.calendar.component(.day, from: date)
        let month: Int = STPeriodMath.calendar.component(.month, from: date)
        return "\(day) \(monthGenitive(month))"
    }

    /// «Сентябрь»
    static func monthNominative(_ date: Date) -> String {
        let month: Int = STPeriodMath.calendar.component(.month, from: date)
        return monthNominative(month)
    }

    /// «сентябрь»
    static func monthNominativeLower(_ month: Int) -> String {
        return monthNominative(month).lowercased()
    }

    static func monthNominative(_ month: Int) -> String {
        let safe: Int = min(max(month, 1), 12)
        return nominatives[safe - 1]
    }

    static func monthGenitive(_ month: Int) -> String {
        let safe: Int = min(max(month, 1), 12)
        return genitives[safe - 1]
    }

    /// «сентябрю» — для «к сентябрю»
    static func monthDative(_ month: Int) -> String {
        let safe: Int = min(max(month, 1), 12)
        return datives[safe - 1]
    }

    static func monthShortLower(_ month: Int) -> String {
        let safe: Int = min(max(month, 1), 12)
        return shortsLower[safe - 1]
    }

    private static let nominatives: [String] = [
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ]

    private static let genitives: [String] = [
        "января", "февраля", "марта", "апреля", "мая", "июня",
        "июля", "августа", "сентября", "октября", "ноября", "декабря"
    ]

    private static let datives: [String] = [
        "январю", "февралю", "марту", "апрелю", "маю", "июню",
        "июлю", "августу", "сентябрю", "октюбрю", "ноябрю", "декабрю"
    ]

    private static let shortsLower: [String] = [
        "янв", "фев", "мар", "апр", "май", "июн",
        "июл", "авг", "сен", "окт", "ноя", "дек"
    ]
}

// MARK: - Периоды

enum STPeriodMath {
    /// Календарь с понедельчным началом недели
    static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        cal.firstWeekday = 2
        return cal
    }()

    static let weekdayShort: [String] = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    static let monthShortCaps: [String] = ["Я", "Ф", "М", "А", "М", "И", "И", "А", "С", "О", "Н", "Д"]

    /// Границы выбранного периода: offset 0 — текущий, −1 — прошлый
    static func range(period: StatsViewModel.Period, offset: Int, today: Date) -> STDateRange {
        switch period {
        case .week: return weekRange(offset: offset, today: today)
        case .month: return monthRange(offset: offset, today: today)
        case .year: return yearRange(offset: offset, today: today)
        }
    }

    /// Период, с которым сравниваем (предыдущий)
    static func comparisonRange(period: StatsViewModel.Period, offset: Int, today: Date) -> STDateRange {
        return range(period: period, offset: offset - 1, today: today)
    }

    /// Каждый день периода в формате «yyyy-MM-dd»
    static func dayKeys(in range: STDateRange) -> [String] {
        var keys: [String] = []
        var current: Date = range.start
        while current <= range.end {
            keys.append(STFormat.key(current))
            guard let next: Date = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return keys
    }

    /// Насколько далеко можно листать назад — 5 лет
    static func minimumOffset(for period: StatsViewModel.Period) -> Int {
        switch period {
        case .week: return -260
        case .month: return -60
        case .year: return -5
        }
    }

    // MARK: Подписи

    /// «21–27 сентября», «29 сентября – 5 октября», «Сентябрь 2026», «2026 год»
    static func label(period: StatsViewModel.Period, range: STDateRange) -> String {
        switch period {
        case .week: return weekLabel(range)
        case .month: return monthLabel(range)
        case .year: return yearLabel(range)
        }
    }

    /// «к прошлой неделе», «к августу», «к 2025 году»
    static func comparisonLabel(period: StatsViewModel.Period, range: STDateRange) -> String {
        switch period {
        case .week: return "прошлой неделе"
        case .month: return monthDative(calendar.component(.month, from: range.start))
        case .year: return "\(calendar.component(.year, from: range.start)) году"
        }
    }

    /// «Расходы · сентябрь» / «· 21–27 сентября» / «· 2026»
    static func expensesTitle(period: StatsViewModel.Period, range: STDateRange) -> String {
        switch period {
        case .week: return weekLabel(range)
        case .month: return monthNominativeLower(calendar.component(.month, from: range.start))
        case .year: return "\(calendar.component(.year, from: range.start))"
        }
    }

    private static func weekLabel(_ range: STDateRange) -> String {
        let startMonth: Int = calendar.component(.month, from: range.start)
        let endMonth: Int = calendar.component(.month, from: range.end)
        let startDay: Int = calendar.component(.day, from: range.start)
        let endDay: Int = calendar.component(.day, from: range.end)
        if startMonth == endMonth {
            return "\(startDay)–\(endDay) \(monthGenitive(startMonth))"
        }
        return "\(STFormat.dayWithMonth(range.start)) – \(STFormat.dayWithMonth(range.end))"
    }

    private static func monthLabel(_ range: STDateRange) -> String {
        let year: Int = calendar.component(.year, from: range.start)
        return "\(monthNominative(calendar.component(.month, from: range.start))) \(year)"
    }

    private static func yearLabel(_ range: STDateRange) -> String {
        return "\(calendar.component(.year, from: range.start)) год"
    }

    // MARK: Границы

    private static func weekRange(offset: Int, today: Date) -> STDateRange {
        let base: Date = calendar.startOfDay(for: today)
        let shifted: Date = calendar.date(byAdding: .day, value: offset * 7, to: base) ?? base
        let weekday: Int = calendar.component(.weekday, from: shifted)
        // .weekday: 1 = воскресенье, 2 = понедельник
        let daysToMonday: Int = (weekday + 5) % 7
        let monday: Date = calendar.date(byAdding: .day, value: -daysToMonday, to: shifted) ?? shifted
        let sunday: Date = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        return STDateRange(start: monday, end: sunday)
    }

    private static func monthRange(offset: Int, today: Date) -> STDateRange {
        let year: Int = calendar.component(.year, from: today)
        let month: Int = calendar.component(.month, from: today)
        let start: Date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? today
        let shifted: Date = calendar.date(byAdding: .month, value: offset, to: start) ?? start
        let first: Date = calendar.date(
            from: calendar.dateComponents([.year, .month], from: shifted)
        ) ?? shifted
        let dayCount: Int = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let last: Date = calendar.date(byAdding: .day, value: dayCount - 1, to: first) ?? first
        return STDateRange(start: first, end: last)
    }

    private static func yearRange(offset: Int, today: Date) -> STDateRange {
        let year: Int = calendar.component(.year, from: today) + offset
        let first: Date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? today
        let last: Date = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? first
        return STDateRange(start: first, end: last)
    }
}

// MARK: - View Model

@MainActor
final class StatsViewModel: ObservableObject {
    enum Period: String, CaseIterable {
        case week, month, year

        var displayName: String {
            switch self {
            case .week: return "Неделя"
            case .month: return "Месяц"
            case .year: return "Год"
            }
        }
    }

    // Период и положение
    @Published var period: Period = .month
    @Published var offset: Int = 0

    // Состояние загрузки
    @Published var isLoading: Bool = false
    @Published var isStale: Bool = false
    @Published var hasLoadedOnce: Bool = false
    /// Растёт с каждой загрузкой — по нему заново вырастают столбики
    @Published var growToken: Int = 0

    // Данные периода
    @Published var days: [STDayEarning] = []
    @Published var previousDays: [STDayEarning] = []
    @Published var expenses: [Expense] = []

    // Метрики
    @Published var noShowCount: Int = 0
    @Published var clientsCount: Int = 0
    @Published var allTimeClients: Int = 0
    @Published var topItems: [STTopItem] = []
    @Published var awayCount: Int = 0

    // Состояние экрана
    @Published var selectedBarIndex: Int? = nil
    @Published var showExpenseSheet: Bool = false
    @Published var isAddingExpense: Bool = false
    @Published var expenseError: String? = nil

    /// Номер текущей загрузки — защита от гонок при быстрой смене периода
    private var loadToken: Int = 0
    private var didLoadClients: Bool = false

    private let api = APIClient.shared

    // MARK: Границы

    private var today: Date { Date() }
    private var todayKey: String { STFormat.key(today) }

    var range: STDateRange {
        return STPeriodMath.range(period: period, offset: offset, today: today)
    }

    private var comparisonRange: STDateRange {
        return STPeriodMath.comparisonRange(period: period, offset: offset, today: today)
    }

    var periodLabel: String {
        return STPeriodMath.label(period: period, range: range)
    }

    var comparisonLabel: String {
        return STPeriodMath.comparisonLabel(period: period, range: comparisonRange)
    }

    var expensesTitle: String {
        return STPeriodMath.expensesTitle(period: period, range: range)
    }

    var isYearPeriod: Bool { period == .year }

    var canGoForward: Bool { offset < 0 }

    var canGoBack: Bool { offset > STPeriodMath.minimumOffset(for: period) }

    /// Расход по умолчанию: сегодня для текущего периода, иначе последний день периода
    var defaultExpenseDateKey: String {
        if offset == 0 { return todayKey }
        return range.endKey
    }

    // MARK: Деньги

    /// Заработано — только прошедшие дни
    var earned: Int {
        return days.filter { $0.date <= todayKey }.reduce(0) { $0 + $1.total }
    }

    /// Ещё запланировано — будущие дни
    var planned: Int {
        return days.filter { $0.date > todayKey }.reduce(0) { $0 + $1.total }
    }

    var periodExpenses: [Expense] {
        let start: String = range.startKey
        let end: String = range.endKey
        return expenses
            .filter { $0.date >= start && $0.date <= end }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                return lhs.id > rhs.id
            }
    }

    var expensesTotal: Int {
        return periodExpenses.reduce(0) { $0 + $1.amount }
    }

    var net: Int {
        return max(0, earned - expensesTotal)
    }

    /// Записей — сумма count прошедших дней
    var appointments: Int {
        return days.filter { $0.date <= todayKey }.reduce(0) { $0 + $1.count }
    }

    /// Средний чек, округлённый до 10 ₽
    var avgCheck: Int {
        guard appointments > 0 else { return 0 }
        return roundToTen(Double(earned) / Double(appointments))
    }

    /// Доля расходов в выручке, %
    var expensesSharePercent: Int {
        guard earned > 0 else { return 0 }
        let share: Double = Double(expensesTotal) / Double(earned) * 100.0
        return Int(share.rounded())
    }

    /// Сколько дней периода уже прошло — для честного сравнения
    private var comparisonDayCount: Int {
        let allKeys: [String] = STPeriodMath.dayKeys(in: range)
        guard offset == 0 else { return allKeys.count }
        let pastCount: Int = allKeys.filter { $0 <= todayKey }.count
        return max(pastCount, 1)
    }

    /// Сумма прошлого периода за то же количество первых дней
    private var previousTotal: Int {
        let keys: [String] = STPeriodMath.dayKeys(in: comparisonRange)
        let take: Int = min(comparisonDayCount, keys.count)
        let allowed: Set<String> = Set(keys.prefix(take))
        return previousDays.filter { allowed.contains($0.date) }.reduce(0) { $0 + $1.total }
    }

    /// Процент изменения; nil — сравнивать не с чем
    var deltaPercent: Int? {
        let prev: Int = previousTotal
        guard prev > 0 else { return nil }
        let diff: Double = Double(earned - prev) / Double(prev) * 100.0
        return Int(diff.rounded())
    }

    // MARK: График

    var bars: [STBar] {
        switch period {
        case .week: return weekBars()
        case .month: return dayBars()
        case .year: return monthBars()
        }
    }

    var barsMaxValue: Int {
        return max(bars.map { $0.value }.max() ?? 0, 1)
    }

    var hasFutureBars: Bool {
        return bars.contains { $0.isFuture }
    }

    var selectedBar: STBar? {
        guard let index = selectedBarIndex, index >= 0, index < bars.count else { return nil }
        return bars[index]
    }

    /// Среднее по прошедшим дням с выручкой, округлённое до 10 ₽
    var averagePerDay: Int {
        let withMoney: [STBar] = bars.filter { !$0.isFuture && $0.value > 0 }
        guard !withMoney.isEmpty else { return 0 }
        return roundToTen(Double(earned) / Double(withMoney.count))
    }

    private func weekBars() -> [STBar] {
        return STPeriodMath.dayKeys(in: range).enumerated().map { index, key in
            let date: Date = STFormat.date(fromKey: key) ?? range.start
            let weekday: Int = STPeriodMath.calendar.component(.weekday, from: date)
            let label: String = STPeriodMath.weekdayShort[(weekday + 5) % 7]
            return STBar(
                index: index,
                label: label,
                fullLabel: "\(label), \(STFormat.dayWithMonth(date))",
                value: total(on: key),
                isFuture: key > todayKey
            )
        }
    }

    private func dayBars() -> [STBar] {
        return STPeriodMath.dayKeys(in: range).enumerated().map { index, key in
            let date: Date = STFormat.date(fromKey: key) ?? range.start
            let day: Int = STPeriodMath.calendar.component(.day, from: date)
            // Подписи 1, 6, 11, 16, 21, 26, 31
            let label: String = index % 5 == 0 ? "\(day)" : ""
            return STBar(
                index: index,
                label: label,
                fullLabel: STFormat.dayWithMonth(date),
                value: total(on: key),
                isFuture: key > todayKey
            )
        }
    }

    private func monthBars() -> [STBar] {
        let year: Int = STPeriodMath.calendar.component(.year, from: range.start)
        var sums: [Int: Int] = [:]
        for entry in days {
            guard let date: Date = STFormat.date(fromKey: entry.date) else { continue }
            let month: Int = STPeriodMath.calendar.component(.month, from: date)
            sums[month, default: 0] += entry.total
        }
        return (1...12).map { month in
            let first: Date = STPeriodMath.calendar.date(
                from: DateComponents(year: year, month: month, day: 1)
            ) ?? range.start
            return STBar(
                index: month - 1,
                label: STPeriodMath.monthShortCaps[month - 1],
                fullLabel: STFormat.monthNominative(month),
                value: sums[month] ?? 0,
                isFuture: STFormat.key(first) > todayKey
            )
        }
    }

    private func total(on key: String) -> Int {
        return days.first { $0.date == key }?.total ?? 0
    }

    // MARK: Подписи плиток

    var appointmentsHint: String {
        if isYearPeriod { return "за год" }
        if noShowCount > 0 {
            let word: String = ruPlural(noShowCount, "неявка", "неявки", "неявок")
            return "\(noShowCount) \(word)"
        }
        return "без неявок"
    }

    var clientsHint: String {
        return isYearPeriod ? "всего в базе" : "за период"
    }

    var topTotalCount: Int {
        return topItems.reduce(0) { $0 + $1.count }
    }

    func topShare(_ item: STTopItem) -> Int {
        let sum: Int = topTotalCount
        guard sum > 0 else { return 0 }
        return Int((Double(item.count) / Double(sum) * 100.0).rounded())
    }

    // MARK: Действия

    func setPeriod(_ newPeriod: Period) {
        guard newPeriod != period else { return }
        HapticManager.selection()
        withAnimation(DS.springSnappy) {
            period = newPeriod
            offset = 0
            selectedBarIndex = nil
        }
        Task { await load() }
    }

    func shiftPeriod(by delta: Int) {
        var next: Int = offset + delta
        if next > 0 { next = 0 }
        if next < STPeriodMath.minimumOffset(for: period) { next = STPeriodMath.minimumOffset(for: period) }
        guard next != offset else { return }
        HapticManager.light()
        withAnimation(DS.springSmooth) {
            offset = next
            selectedBarIndex = nil
        }
        Task { await load() }
    }

    func selectBar(_ index: Int) {
        HapticManager.selection()
        withAnimation(DS.springSnappy) {
            selectedBarIndex = (selectedBarIndex == index) ? nil : index
        }
    }

    func openAwayClients() {
        HapticManager.selection()
        STPendingClientsFilter.away = true
        NotificationCenter.default.post(name: .stOpenClientsAway, object: nil)
    }

    // MARK: Загрузка

    func load() async {
        loadToken += 1
        let token: Int = loadToken
        if hasLoadedOnce {
            isStale = true
        } else {
            isLoading = true
        }

        let current: STDateRange = range
        let previous: STDateRange = comparisonRange

        async let earningsTask: [EarningsDay]? = try? await api.earningsByRange(
            start: current.startKey,
            end: current.endKey
        )
        async let previousTask: [EarningsDay]? = try? await api.earningsByRange(
            start: previous.startKey,
            end: previous.endKey
        )
        async let expensesTask: [Expense]? = try? await api.fetchExpenses()
        async let servicesTask: ServicesResponse? = try? await api.request(.services, as: ServicesResponse.self)
        async let statsTask: StatsResponse? = try? await api.request(.stats, as: StatsResponse.self)

        let earnings: [EarningsDay] = await earningsTask ?? []
        let previousEarnings: [EarningsDay] = await previousTask ?? []
        let loadedExpenses: [Expense] = await expensesTask ?? []
        let services: [Service] = await servicesTask?.services ?? []
        let statsResponse: StatsResponse? = await statsTask

        var yearlyResponse: YearlyStatsResponse? = nil
        if isYearPeriod {
            let year: Int = STPeriodMath.calendar.component(.year, from: current.start)
            yearlyResponse = try? await api.request(.statsYearly(year: year), as: YearlyStatsResponse.self)
        }

        // Показатели из расписания — только для недели и месяца
        var scheduleStats: STScheduleStats = STScheduleStats.empty
        if !isYearPeriod {
            scheduleStats = await loadScheduleStats(range: current, services: services)
        }

        // Пока результат считался, могли начать новую загрузку
        guard token == loadToken else { return }

        days = earnings.map { STDayEarning(date: $0.date, total: $0.total, count: $0.count) }
        previousDays = previousEarnings.map { STDayEarning(date: $0.date, total: $0.total, count: $0.count) }
        expenses = loadedExpenses

        noShowCount = scheduleStats.noShow
        clientsCount = isYearPeriod ? (statsResponse?.totalClients ?? 0) : scheduleStats.clients
        allTimeClients = statsResponse?.totalClients ?? 0

        if isYearPeriod {
            topItems = makeYearTopItems(yearlyResponse, services: services)
        } else {
            topItems = makeTopItems(scheduleStats.counts, scheduleStats.revenues, scheduleStats.fallbacks)
        }

        if !didLoadClients {
            didLoadClients = true
            awayCount = await countAwayClients()
        }

        isLoading = false
        isStale = false
        hasLoadedOnce = true
        growToken += 1
    }

    /// Загружает расписание прошедших дней периода (не больше 31 запроса)
    private func loadScheduleStats(range: STDateRange, services: [Service]) async -> STScheduleStats {
        let today: String = STFormat.key(Date())
        let pastKeys: [String] = STPeriodMath.dayKeys(in: range).filter { $0 <= today }.suffix(31).map { $0 }
        guard !pastKeys.isEmpty else { return STScheduleStats.empty }

        let prices: [String: Int] = STPriceIndex.make(services)
        let collected: [[STAppointmentFact]] = await withTaskGroup(
            of: [STAppointmentFact].self,
            returning: [[STAppointmentFact]].self
        ) { group in
            for key in pastKeys {
                group.addTask { [api] in
                    guard let response: ScheduleResponse = try? await api.request(
                        .schedule(date: key),
                        as: ScheduleResponse.self
                    ) else { return [] }
                    return STAppointmentFact.facts(from: response.appointments, prices: prices)
                }
            }
            var all: [[STAppointmentFact]] = []
            for await dayFacts in group {
                guard !Task.isCancelled else { return all }
                all.append(dayFacts)
            }
            return all
        }

        var stats: STScheduleStats = STScheduleStats.empty
        for dayFacts in collected {
            for fact in dayFacts {
                if fact.isNoShow { stats.noShow += 1 }
                if !fact.isCancelled { stats.clientIds.insert(fact.clientId) }
                stats.counts[fact.part, default: 0] += 1
                stats.revenues[fact.part, default: 0] += fact.revenue
                stats.fallbacks[fact.part, default: 0] += fact.fallbackRevenue
            }
        }
        stats.clients = stats.clientIds.count
        return stats
    }

    /// Топ услуг недели/месяца из расписания
    private func makeTopItems(
        _ counts: [String: Int],
        _ revenues: [String: Int],
        _ fallbacks: [String: Int]
    ) -> [STTopItem] {
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(4)
            .map { entry in
                // Цена услуги, а если её нет — доля цены записи, делённая на части
                let total: Int = (revenues[entry.key] ?? 0) + (fallbacks[entry.key] ?? 0)
                let revenue: Int? = total > 0 ? total : nil
                return STTopItem(name: entry.key, count: entry.value, revenue: revenue)
            }
    }

    /// Топ услуг года — из yearlyStats, выручка только если нашли цену услуги
    private func makeYearTopItems(
        _ response: YearlyStatsResponse?,
        services: [Service]
    ) -> [STTopItem] {
        guard let response = response else { return [] }
        let prices: [String: Int] = STPriceIndex.make(services)
        return response.topServices
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.procedure < rhs.procedure
            }
            .prefix(4)
            .map { item in
                var revenue: Int? = nil
                if let price = prices[item.procedure.lowercased()] {
                    revenue = price * item.count
                }
                return STTopItem(name: item.procedure, count: item.count, revenue: revenue)
            }
    }

    /// Клиентки, которые не приходили больше 35 дней — так же, как фильтр «Давно не были»
    private func countAwayClients() async -> Int {
        var collected: [Client] = []
        var seenIds: Set<Int> = []
        var page: Int = 0
        while page < 30 {
            guard let response: ClientsResponse = try? await api.request(
                .clients(page: page, search: ""),
                as: ClientsResponse.self
            ) else { break }
            var added: Int = 0
            for client in response.clients {
                if seenIds.insert(client.id).inserted {
                    collected.append(client)
                    added += 1
                }
            }
            if response.clients.isEmpty || added == 0 { break }
            if collected.count >= response.total { break }
            page += 1
        }
        let today: Date = Date()
        var result: Int = 0
        for client in collected {
            guard let lastVisit: Date = STFormat.date(fromKey: client.lastVisit ?? "") else { continue }
            let days: Int = STPeriodMath.calendar.dateComponents(
                [.day],
                from: STPeriodMath.calendar.startOfDay(for: lastVisit),
                to: STPeriodMath.calendar.startOfDay(for: today)
            ).day ?? 0
            if days > 35 { result += 1 }
        }
        return result
    }

    // MARK: Расходы

    func addExpense(kind: String, amount: Int, note: String, dateKey: String) async -> Bool {
        isAddingExpense = true
        expenseError = nil
        let request = ExpenseCreateRequest(
            category: kind,
            amount: amount,
            description: note.isEmpty ? kind : note,
            date: dateKey
        )
        do {
            _ = try await api.addExpense(request)
            if let fresh: [Expense] = try? await api.fetchExpenses() {
                expenses = fresh
            }
            isAddingExpense = false
            return true
        } catch {
            expenseError = "Не удалось сохранить расход. Проверьте связь и попробуйте ещё раз."
            isAddingExpense = false
            return false
        }
    }

    /// Удаляет расход и убирает его из списка только после ответа сервера
    func deleteExpense(id: Int) async -> Bool {
        do {
            try await api.deleteExpense(id: id)
            expenses.removeAll { $0.id == id }
            return true
        } catch {
            return false
        }
    }

    private func roundToTen(_ value: Double) -> Int {
        return Int((value / 10.0).rounded()) * 10
    }
}

// MARK: - Промежуточные типы загрузки

/// Промежуточный итог по расписанию за прошедшие дни периода
struct STScheduleStats {
    var noShow: Int = 0
    var clients: Int = 0
    var clientIds: Set<Int> = []
    var counts: [String: Int] = [:]
    var revenues: [String: Int] = [:]
    /// Доля цены записи по частям, у которых не нашлось цены услуги
    var fallbacks: [String: Int] = [:]

    static let empty: STScheduleStats = STScheduleStats()
}

/// Одна часть записи: «Маникюр + Дизайн» распадается на две части
struct STAppointmentFact {
    let part: String
    let clientId: Int
    let isNoShow: Bool
    let isCancelled: Bool
    /// Выручка части, если нашли цену услуги
    let revenue: Int
    /// Доля цены записи, если цену услуги не нашли
    let fallbackRevenue: Int

    static func facts(from appointments: [Appointment], prices: [String: Int]) -> [STAppointmentFact] {
        var result: [STAppointmentFact] = []
        for appointment in appointments {
            let parts: [String] = appointment.procedure
                .components(separatedBy: "+")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let share: Int = parts.isEmpty ? appointment.price : appointment.price / parts.count
            for part in parts {
                let known: Int? = prices[part.lowercased()]
                result.append(STAppointmentFact(
                    part: part,
                    clientId: appointment.clientId,
                    isNoShow: appointment.status == .noShow,
                    isCancelled: appointment.status == .cancelled,
                    revenue: known ?? 0,
                    fallbackRevenue: known == nil ? share : 0
                ))
            }
        }
        return result
    }
}

/// Поиск цены услуги по названию без учёта регистра
enum STPriceIndex {
    static func make(_ services: [Service]) -> [String: Int] {
        var index: [String: Int] = [:]
        for service in services {
            index[service.name.lowercased()] = service.priceDefault
        }
        return index
    }
}
// MARK: - Появление блоков по очереди

/// Блок проявляется со сдвигом: прозрачность и подъём снизу
struct STReveal: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: verticalOffset)
            .animation(animation, value: shown)
            .onAppear(perform: reveal)
    }

    private var verticalOffset: CGFloat {
        if shown || reduceMotion { return 0 }
        return 14
    }

    private var animation: Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        return DS.springSmooth.delay(Double(index) * 0.05)
    }

    private func reveal() {
        guard !shown else { return }
        if reduceMotion {
            shown = true
            return
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(index) * 50_000_000)
            shown = true
        }
    }
}

extension View {
    /// Показывать блок с задержкой по номеру
    func stReveal(_ index: Int) -> some View {
        modifier(STReveal(index: index))
    }
}

// MARK: - Сегмент «Неделя / Месяц / Год»

struct STSegment: View {
    let period: StatsViewModel.Period
    let onPick: (StatsViewModel.Period) -> Void

    @Environment(\.theme) private var theme
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatsViewModel.Period.allCases, id: \.self) { item in
                button(for: item)
            }
        }
        .padding(3)
        .frame(height: 44)
        .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 14))
    }

    private func button(for item: StatsViewModel.Period) -> some View {
        let isSelected: Bool = period == item
        return Button {
            onPick(item)
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(theme.gradientPrimary)
                        .matchedGeometryEffect(id: "stSegmentPill", in: pill)
                }
                Text(item.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.96))
    }
}

// MARK: - Навигация по периодам

struct STPeriodNav: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let onShift: (Int) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DS.s4) {
            arrow("chevron.left", enabled: canGoBack, delta: -1, hint: "Предыдущий период")
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(reduceMotion ? .identity : .numericText())
                .frame(maxWidth: .infinity)
            arrow("chevron.right", enabled: canGoForward, delta: 1, hint: "Следующий период")
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, delta: Int, hint: String) -> some View {
        return Button {
            onShift(delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.9))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(hint)
    }
}

// MARK: - Главная карточка

struct STHeroCard: View {
    let earned: Int
    let delta: Int?
    let comparisonTitle: String
    let net: Int
    let planned: Int

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            Text("Заработано")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
            amount
            comparison
            Divider().overlay(theme.borderSubtle)
            row("Чистыми после расходов", rubText(net), theme.textPrimary)
            if planned > 0 {
                row("Ещё запланировано", "+\(rubText(planned))", theme.accent)
            }
        }
        .padding(DS.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.borderSubtle, lineWidth: 1))
        .overlay(alignment: .topTrailing) { accentSpot }
    }

    private var amount: some View {
        Text(rubText(earned))
            .font(.system(size: 38, weight: .bold, design: .rounded))
            .foregroundColor(theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: Double(earned)))
            .animation(DS.springSmooth, value: earned)
    }

    @ViewBuilder
    private var comparison: some View {
        if let delta = delta {
            HStack(spacing: DS.s8) {
                STDeltaBadge(value: delta)
                Text("к \(comparisonTitle)")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    /// Мягкое пятно угла карточки
    private var accentSpot: some View {
        Circle()
            .fill(theme.accent.opacity(0.18))
            .frame(width: 130, height: 130)
            .blur(radius: 26)
            .offset(x: 34, y: -34)
            .allowsHitTesting(false)
    }

    private func row(_ title: String, _ value: String, _ color: Color) -> some View {
        return HStack(spacing: DS.s8) {
            Text(title)
                .font(DS.body)
                .foregroundColor(theme.textSecondary)
            Spacer(minLength: DS.s8)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

/// Плашка «▲ 7%» / «▼ 7%»
struct STDeltaBadge: View {
    let value: Int

    @Environment(\.theme) private var theme

    private var isUp: Bool { value >= 0 }

    private var title: String {
        return "\(isUp ? "▲" : "▼") \(abs(value))%"
    }

    private var color: Color {
        return isUp ? theme.statusGreen : theme.statusRed
    }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
    }
}
// MARK: - График

struct STBarChart: View {
    @ObservedObject var vm: StatsViewModel

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let chartHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            header
            plot
            if vm.hasFutureBars { legend }
        }
        .padding(DS.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: DS.r20))
        .overlay(RoundedRectangle(cornerRadius: DS.r20).stroke(theme.borderSubtle, lineWidth: 1))
    }

    // MARK: Шапка графика

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.s8) {
            Text(title)
                .font(DS.headline)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(reduceMotion ? .identity : .numericText())
            Spacer(minLength: DS.s8)
            Text(rightTitle)
                .font(DS.bodySmall)
                .foregroundColor(rightColor)
                .lineLimit(1)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
    }

    private var title: String {
        guard let bar = vm.selectedBar else { return vm.isYearPeriod ? "По месяцам" : "По дням" }
        return bar.fullLabel
    }

    private var rightTitle: String {
        guard let bar = vm.selectedBar else { return "в среднем \(rubText(vm.averagePerDay))" }
        if bar.isFuture { return "\(rubText(bar.value)) запланировано" }
        return rubText(bar.value)
    }

    private var rightColor: Color {
        guard vm.selectedBar != nil else { return theme.textSecondary }
        return theme.accent
    }

    // MARK: Поле графика

    @ViewBuilder
    private var plot: some View {
        if vm.barsMaxValue <= 1 && vm.bars.allSatisfy({ $0.value == 0 }) {
            empty
        } else {
            VStack(spacing: 6) {
                ZStack(alignment: .bottom) {
                    averageLine
                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(vm.bars) { bar in
                            column(bar)
                        }
                    }
                }
                .frame(height: chartHeight)
                labels
            }
        }
    }

    private var empty: some View {
        Text("Данные появятся после первых записей")
            .font(DS.bodySmall)
            .foregroundColor(theme.textMuted)
            .frame(maxWidth: .infinity)
            .frame(height: chartHeight)
    }

    /// Столбик: прошедшие — пружина, будущие — бледнее, нулевые — еле заметные
    private func column(_ bar: STBar) -> some View {
        let ratio: CGFloat = CGFloat(bar.value) / CGFloat(vm.barsMaxValue)
        let height: CGFloat = max(3, chartHeight * ratio)
        let dimmed: Bool = vm.selectedBarIndex != nil && vm.selectedBarIndex != bar.index
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            UnevenRoundedRectangle(
                topLeadingRadius: 5,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 5
            )
            .fill(AnyShapeStyle(fill(for: bar)))
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .opacity(dimmed ? 0.4 : 1)
        }
        .frame(height: chartHeight)
        .contentShape(Rectangle())
        .onTapGesture { vm.selectBar(bar.index) }
        .animation(DS.springSmooth.delay(Double(bar.index) * 0.012), value: vm.growToken)
    }

    private func fill(for bar: STBar) -> AnyShapeStyle {
        if bar.value == 0 { return AnyShapeStyle(theme.borderSubtle) }
        if bar.isFuture { return AnyShapeStyle(theme.accent.opacity(0.28)) }
        return AnyShapeStyle(theme.gradientPrimary)
    }

    private var labels: some View {
        HStack(alignment: .top, spacing: barSpacing) {
            ForEach(vm.bars) { bar in
                Text(bar.label)
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Пунктирная линия среднего
    private var averageLine: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0.5))
            path.addLine(to: CGPoint(x: 1000, y: 0.5))
        }
        .stroke(theme.textMuted.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .frame(height: 1)
        .offset(y: -averageOffset)
        .opacity(vm.averagePerDay > 0 ? 1 : 0)
    }

    private var averageOffset: CGFloat {
        let ratio: CGFloat = CGFloat(vm.averagePerDay) / CGFloat(vm.barsMaxValue)
        return max(0, chartHeight - chartHeight * ratio)
    }

    private var barSpacing: CGFloat {
        switch vm.period {
        case .week: return 8
        case .month: return 3
        case .year: return 6
        }
    }

    private var legend: some View {
        HStack(spacing: DS.s16) {
            dot("заработано", AnyShapeStyle(theme.gradientPrimary))
            dot("записаны, ещё впереди", AnyShapeStyle(theme.accent.opacity(0.28)))
        }
    }

    private func dot(_ title: String, _ style: AnyShapeStyle) -> some View {
        return HStack(spacing: 6) {
            Circle()
                .fill(style)
                .frame(width: 8, height: 8)
            Text(title)
                .font(DS.caption)
                .foregroundColor(theme.textMuted)
        }
    }
}

// MARK: - Плитки показателей

struct STKpiTile: View {
    let title: String
    let value: String
    let hint: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(hint)
                .font(.system(size: 12))
                .foregroundColor(theme.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

// MARK: - Подсказка «Давно не были»

struct STAwayHint: View {
    let count: Int
    let action: () -> Void

    @Environment(\.theme) private var theme

    private var title: String {
        let word: String = ruPlural(
            count,
            "клиентка давно не была",
            "клиентки давно не были",
            "клиенток давно не были"
        )
        return "\(count) \(word)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.s12) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15))
                        .foregroundColor(theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.label)
                        .foregroundColor(theme.textPrimary)
                    Text("Напомни о себе, и они вернутся. Показать список")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.s8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
            .padding(DS.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(CLPressStyle(scale: 0.98))
    }
}

// MARK: - Заголовок раздела

struct STSectionTitle: View {
    let title: String

    @Environment(\.theme) private var theme

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textMuted)
    }
}
// MARK: - Популярные услуги

struct STTopRow: View {
    let index: Int
    let item: STTopItem
    let share: Int
    let maxCount: Int

    @Environment(\.theme) private var theme
    @State private var grown: Bool = false

    private var shareTitle: String {
        guard let revenue = item.revenue else { return "\(share)% записей" }
        return "\(share)% записей · \(rubText(revenue))"
    }

    private var ratio: CGFloat {
        guard maxCount > 0 else { return 0 }
        return CGFloat(item.count) / CGFloat(maxCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: DS.s8) {
                Text("\(index)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textMuted)
                    .frame(width: 16, alignment: .leading)
                Text(item.name)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: DS.s8)
                Text("\(item.count)")
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
            }
            bar
            Text(shareTitle)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.backgroundInput)
                Capsule()
                    .fill(theme.gradientPrimary)
                    .frame(width: geo.size.width * ratio, height: 6)
            }
        }
        .frame(height: 6)
        .animation(DS.springSmooth, value: grown)
        .onAppear { grown = true }
    }
}

// MARK: - Строка расхода

struct STExpenseRow: View {
    let expense: Expense
    let action: () -> Void

    @Environment(\.theme) private var theme

    private var title: String {
        let trimmed: String = expense.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? expense.category : trimmed
    }

    private var dateTitle: String {
        guard let date: Date = STFormat.date(fromKey: expense.date) else {
            return String(expense.date.prefix(10))
        }
        return STFormat.dayWithMonth(date)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.s12) {
                ZStack {
                    Circle()
                        .fill(theme.backgroundInput)
                        .frame(width: 36, height: 36)
                    Image(systemName: STExpenseKind.icon(for: expense.category))
                        .font(.system(size: 14))
                        .foregroundColor(theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text("\(expense.category) · \(dateTitle)")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: DS.s8)
                Text("−\(rubText(expense.amount))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.statusRed)
            }
            .padding(.vertical, DS.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.99))
    }
}

// MARK: - Добавление расхода

struct STExpenseSheet: View {
    @ObservedObject var vm: StatsViewModel

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool

    @State private var kind: STExpenseKind = .materials
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var isInvalid: Bool = false
    @State private var shakePhase: CGFloat = 0

    private var amountValue: Int { return Int(amountText) ?? 0 }

    private var dateTitle: String {
        guard let date: Date = STFormat.date(fromKey: vm.defaultExpenseDateKey) else {
            return vm.defaultExpenseDateKey
        }
        return STFormat.dayWithMonth(date)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DS.s20) {
                    amountField
                    categories
                    noteField
                    dateRow
                    if let message = vm.expenseError {
                        BBErrorBanner(message: message)
                    }
                    submitButton
                }
                .padding(.horizontal, DS.s20)
                .padding(.bottom, DS.s32)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.backgroundDeep)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .onAppear { vm.expenseError = nil }
        .task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            amountFocused = true
        }
    }

    // MARK: Шапка

    private var header: some View {
        HStack {
            Text("Новый расход")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(theme.backgroundInput, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(CLPressStyle(scale: 0.9))
        }
        .padding(.horizontal, DS.s20)
        .padding(.top, DS.s16)
        .padding(.bottom, DS.s8)
    }

    // MARK: Сумма

    private var amountField: some View {
        VStack(alignment: .leading, spacing: DS.s8) {
            Text("СУММА")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: DS.s8) {
                TextField("0", text: $amountText)
                    .keyboardType(.numberPad)
                    .focused($amountFocused)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .onChange(of: amountText) { _, newValue in
                        amountText = sanitize(newValue)
                        isInvalid = false
                    }
                Text("₽")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, DS.s16)
            .padding(.vertical, DS.s12)
            .offset(x: shakeOffset)
            .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: DS.r16))
            .overlay(
                RoundedRectangle(cornerRadius: DS.r16)
                    .stroke(isInvalid ? theme.statusRed : theme.borderSubtle, lineWidth: 1)
            )
        }
    }

    /// Только цифры и не больше 7 знаков
    private func sanitize(_ raw: String) -> String {
        let digits: String = raw.filter { $0.isASCII && $0.isNumber }
        return String(digits.prefix(7))
    }

    private var shakeOffset: CGFloat {
        guard shakePhase > 0 else { return 0 }
        return sin(shakePhase * .pi * 3) * 9
    }

    // MARK: Категория

    private var categories: some View {
        VStack(alignment: .leading, spacing: DS.s8) {
            Text("КАТЕГОРИЯ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textMuted)
            LazyVGrid(columns: pillColumns, spacing: DS.s8) {
                ForEach(STExpenseKind.allCases, id: \.rawValue) { item in
                    pill(for: item)
                }
            }
        }
    }

    private var pillColumns: [GridItem] {
        return [
            GridItem(.flexible(), spacing: DS.s8),
            GridItem(.flexible(), spacing: DS.s8),
            GridItem(.flexible(), spacing: DS.s8)
        ]
    }

    private func pill(for item: STExpenseKind) -> some View {
        let isSelected: Bool = kind == item
        let style: AnyShapeStyle = isSelected
            ? AnyShapeStyle(theme.gradientPrimary)
            : AnyShapeStyle(theme.backgroundInput)
        return Button {
            HapticManager.selection()
            withAnimation(DS.springSnappy) { kind = item }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 12))
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(style, in: RoundedRectangle(cornerRadius: DS.r12))
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.96))
    }

    // MARK: Комментарий и дата

    private var noteField: some View {
        VStack(alignment: .leading, spacing: DS.s8) {
            Text("НА ЧТО")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textMuted)
            TextField("Например, гель-лаки", text: $note)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, DS.s16)
                .frame(height: 48)
                .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: DS.r12))
        }
    }

    private var dateRow: some View {
        HStack(spacing: DS.s8) {
            Text("Дата")
                .font(DS.body)
                .foregroundColor(theme.textSecondary)
            Spacer(minLength: DS.s8)
            Text(dateTitle)
                .font(DS.label)
                .foregroundColor(theme.textPrimary)
        }
    }

    // MARK: Сохранение

    private var submitButton: some View {
        return BBPrimaryButton(
            title: "Добавить расход",
            isLoading: vm.isAddingExpense,
            isDisabled: vm.isAddingExpense
        ) {
            save()
        }
    }

    private func save() {
        guard amountValue > 0 else {
            withAnimation(DS.springMicro) { isInvalid = true }
            HapticManager.error()
            withAnimation(.linear(duration: 0.4)) { shakePhase = shakePhase < 1 ? 1 : 0.001 }
            return
        }
        let noteText: String = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let saved: Bool = await vm.addExpense(
                kind: kind.rawValue,
                amount: amountValue,
                note: noteText,
                dateKey: vm.defaultExpenseDateKey
            )
            if saved {
                HapticManager.success()
                dismiss()
            }
        }
    }
}
// MARK: - Экран «Статистика»

struct StatsView: View {
    @StateObject private var vm: StatsViewModel = StatsViewModel()

    @Environment(\.theme) private var theme
    @State private var expenseToDelete: Expense? = nil

    var body: some View {
        Color.clear
            .overlay {
                if vm.isLoading && !vm.hasLoadedOnce {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                } else {
                    content
                }
            }
            .task {
                if !vm.hasLoadedOnce { await vm.load() }
            }
            .sheet(isPresented: $vm.showExpenseSheet) {
                STExpenseSheet(vm: vm).environment(\.theme, theme)
            }
            .confirmationDialog(
                "Удалить расход?",
                isPresented: deleteDialogBinding,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) { confirmDelete() }
                Button("Отмена", role: .cancel) { expenseToDelete = nil }
            }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.s16) {
                header
                    .stReveal(0)
                STSegment(period: vm.period, onPick: vm.setPeriod)
                STPeriodNav(
                    title: vm.periodLabel,
                    canGoBack: vm.canGoBack,
                    canGoForward: vm.canGoForward,
                    onShift: vm.shiftPeriod
                )
                STHeroCard(
                    earned: vm.earned,
                    delta: vm.deltaPercent,
                    comparisonTitle: vm.comparisonLabel,
                    net: vm.net,
                    planned: vm.planned
                )
                .stReveal(1)
                STBarChart(vm: vm)
                    .stReveal(2)
                kpiGrid
                    .stReveal(3)
                awayHint
                topSection
                expensesSection
            }
            .padding(.horizontal, DS.s20)
            .padding(.top, DS.s8)
            .padding(.bottom, 120)
        }
        .refreshable { await vm.load() }
        .opacity(vm.isStale ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.2), value: vm.isStale)
    }

    // MARK: Шапка

    private var header: some View {
        HStack(alignment: .top, spacing: DS.s8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Твои деньги и клиенты")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent)
                Text("Статистика")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
            }
            Spacer(minLength: DS.s8)
            HeaderBellButton()
        }
    }

    // MARK: Плитки

    private var kpiGrid: some View {
        LazyVGrid(columns: tileColumns, spacing: DS.s12) {
            STKpiTile(title: "Записей", value: "\(vm.appointments)", hint: vm.appointmentsHint)
            STKpiTile(title: "Клиентов", value: "\(vm.clientsCount)", hint: vm.clientsHint)
            STKpiTile(title: "Средний чек", value: rubText(vm.avgCheck), hint: "за визит")
            STKpiTile(title: "Расходы", value: rubText(vm.expensesTotal), hint: expensesHint)
        }
    }

    private var tileColumns: [GridItem] {
        return [
            GridItem(.flexible(), spacing: DS.s12),
            GridItem(.flexible(), spacing: DS.s12)
        ]
    }

    private var expensesHint: String {
        return "\(vm.expensesSharePercent)% от выручки"
    }

    // MARK: Подсказка

    @ViewBuilder
    private var awayHint: some View {
        if vm.awayCount > 0 {
            STAwayHint(count: vm.awayCount, action: vm.openAwayClients)
                .stReveal(4)
        }
    }

    // MARK: Популярные услуги

    @ViewBuilder
    private var topSection: some View {
        if !vm.topItems.isEmpty {
            VStack(alignment: .leading, spacing: DS.s12) {
                STSectionTitle(title: "Популярное")
                VStack(alignment: .leading, spacing: DS.s16) {
                    ForEach(Array(vm.topItems.enumerated()), id: \.element.id) { entry in
                        STTopRow(
                            index: entry.offset + 1,
                            item: entry.element,
                            share: vm.topShare(entry.element),
                            maxCount: vm.topItems.first?.count ?? 0
                        )
                    }
                }
            }
            .stReveal(5)
        }
    }

    // MARK: Расходы

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            HStack(spacing: DS.s8) {
                Text("Расходы · \(vm.expensesTitle)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: DS.s8)
                addButton
            }
            expenseCard
        }
        .stReveal(6)
    }

    private var addButton: some View {
        return Button {
            HapticManager.light()
            vm.showExpenseSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("Добавить")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(theme.accent)
            .frame(height: 44)
            .padding(.horizontal, DS.s8)
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.94))
    }

    @ViewBuilder
    private var expenseCard: some View {
        if vm.periodExpenses.isEmpty {
            emptyExpenses
        } else {
            VStack(spacing: 0) {
                ForEach(Array(vm.periodExpenses.enumerated()), id: \.element.id) { entry in
                    STExpenseRow(expense: entry.element) { expenseToDelete = entry.element }
                    if entry.offset < vm.periodExpenses.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(.horizontal, DS.s16)
            .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: DS.r20))
            .overlay(RoundedRectangle(cornerRadius: DS.r20).stroke(theme.borderSubtle, lineWidth: 1))
        }
    }

    private var emptyExpenses: some View {
        VStack(spacing: DS.s12) {
            Text("В этом периоде расходов нет")
                .font(DS.body)
                .foregroundColor(theme.textMuted)
            Button {
                HapticManager.light()
                vm.showExpenseSheet = true
            } label: {
                Text("Добавить расход")
                    .font(DS.label)
                    .foregroundColor(theme.accent)
                    .frame(height: 44)
                    .padding(.horizontal, DS.s12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(CLPressStyle(scale: 0.96))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.s20)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: DS.r20))
        .overlay(RoundedRectangle(cornerRadius: DS.r20).stroke(theme.borderSubtle, lineWidth: 1))
    }

    // MARK: Удаление расхода

    private var deleteDialogBinding: Binding<Bool> {
        return Binding(
            get: { expenseToDelete != nil },
            set: { isOpen in
                if !isOpen { expenseToDelete = nil }
            }
        )
    }

    private func confirmDelete() {
        guard let target: Expense = expenseToDelete else { return }
        expenseToDelete = nil
        Task {
            let removed: Bool = await vm.deleteExpense(id: target.id)
            if removed {
                HapticManager.success()
            } else {
                HapticManager.error()
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
    StatsView()
        .environment(\.theme, .pink)
        .environmentObject(NotificationsViewModel())
}