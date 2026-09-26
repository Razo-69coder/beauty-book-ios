import SwiftUI
import Contacts

// MARK: - Contacts Importer

struct ContactImporter {
    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    static func fetchContacts() async -> [(name: String, phone: String)] {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        var contacts: [(name: String, phone: String)] = []

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                for phoneNumber in contact.phoneNumbers {
                    let phone = phoneNumber.value.stringValue
                    if !name.isEmpty && !phone.isEmpty {
                        contacts.append((name: name, phone: phone))
                    }
                }
            }
        } catch {
            print("Error fetching contacts: \(error)")
        }

        return contacts
    }
}

// MARK: - Contacts Picker Sheet

struct ContactsPickerSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var contacts: [(name: String, phone: String)] = []
    @State private var isLoading = true
    @State private var hasAccess = false
    @State private var searchText = ""

    let onSelect: (String, String) -> Void

    private var filteredContacts: [(name: String, phone: String)] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.contains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                        Text("Загрузка контактов...")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                    }
                } else if !hasAccess {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(theme.textMuted)
                        Text("Доступ к контактам запрещён")
                            .font(DS.headline)
                            .foregroundColor(theme.textPrimary)
                        Text("Разрешите доступ в Настройки → Конфиденциальность → Контакты")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else if contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(theme.textMuted)
                        Text("Контакты не найдены")
                            .font(DS.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(theme.textMuted)
                            TextField("Поиск", text: $searchText)
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                        }
                        .padding(12)
                        .background(theme.backgroundInput)
                        .cornerRadius(DS.r12)
                        .padding(20)

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(filteredContacts.enumerated()), id: \.offset) { _, contact in
                                    Button {
                                        onSelect(contact.name, contact.phone)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(theme.gradientPrimary)
                                                    .frame(width: 40, height: 40)
                                                Text(contact.name.prefix(1).uppercased())
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(contact.name)
                                                    .font(DS.body)
                                                    .foregroundColor(theme.textPrimary)
                                                Text(contact.phone)
                                                    .font(DS.bodySmall)
                                                    .foregroundColor(theme.textMuted)
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle")
                                                .foregroundColor(theme.accent)
                                        }
                                        .padding(12)
                                        .background(theme.backgroundCard)
                                        .cornerRadius(DS.r12)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .navigationTitle("Импорт из контактов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
        }
        .task {
            hasAccess = await ContactImporter.requestAccess()
            if hasAccess {
                contacts = await ContactImporter.fetchContacts()
            }
            isLoading = false
        }
    }
}

// MARK: - Фильтры списка клиентов

enum CLClientFilter: String, CaseIterable {
    case all
    case away
    case soon
    case birthday
    case new

    var title: String {
        switch self {
        case .all:      return "Все"
        case .away:     return "Давно не были"
        case .soon:     return "Скоро скидка"
        case .birthday: return "День рождения"
        case .new:      return "Новые"
        }
    }

    /// Подсказка для пустого состояния по фильтру
    var emptyText: String {
        switch self {
        case .all:      return "Список клиентов пуст."
        case .away:     return "Все клиенты приходили за последние 5 недель."
        case .soon:     return "Ни у кого нет скидки на ближайших визитах."
        case .birthday: return "В ближайшие 2 недели дней рождения нет."
        case .new:      return "Новых клиентов пока нет."
        }
    }
}

// MARK: - Даты и склонения для списка

private enum CLListFormat {
    static let monthsShort: [String] = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]

    /// «2026-04-20» → Date (по первым 10 символам)
    static func isoDay(_ raw: String?) -> Date? {
        guard let raw = raw else { return nil }
        let trimmed: String = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 10 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: String(trimmed.prefix(10)))
    }

    /// «12 сен»
    static func shortDay(_ date: Date) -> String {
        let month: Int = Calendar.current.component(.month, from: date) - 1
        guard month >= 0 && month < monthsShort.count else { return "" }
        let day: Int = Calendar.current.component(.day, from: date)
        return "\(day) \(monthsShort[month])"
    }

    /// Скидка мастера: «10%» или «500 ₽»
    static func discountLabel(_ me: MasterProfile) -> String {
        if me.loyaltyDiscountType == "rub" {
            let rub: Int = me.loyaltyDiscountRub ?? 0
            return rub > 0 ? rubText(rub) : "скидка"
        }
        let percent: Int = me.loyaltyDiscountPercent ?? 0
        return percent > 0 ? "\(percent)%" : "скидка"
    }
}

// MARK: - Расчёты по клиентке

fileprivate extension Client {
    var clVisits: Int { appointmentsCount ?? 0 }

    var clLastVisitDate: Date? { CLListFormat.isoDay(lastVisit) }

    /// Сколько дней прошло с последнего визита (nil — визитов не было)
    var clDaysAway: Int? {
        guard let date: Date = clLastVisitDate else { return nil }
        let calendar = Calendar.current
        let from: Date = calendar.startOfDay(for: date)
        let to: Date = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: from, to: to).day
    }

    /// Через сколько дней день рождения (nil — не указан)
    var clBirthdayIn: Int? {
        guard let raw: String = birthday else { return nil }
        let trimmed: String = raw.trimmingCharacters(in: .whitespaces)
        let parts: [Substring] = trimmed.split(separator: "-")
        guard parts.count == 2,
              let month: Int = Int(parts[0]),
              let day: Int = Int(parts[1]),
              month >= 1, month <= 12, day >= 1, day <= 31 else { return nil }

        let calendar = Calendar.current
        let today: Date = calendar.startOfDay(for: Date())
        let year: Int = calendar.component(.year, from: today)

        for candidateYear in [year, year + 1] {
            var components = DateComponents()
            components.year = candidateYear
            components.month = month
            components.day = day
            // 29 февраля в невисокопосный год отмечаем 1 марта
            let isLeap: Bool = (candidateYear % 4 == 0 && candidateYear % 100 != 0) || candidateYear % 400 == 0
            if month == 2 && day == 29 && !isLeap {
                components.month = 3
                components.day = 1
            }
            guard let target: Date = calendar.date(from: components) else { continue }
            let days: Int = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: target)).day ?? 0
            if days >= 0 { return days }
        }
        return nil
    }
}

// MARK: - Clients View Model

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var isLoading = false
    @Published var hasLoadedOnce = false
    @Published var searchText = ""
    @Published var filter: CLClientFilter = .all
    @Published var showAddSheet = false
    @Published var prefillName = ""
    @Published var prefillPhone = ""
    @Published var loyaltyEnabled = false
    @Published var loyaltyThreshold = 10
    @Published var discountLabel = "10%"
    @Published var scrollTargetId: Int? = nil
    @Published var highlightId: Int? = nil

    var name: String {
        get { prefillName }
        set { prefillName = newValue }
    }

    var phone: String {
        get { prefillPhone }
        set { prefillPhone = newValue }
    }

    private let api = APIClient.shared

    // MARK: Список и поиск

    /// Клиенты, подходящие под фильтр и поисковый запрос
    var filteredClients: [Client] {
        clients.filter { client in
            passesFilter(client) && matchesSearch(client)
        }
    }

    func count(for filter: CLClientFilter) -> Int {
        clients.filter { passesFilter($0, filter: filter) }.count
    }

    /// Поиск: по имени без учёта регистра или по цифрам телефона
    private func matchesSearch(_ client: Client) -> Bool {
        let query: String = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return true }
        if client.name.lowercased().contains(query) { return true }
        let queryDigits: String = query.filter { $0.isNumber }
        guard !queryDigits.isEmpty else { return false }
        let phoneDigits: String = client.phone.filter { $0.isNumber }
        return !phoneDigits.isEmpty && phoneDigits.contains(queryDigits)
    }

    private func passesFilter(_ client: Client, filter: CLClientFilter? = nil) -> Bool {
        let active: CLClientFilter = filter ?? self.filter
        switch active {
        case .all:
            return true
        case .away:
            guard let days: Int = client.clDaysAway else { return false }
            return days > 35
        case .soon:
            return isSoonDiscount(client)
        case .birthday:
            guard let days: Int = client.clBirthdayIn else { return false }
            return days <= 14
        case .new:
            return client.clVisits == 0
        }
    }

    /// Скидка будет на следующем визите
    func isNextDiscount(_ client: Client) -> Bool {
        guard loyaltyEnabled, loyaltyThreshold > 0 else { return false }
        return (client.clVisits + 1) % loyaltyThreshold == 0
    }

    /// Скидка на ближайших визитах (сейчас или через один)
    private func isSoonDiscount(_ client: Client) -> Bool {
        guard loyaltyEnabled, loyaltyThreshold > 0 else { return false }
        let visits: Int = client.clVisits
        guard visits > 0 else { return false }
        let nextIsDiscount: Bool = (visits + 1) % loyaltyThreshold == 0
        return nextIsDiscount || (visits + 2) % loyaltyThreshold == 0
    }

    // MARK: Загрузка

    func load() async {
        if clients.isEmpty { isLoading = true }
        let api = self.api

        // Профиль мастера нужен для скидок — грузим параллельно со списком
        async let profileTask: MasterProfile? = try? await api.request(.me, as: MasterProfile.self)

        var collected: [Client] = []
        var seenIds: Set<Int> = []
        var page: Int = 0

        while page < 30 {
            guard let resp: ClientsResponse = try? await api.request(.clients(page: page, search: ""), as: ClientsResponse.self) else { break }
            var added: Int = 0
            for client in resp.clients {
                if seenIds.insert(client.id).inserted {
                    collected.append(client)
                    added += 1
                }
            }
            if resp.clients.isEmpty || added == 0 { break }
            if collected.count >= resp.total { break }
            page += 1
        }

        if !collected.isEmpty { clients = collected }

        if let me: MasterProfile = await profileTask {
            loyaltyEnabled = me.loyaltyDiscountEnabled ?? false
            if let threshold: Int = me.loyaltyThreshold, threshold > 0 {
                loyaltyThreshold = threshold
            } else {
                loyaltyThreshold = 10
            }
            discountLabel = CLListFormat.discountLabel(me)
        }

        if filter == .soon && !loyaltyEnabled { filter = .all }
        isLoading = false
        hasLoadedOnce = true
    }

    func delete(client: Client) async {
        clients.removeAll { $0.id == client.id }
        do { let _ = try await api.request(.deleteClient(id: client.id), as: MessageResponse.self) }
        catch { clients.append(client) }
    }

    /// Добавляет клиента. Возвращает false, если сервер ответил ошибкой.
    @discardableResult
    func add(name: String, phone: String, notes: String, birthday: String, source: String, allergies: String) async -> Bool {
        // birthday в ClientCreateRequest не входит — бэкенд принимает без него
        _ = birthday
        do {
            let request = ClientCreateRequest(
                name: name,
                phone: phone,
                notes: notes,
                source: source,
                allergies: allergies
            )
            let _ = try await api.request(.createClient(request), as: MessageResponse.self)
            await load()
            resetFilters()
            if let newId: Int = findNewClientId(name: name, phone: phone) {
                scrollTargetId = newId
                highlightId = newId
            }
            return true
        } catch {
            return false
        }
    }

    private func resetFilters() {
        filter = .all
        searchText = ""
    }

    /// Ищем новую клиентку по телефону, иначе по имени
    private func findNewClientId(name: String, phone: String) -> Int? {
        let digits: String = phone.filter { $0.isNumber }
        if !digits.isEmpty {
            let match: Client? = clients.first { client in
                let phoneDigits: String = client.phone.filter { $0.isNumber }
                return !phoneDigits.isEmpty && phoneDigits.hasSuffix(digits)
            }
            if let match = match { return match.id }
        }
        let target: String = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !target.isEmpty else { return nil }
        let match: Client? = clients.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
        return match?.id
    }
}

// MARK: - Client: Hashable (только по id)

extension Client: Hashable {
    static func == (lhs: Client, rhs: Client) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Общие мелкие view для экрана клиентов

/// Сжатие при нажатии с реакцией сразу при касании
struct CLPressStyle: ButtonStyle {
    var scale: CGFloat = 0.98
    var releaseAnimation: Animation = DS.springSnappy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(
                configuration.isPressed ? DS.springMicro : releaseAnimation,
                value: configuration.isPressed
            )
    }
}

/// Аватар с инициалами и синей точкой Telegram
struct CLAvatar: View {
    let name: String
    let size: CGFloat
    let dotSize: CGFloat
    let hasTelegram: Bool
    let theme: AppTheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(theme.gradientPrimary)
                .frame(width: size, height: size)

            Text(clInitials(name))
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundColor(.white)

            if hasTelegram {
                Circle()
                    .fill(Color(hex: "#2AABEE"))
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle().stroke(theme.backgroundCard, lineWidth: 2)
                    )
                    .offset(x: 1, y: 1)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Капсула-метка: цвет текста совпадает с цветом, фон — тот же цвет с прозрачностью
struct CLTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// Кольцо лояльности: сколько визитов из порога уже сделано
struct CLRing: View {
    let visits: Int
    let threshold: Int
    let enabled: Bool
    let theme: AppTheme

    private var progress: CGFloat {
        guard enabled, threshold > 0 else { return 0 }
        return CGFloat(visits % threshold) / CGFloat(threshold)
    }

    var body: some View {
        ZStack {
            if enabled {
                Circle()
                    .stroke(theme.borderSubtle, lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
            }
            Text("\(visits)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(theme.textPrimary)
        }
        .frame(width: 36, height: 36)
        .accessibilityLabel("\(visits) \(ruPlural(visits, "визит", "визита", "визитов"))")
    }
}

/// Чип-фильтр с числом подходящих клиенток
struct CLFilterChip: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : theme.textSecondary)
                        .frame(minWidth: 20)
                        .frame(height: 20)
                        .background(
                            Circle().fill(isSelected ? Color.white.opacity(0.25) : theme.backgroundInput)
                        )
                }
            }
            .foregroundColor(isSelected ? .white : theme.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundCard))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.clear : theme.borderSubtle, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(CLPressStyle(scale: 0.94))
    }
}

/// Появление строки: с задержкой по индексу или быстрым фейдом
struct CLStaggeredRow<Content: View>: View {
    let index: Int
    let stagger: Bool
    private let content: () -> Content

    init(index: Int, stagger: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.index = index
        self.stagger = stagger
        self.content = content
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: verticalOffset)
            .animation(animation, value: appeared)
            .onAppear {
                guard !appeared else { return }
                guard stagger && !reduceMotion else {
                    appeared = true
                    return
                }
                let delay: Double = min(Double(index) * 0.028, 0.34)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    appeared = true
                }
            }
    }

    private var verticalOffset: CGFloat {
        if appeared || reduceMotion { return 0 }
        return stagger ? 8 : 0
    }

    private var animation: Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        if stagger {
            return DS.springSmooth.delay(min(Double(index) * 0.028, 0.34))
        }
        return .easeOut(duration: 0.18)
    }
}

/// Строка клиентки в списке
struct CLRow: View {
    let client: Client
    let theme: AppTheme
    let loyaltyEnabled: Bool
    let loyaltyThreshold: Int
    let isHighlighted: Bool
    let isNextDiscount: Bool

    private var visits: Int { client.clVisits }
    private var daysAway: Int? { client.clDaysAway }
    private var birthdayIn: Int? { client.clBirthdayIn }

    var body: some View {
        HStack(spacing: 12) {
            CLAvatar(
                name: client.name,
                size: 46,
                dotSize: 12,
                hasTelegram: client.telegramId != nil,
                theme: theme
            )
            clientText
            Spacer(minLength: 6)
            CLRing(visits: visits, threshold: loyaltyThreshold, enabled: loyaltyEnabled, theme: theme)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 68)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isHighlighted ? theme.accent.opacity(0.12) : theme.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private var clientText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(subtitleText)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if let tag = tagInfo {
                    CLTag(text: tag.text, color: tag.color)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var subtitleText: String {
        guard let date: Date = client.clLastVisitDate else { return "Ещё не была" }
        return "Была " + CLListFormat.shortDay(date)
    }

    /// Метка по приоритету: день рождения → скидка → давно не была
    private var tagInfo: (text: String, color: Color)? {
        if let days: Int = birthdayIn, days <= 14 {
            if days == 0 { return ("ДР сегодня", theme.accent) }
            let word: String = ruPlural(days, "день", "дня", "дней")
            return ("ДР через \(days) \(word)", theme.accent)
        }
        if isNextDiscount && visits > 0 {
            return ("Скидка на след. визите", theme.statusGreen)
        }
        if let days: Int = daysAway, days > 35 {
            return ("\(days / 7) нед. не была", theme.statusYellow)
        }
        return nil
    }
}

// MARK: - Буква-разделитель в списке

struct CLLetterGroup: Identifiable {
    let letter: String
    let clients: [Client]

    var id: String { letter }
}

struct CLLetterHeader: View {
    let letter: String
    let theme: AppTheme

    var body: some View {
        Text(letter)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .padding(.horizontal, 4)
    }
}

// MARK: - Клиенты List View

struct ClientsListView: View {
    @StateObject private var vm = ClientsViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showImportContacts = false
    @State private var showImportCSV = false
    @State private var scrollResetToken: Int = 0
    @State private var didRevealList = false

    private let topAnchorId: String = "clTopAnchor"

    var body: some View {
        NavigationStack {
            rootContent
                .navigationTitle("Клиенты")
                .toolbar(.hidden, for: .navigationBar)
                .tint(theme.accent)
                .navigationDestination(for: Client.self) { client in
                    ClientDetailView(client: client, onDelete: {
                        Task { await vm.load() }
                    })
                    .environment(\.theme, theme)
                }
        }
        .onAppear {
            // Переход из «Статистики»: сразу показываем «Давно не были»
            if STPendingClientsFilter.away {
                STPendingClientsFilter.away = false
                vm.filter = .away
            }
        }
    }

    private var rootContent: some View {
        Color.clear
            .overlay { scrollContent }
            .overlay(alignment: .bottomTrailing) { fabButton }
            .task { await vm.load() }
            .task(id: vm.hasLoadedOnce) { await revealListOnce() }
            .sheet(isPresented: $vm.showAddSheet) {
                AddClientSheet(vm: vm).environment(\.theme, theme)
            }
            .sheet(isPresented: $showImportContacts) {
                ContactsPickerSheet { name, phone in
                    vm.name = name
                    vm.phone = phone
                    vm.showAddSheet = true
                }
                .environment(\.theme, theme)
            }
            .sheet(isPresented: $showImportCSV) {
                ImportClientsView()
                    .environment(\.theme, theme)
                    .onDisappear { Task { await vm.load() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClientUpdated"))) { _ in
                Task { await vm.load() }
            }
    }

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchorId)
                    headerSection
                    searchBar
                    filtersRow
                    listContent
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await vm.load() }
            .onChange(of: vm.scrollTargetId) { _, newId in
                guard let newId = newId else { return }
                withAnimation(DS.springSmooth) {
                    proxy.scrollTo(newId, anchor: .center)
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    vm.highlightId = nil
                }
                vm.scrollTargetId = nil
            }
            .onChange(of: scrollResetToken) { _, _ in
                withAnimation(reduceMotion ? nil : DS.springSnappy) {
                    proxy.scrollTo(topAnchorId, anchor: .top)
                }
            }
        }
    }

    private func revealListOnce() async {
        guard vm.hasLoadedOnce, !didRevealList, !vm.filteredClients.isEmpty else { return }
        try? await Task.sleep(nanoseconds: 700_000_000)
        didRevealList = true
    }

    // MARK: - Шапка

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(countText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent)
                Text("Клиенты")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                importMenu
                HeaderBellButton()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var countText: String {
        let total: Int = vm.clients.count
        return "\(total) \(ruPlural(total, "клиент", "клиента", "клиентов"))"
    }

    /// Одна кнопка импорта: контакты iPhone или CSV
    private var importMenu: some View {
        Menu {
            Button {
                showImportContacts = true
            } label: {
                Label("Из контактов iPhone", systemImage: "person.crop.circle")
            }
            Button {
                showImportCSV = true
            } label: {
                Label("Из файла CSV", systemImage: "doc.text")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(theme.backgroundCard)
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(theme.borderSubtle, lineWidth: 1)
                    .frame(width: 44, height: 44)
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            }
            .contentShape(Circle())
        }
        .accessibilityLabel("Импорт клиентов")
    }

    // MARK: - Поиск

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(theme.textMuted)
            TextField("Имя или телефон", text: $vm.searchText)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(theme.textMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(height: 52)
        .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Фильтры

    private var filtersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleFilters, id: \.self) { filter in
                    CLFilterChip(
                        title: filter.title,
                        count: filter == .all ? nil : vm.count(for: filter),
                        isSelected: vm.filter == filter,
                        theme: theme
                    ) {
                        selectFilter(filter)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var visibleFilters: [CLClientFilter] {
        CLClientFilter.allCases.filter { $0 != .soon || vm.loyaltyEnabled }
    }

    private func selectFilter(_ filter: CLClientFilter) {
        guard vm.filter != filter else { return }
        HapticManager.selection()
        withAnimation(reduceMotion ? nil : DS.springSnappy) {
            vm.filter = filter
        }
        scrollResetToken += 1
    }

    // MARK: - Список

    @ViewBuilder
    private var listContent: some View {
        if vm.isLoading && vm.clients.isEmpty {
            loadingState
        } else if vm.filteredClients.isEmpty {
            emptyState
        } else {
            clientsList
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
            Text("Загружаю клиентов...")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var clientsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(letterGroups.enumerated()), id: \.element.id) { groupIndex, group in
                CLLetterHeader(letter: group.letter, theme: theme)
                ForEach(Array(group.clients.enumerated()), id: \.element.id) { rowIndex, client in
                    rowView(client, index: groupIndex + rowIndex)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 140)
        .animation(reduceMotion ? .none : DS.springSnappy, value: vm.filter)
    }

    private func rowView(_ client: Client, index: Int) -> some View {
        NavigationLink(value: client) {
            CLRow(
                client: client,
                theme: theme,
                loyaltyEnabled: vm.loyaltyEnabled,
                loyaltyThreshold: vm.loyaltyThreshold,
                isHighlighted: vm.highlightId == client.id,
                isNextDiscount: vm.isNextDiscount(client)
            )
        }
        .buttonStyle(CardPressStyle())
        .simultaneousGesture(
            TapGesture().onEnded { HapticManager.selection() }
        )
        .padding(.bottom, 8)
        .modifier(CLStaggerModifier(index: index, stagger: !didRevealList))
    }

    /// Группы по первой букве имени, сортировка по алфавиту
    private var letterGroups: [CLLetterGroup] {
        let sorted: [Client] = vm.filteredClients.sorted { lhs, rhs in
            lhs.name.compare(rhs.name, options: [.caseInsensitive], locale: Locale(identifier: "ru_RU")) == .orderedAscending
        }
        var order: [String] = []
        var clientsByLetter: [String: [Client]] = [:]
        for client in sorted {
            let letter: String = String(client.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
            let key: String = letter.isEmpty ? "#" : letter
            if clientsByLetter[key] == nil {
                order.append(key)
            }
            clientsByLetter[key, default: []].append(client)
        }
        return order.map { CLLetterGroup(letter: $0, clients: clientsByLetter[$0] ?? []) }
    }

    // MARK: - Пустые состояния

    private var emptyState: some View {
        Group {
            if !trimmedQuery.isEmpty {
                searchEmptyState
            } else if vm.clients.isEmpty {
                noClientsState
            } else {
                filterEmptyState
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 140)
    }

    private var trimmedQuery: String {
        vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Text("Никого не нашли")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text("По запросу «\(trimmedQuery)» клиентов нет.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            BBPrimaryButton(title: "Добавить «\(trimmedQuery)»") {
                openAddSheetWithQuery(trimmedQuery)
            }
            .environment(\.theme, theme)
            .padding(.top, 6)
        }
    }

    private var noClientsState: some View {
        VStack(spacing: 10) {
            Text("Пока нет клиентов")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text("Добавь первую клиентку кнопкой + или перенеси всех из контактов iPhone.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            BBPrimaryButton(title: "Импорт из контактов") {
                showImportContacts = true
            }
            .environment(\.theme, theme)
            .padding(.top, 6)
        }
    }

    private var filterEmptyState: some View {
        VStack(spacing: 10) {
            Text("Здесь пока пусто")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(vm.filter.emptyText)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Если запрос состоит только из цифр и знаков телефона — подставляем его в поле телефона
    private func openAddSheetWithQuery(_ query: String) {
        let phoneChars: Set<Character> = ["+", "-", "(", ")", " "]
        let onlyPhone: Bool = query.contains(where: { $0.isNumber })
            && query.allSatisfy { $0.isNumber || phoneChars.contains($0) }
        if onlyPhone {
            vm.prefillName = ""
            vm.prefillPhone = query
        } else {
            vm.prefillName = query
            vm.prefillPhone = ""
        }
        vm.showAddSheet = true
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            HapticManager.medium()
            vm.showAddSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 60, height: 60)
                    .shadow(color: theme.accentGlow, radius: 12, x: 0, y: 6)
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(CLPressStyle(scale: 0.92, releaseAnimation: DS.springBouncy))
        .padding(.bottom, 100)
        .padding(.trailing, 20)
        .accessibilityLabel("Новый клиент")
    }
}

/// Появление строки по очереди при первой загрузке
private struct CLStaggerModifier: ViewModifier {
    let index: Int
    let stagger: Bool

    func body(content: Content) -> some View {
        CLStaggeredRow(index: index, stagger: stagger) { content }
    }
}

// MARK: - Сжатие при нажатии (общее для карточек приложения)

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DS.springSnappy, value: configuration.isPressed)
    }
}

// MARK: - Add Client Sheet

struct AddClientSheet: View {
    @ObservedObject var vm: ClientsViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var name = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var allergies = ""
    @State private var birthday = ""
    @State private var birthdayDate = Date()
    @State private var showBirthdayPicker = false
    @State private var source = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @State private var nameIsValid = true
    @State private var nameShake: CGFloat = 0

    private let sourceOptions: [String] = [
        "Сарафанное радио", "Авито", "ВКонтакте", "Instagram", "Telegram", "Другое"
    ]

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                Divider().background(theme.borderSubtle)
                ScrollView(showsIndicators: false) {
                    formContent
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .onAppear {
            name = vm.prefillName
            phone = vm.prefillPhone
        }
    }

    // MARK: Шапка шторки

    private var sheetHeader: some View {
        HStack {
            Text("Новый клиент")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(theme.backgroundInput, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(CLPressStyle(scale: 0.9))
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: Поля

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let errorMessage = errorMessage {
                BBErrorBanner(message: errorMessage)
                    .environment(\.theme, theme)
            }
            nameField
            phoneField
            birthdayField
            sourcePills
            notesField
            allergiesField
            saveButton
            hintText
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 40)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Имя")
            BBTextField(
                placeholder: "Например, Анна Петрова",
                text: $name,
                isValid: nameIsValid,
                contentType: .name
            )
            .environment(\.theme, theme)
            .modifier(CLShake(animatableData: nameShake))
            .onChange(of: name) { _, _ in
                // Красная рамка держится, пока пользователь не начал исправлять
                if !nameIsValid, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    nameIsValid = true
                    nameShake = 0
                }
            }
        }
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Телефон")
            BBTextField(
                placeholder: "+7 900 000-00-00",
                text: $phone,
                keyboardType: .phonePad,
                contentType: .telephoneNumber
            )
            .environment(\.theme, theme)
        }
    }

    private var birthdayField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("День рождения")
            HStack(spacing: 8) {
                Button {
                    withAnimation(DS.springSnappy) { showBirthdayPicker.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "gift")
                            .foregroundColor(birthday.isEmpty ? theme.textMuted : theme.accent)
                        Text(birthday.isEmpty ? "Необязательно" : formattedBirthday(birthday))
                            .font(DS.body)
                            .foregroundColor(birthday.isEmpty ? theme.textMuted : theme.textPrimary)
                        Spacer()
                        Image(systemName: showBirthdayPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: DS.r12))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.r12)
                            .stroke(theme.borderSubtle, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(CLPressStyle())

                if !birthday.isEmpty {
                    Button {
                        birthday = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 19))
                            .foregroundColor(theme.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Убрать день рождения")
                }
            }
            if showBirthdayPicker {
                DatePicker("", selection: $birthdayDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .tint(theme.accent)
                    .colorScheme(theme == .platinum ? .light : .dark)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .onChange(of: birthdayDate) { _, newDate in
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.dateFormat = "MM-dd"
                        birthday = formatter.string(from: newDate)
                        showBirthdayPicker = false
                    }
            }
        }
    }

    private var sourcePills: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Откуда пришла")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sourceOptions, id: \.self) { option in
                        sourcePill(option)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func sourcePill(_ option: String) -> some View {
        let isSelected: Bool = source == option
        return Button {
            HapticManager.selection()
            withAnimation(DS.springSnappy) {
                source = isSelected ? "" : option
            }
        } label: {
            Text(option)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : theme.borderSubtle, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(CLPressStyle(scale: 0.94))
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Заметка")
            BBTextField(placeholder: "Необязательно", text: $notes)
                .environment(\.theme, theme)
        }
    }

    private var allergiesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Аллергии и противопоказания")
            BBTextField(placeholder: "Необязательно", text: $allergies)
                .environment(\.theme, theme)
        }
    }

    private var saveButton: some View {
        BBPrimaryButton(title: "Добавить клиента", isLoading: isSaving) {
            save()
        }
        .environment(\.theme, theme)
        .padding(.top, 4)
    }

    private var hintText: some View {
        Text("Много клиентов? Кнопка импорта вверху списка перенесёт их из контактов iPhone.")
            .font(.system(size: 12.5))
            .foregroundColor(theme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(theme.textMuted)
    }

    private func formattedBirthday(_ bday: String) -> String {
        let parts: [Substring] = bday.split(separator: "-")
        guard parts.count == 2,
              let month: Int = Int(parts[0]),
              let day: Int = Int(parts[1]) else { return bday }
        let months: [String] = CLListFormat.monthsShort
        guard month >= 1 && month <= 12 else { return bday }
        return "\(day) \(months[month - 1])"
    }

    // MARK: Сохранение

    private func save() {
        let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            nameIsValid = false
            HapticManager.error()
            nameShake = 0
            // Тряска отключаем при Reduce Motion, красную рамку оставляем
            if !reduceMotion {
                withAnimation(.linear(duration: 0.4)) { nameShake = 1 }
            }
            return
        }

        isSaving = true
        errorMessage = nil
        let payload = (
            name: trimmedName,
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            birthday: birthday,
            source: source,
            allergies: allergies.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task {
            let success: Bool = await vm.add(
                name: payload.name,
                phone: payload.phone,
                notes: payload.notes,
                birthday: payload.birthday,
                source: payload.source,
                allergies: payload.allergies
            )
            isSaving = false
            if success {
                HapticManager.success()
                vm.prefillName = ""
                vm.prefillPhone = ""
                dismiss()
            } else {
                errorMessage = "Не получилось добавить клиента. Попробуй ещё раз."
            }
        }
    }
}

// MARK: - Тряска поля (ошибка ввода)

private struct CLShake: GeometryEffect {
    var amount: CGFloat = 9
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

#Preview {
    ClientsListView()
        .environment(\.theme, .pink)
        .environmentObject(NotificationsViewModel())
}
