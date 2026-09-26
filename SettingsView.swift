import SwiftUI
import UIKit
import UserNotifications

// MARK: - Что сохраняем

/// Вид настройки: у каждого свой запрос и своя отложенная задача.
enum SESaveKind: Hashable {
    case profile
    case schedule
    case loyalty
    case payout
    case timezone
}

/// Данные всплывающего тоста внизу экрана.
struct SEToastInfo: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

// MARK: - ViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    // Профиль
    @Published var masterName = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var specialization = ""

    // Рабочее время
    @Published var workStart = 9
    @Published var workEnd = 20
    @Published var slotDuration = 60
    @Published var reminderDays = 30
    @Published var timezoneOffset = 3

    // Реквизиты для перевода
    @Published var paymentCard = ""
    @Published var paymentPhone = ""
    @Published var paymentBanks = ""

    // Ссылка на запись
    @Published var bookingLinkSlug = ""
    @Published var bookingLinkInput = ""
    @Published var bookingLinkSaving = false
    @Published var bookingLinkSuccess = false
    @Published var bookingLinkError: String? = nil

    // Скидки: тот же UserDefaults, что и раньше
    @Published var loyaltyThreshold: Int {
        didSet { UserDefaults.standard.set(loyaltyThreshold, forKey: "loyalty_threshold") }
    }
    @Published var loyaltyDiscount: Int {
        didSet { UserDefaults.standard.set(loyaltyDiscount, forKey: "loyalty_discount") }
    }
    @Published var birthdayDiscountEnabled: Bool {
        didSet { UserDefaults.standard.set(birthdayDiscountEnabled, forKey: "birthday_discount_enabled") }
    }
    @Published var birthdayDiscount: Int {
        didSet { UserDefaults.standard.set(birthdayDiscount, forKey: "birthday_discount") }
    }
    @Published var loyaltyDiscountType: String {
        didSet { UserDefaults.standard.set(loyaltyDiscountType, forKey: "loyalty_discount_type") }
    }
    @Published var loyaltyDiscountRub: Int {
        didSet { UserDefaults.standard.set(loyaltyDiscountRub, forKey: "loyalty_discount_rub") }
    }
    @Published var loyaltyEnabled = true

    // Напоминания: тот же UserDefaults, что и раньше
    @Published var remindersEnabled: Bool {
        didSet { UserDefaults.standard.set(remindersEnabled, forKey: "reminders_enabled") }
    }
    @Published var paymentReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(paymentReminderEnabled, forKey: "payment_reminder_enabled") }
    }
    @Published var returnReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(returnReminderEnabled, forKey: "return_reminder_enabled") }
    }
    @Published var returnReminderDays: Int {
        didSet { UserDefaults.standard.set(returnReminderDays, forKey: "return_reminder_days") }
    }

    @Published var isTelegramConnected = false
    @Published var errorMessage: String? = nil
    @Published var toast: SEToastInfo? = nil

    private let api = APIClient.shared
    /// Пока load() не закончился, автосохранение не запускаем.
    private var didLoad = false
    /// Отложенные задачи сохранения по видам настроек.
    private var saveTasks: [SESaveKind: Task<Void, Never>] = [:]
    private var toastTask: Task<Void, Never>? = nil

    init() {
        loyaltyThreshold = UserDefaults.standard.integer(forKey: "loyalty_threshold") == 0 ? 10 : UserDefaults.standard.integer(forKey: "loyalty_threshold")
        loyaltyDiscount = UserDefaults.standard.integer(forKey: "loyalty_discount") == 0 ? 10 : UserDefaults.standard.integer(forKey: "loyalty_discount")
        birthdayDiscountEnabled = UserDefaults.standard.object(forKey: "birthday_discount_enabled") as? Bool ?? true
        birthdayDiscount = UserDefaults.standard.integer(forKey: "birthday_discount") == 0 ? 10 : UserDefaults.standard.integer(forKey: "birthday_discount")

        loyaltyDiscountType = UserDefaults.standard.string(forKey: "loyalty_discount_type") ?? "percent"
        loyaltyDiscountRub = UserDefaults.standard.integer(forKey: "loyalty_discount_rub") == 0 ? 300 : UserDefaults.standard.integer(forKey: "loyalty_discount_rub")

        remindersEnabled = UserDefaults.standard.object(forKey: "reminders_enabled") as? Bool ?? true
        paymentReminderEnabled = UserDefaults.standard.object(forKey: "payment_reminder_enabled") as? Bool ?? true
        returnReminderEnabled = UserDefaults.standard.object(forKey: "return_reminder_enabled") as? Bool ?? true
        returnReminderDays = UserDefaults.standard.integer(forKey: "return_reminder_days") == 0 ? 21 : UserDefaults.standard.integer(forKey: "return_reminder_days")
    }

    // MARK: Тексты для строк

    var masterInitials: String {
        let parts = masterName.split(separator: " ")
        var result = ""
        if let first = parts.first {
            result = String(first.prefix(1))
        }
        if parts.count > 1, let second = parts.dropFirst().first {
            result += String(second.prefix(1))
        }
        return result.isEmpty ? "?" : result.uppercased()
    }

    /// Полная рабочая ссылка — её копируем и отдаём в «Поделиться».
    var bookingLink: String {
        bookingLinkSlug.isEmpty ? "" : "https://beauty-bot-44ou.onrender.com/book/\(bookingLinkSlug)"
    }

    /// Ссылка для отмены и переноса.
    var manageLink: String {
        bookingLinkSlug.isEmpty ? "" : "https://solvobeauty.vercel.app/my/\(bookingLinkSlug)"
    }

    /// Ссылки для показа на экране — без «https://».
    var bookingLinkShort: String { SEFormat.withoutScheme(bookingLink) }
    var manageLinkShort: String { SEFormat.withoutScheme(manageLink) }

    var hoursText: String { "\(workStart):00–\(workEnd):00" }

    var profileSubtitle: String {
        let parts = [specialization, phone].filter { !$0.isEmpty }
        return parts.isEmpty ? "Мастер" : parts.joined(separator: " · ")
    }

    var loyaltySummary: String {
        guard loyaltyEnabled else { return "выключены" }
        let size = loyaltyDiscountType == "rub" ? "\(rubText(loyaltyDiscountRub)) ₽" : "\(loyaltyDiscount)%"
        return "каждый \(loyaltyThreshold)-й · \(size)"
    }

    var remindersSummary: String {
        let on = [remindersEnabled, paymentReminderEnabled, returnReminderEnabled].filter { $0 }.count
        return on > 0 ? "\(on) из 3 включены" : "выключены"
    }

    var payoutFilled: Bool { !paymentCard.isEmpty || !paymentPhone.isEmpty }
    var payoutSummary: String { payoutFilled ? "заполнены" : "не заполнены" }

    var versionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return "Solvo Beauty \(v) · сделано с заботой о мастерах"
    }

    var bankList: [String] {
        paymentBanks
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Переключение банка в мультивыборе: известные банки идут по списку, свои — в конце строки.
    func toggleBank(_ bank: String) {
        var known = SEBanks.all
        let custom = bankList.filter { !SEBanks.all.contains($0) }
        if known.contains(bank) {
            if let index = known.firstIndex(of: bank) {
                known.remove(at: index)
            } else {
                known.append(bank)
            }
        }
        paymentBanks = (known + custom).joined(separator: ", ")
    }

    // MARK: Загрузка

    func load() async {
        if let m = try? await api.request(.me, as: MasterProfile.self) {
            masterName = m.name ?? ""
            email = m.email ?? ""
            phone = m.phone ?? ""
            specialization = m.specialization ?? ""
            workStart = m.workStart
            workEnd = m.workEnd
            slotDuration = m.slotDuration
            reminderDays = m.reminderDays
            paymentCard = m.paymentCard ?? ""
            paymentPhone = m.paymentPhone ?? ""
            paymentBanks = m.paymentBanks ?? ""
            isTelegramConnected = (m.telegramId ?? 0) > 0
            if let t = m.loyaltyThreshold, t > 0 { loyaltyThreshold = t }
            if let d = m.loyaltyDiscountPercent, d > 0 { loyaltyDiscount = d }
            if let e = m.birthdayDiscountEnabled { birthdayDiscountEnabled = e }
            if let d = m.birthdayDiscountPercent, d > 0 { birthdayDiscount = d }
            if let t = m.loyaltyDiscountType { loyaltyDiscountType = t }
            if let r = m.loyaltyDiscountRub, r > 0 { loyaltyDiscountRub = r }
            loyaltyEnabled = m.loyaltyDiscountEnabled ?? true
            timezoneOffset = m.timezoneOffset ?? 3
        } else {
            masterName = ""
            email = ""
            phone = ""
            specialization = ""
            workStart = 10
            workEnd = 20
            slotDuration = 60
            reminderDays = 40
            paymentCard = ""
            paymentPhone = ""
            paymentBanks = ""
        }
        if let r = try? await api.request(.getBookingLink, as: BookingLinkResponse.self) {
            bookingLinkSlug = r.bookingLink
            bookingLinkInput = r.bookingLink
        }
        didLoad = true
    }

    // MARK: Автосохранение

    /// Откладывает сохранение на 0.8 с и отменяет предыдущее такого же вида.
    func scheduleSave(_ kind: SESaveKind) {
        guard didLoad else { return }
        saveTasks[kind]?.cancel()
        let task = Task<Void, Never> { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 800_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            await self.runSave(kind)
        }
        saveTasks[kind] = task
    }

    private func runSave(_ kind: SESaveKind) async {
        switch kind {
        case .profile:  await saveProfile()
        case .schedule: await saveSchedule()
        case .loyalty:  await saveLoyaltySettings()
        case .payout:   await savePayout()
        case .timezone: await saveTimezone()
        }
    }

    /// Только расписание и специализация.
    func saveSchedule() async {
        let req = MasterSettingsRequest(
            name: masterName,
            workStart: workStart,
            workEnd: workEnd,
            slotDuration: slotDuration,
            reminderDays: reminderDays,
            timezone: "Europe/Moscow",
            specialization: specialization
        )
        do {
            let _ = try await api.request(.updateSettings(req), as: MessageResponse.self)
            reportSuccess()
        } catch {
            reportFailure()
        }
    }

    /// Только реквизиты для перевода.
    func savePayout() async {
        let req = PaymentRequest(
            paymentCard: paymentCard,
            paymentPhone: paymentPhone,
            paymentBanks: paymentBanks
        )
        do {
            let _ = try await api.request(.updatePayment(req), as: MessageResponse.self)
            reportSuccess()
        } catch {
            reportFailure()
        }
    }

    func saveProfile() async {
        let req = ProfileUpdateRequest(name: masterName, email: email, phone: phone)
        do {
            let _ = try await api.request(.updateProfile(req), as: MessageResponse.self)
            reportSuccess()
        } catch {
            reportFailure()
        }
    }

    func saveLoyaltySettings() async {
        let req = LoyaltySettingsRequest(
            loyaltyEnabled: loyaltyEnabled,
            loyaltyThreshold: loyaltyThreshold,
            loyaltyDiscountPercent: loyaltyDiscount,
            birthdayEnabled: birthdayDiscountEnabled,
            birthdayDiscountPercent: birthdayDiscount,
            loyaltyDiscountType: loyaltyDiscountType,
            loyaltyDiscountRub: loyaltyDiscountRub
        )
        do {
            let _ = try await api.request(.updateLoyaltySettings(req), as: MessageResponse.self)
            reportSuccess()
        } catch {
            reportFailure()
        }
    }

    /// Часовой пояс — тот же PUT-запрос, что был раньше.
    func saveTimezone() async {
        guard let token = KeychainManager.shared.getToken(),
              let url = URL(string: "https://beauty-bot-44ou.onrender.com/api/v1/masters/me/timezone") else {
            reportFailure()
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["timezone_offset": timezoneOffset])
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                reportFailure()
                return
            }
            reportSuccess()
        } catch {
            reportFailure()
        }
    }

    func saveBookingLink() async {
        let slug = bookingLinkInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !slug.isEmpty else { return }
        bookingLinkSaving = true
        bookingLinkError = nil
        do {
            let r = try await api.request(.updateBookingLink(slug), as: BookingLinkResponse.self)
            bookingLinkSlug = r.bookingLink
            bookingLinkInput = r.bookingLink
            bookingLinkSuccess = true
            reportSuccess()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.bookingLinkSuccess = false }
        } catch NetworkError.serverError(_, let msg) {
            bookingLinkError = msg
            reportFailure()
        } catch {
            bookingLinkError = "Ошибка сохранения"
            reportFailure()
        }
        bookingLinkSaving = false
    }

    func connectTelegram() async {
        do {
            let (token, botUsername) = try await APIClient.shared.telegramLinkToken()
            let domain = botUsername.isEmpty ? "Beauty6699_bot" : botUsername
            let deepLink = "https://t.me/\(domain)?start=master_\(token)"
            if let url = URL(string: deepLink) {
                await UIApplication.shared.open(url)
            }
        } catch {
            errorMessage = "Не удалось создать ссылку"
        }
    }

    // MARK: Тост

    /// Тост с текстом результата сохранения.
    func showToast(success: Bool) {
        showToast(text: success ? "Сохранено" : "Не сохранилось. Проверь интернет", isError: !success)
    }

    /// Показывает тост и прячет его через 1.6 с.
    func showToast(text: String, isError: Bool = false) {
        toastTask?.cancel()
        toast = SEToastInfo(text: text, isError: isError)
        if isError {
            HapticManager.error()
        }
        let task = Task<Void, Never> { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_600_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
        toastTask = task
    }

    private func reportSuccess() { showToast(success: true) }

    private func reportFailure() { showToast(success: false) }
}


// MARK: - Данные для экранов

enum SEFormat {
    /// На экране показываем адрес без «https://».
    static func withoutScheme(_ url: String) -> String {
        url.hasPrefix("https://") ? String(url.dropFirst(8)) : url
    }

    /// Минуты в вид «9:00».
    static func clock(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m < 10 ? "\(h):0\(m)" : "\(h):\(m)"
    }
}

enum SEProfile {
    static let specializations = ["Маникюр", "Педикюр", "Ресницы", "Брови", "Визаж", "Другое"]
}

enum SEBanks {
    static let all = ["Сбер", "Т-Банк", "Альфа", "ВТБ", "Озон", "Яндекс"]
}

enum SEHours {
    static let steps = [30, 45, 60, 90, 120]

    static func stepLabel(_ minutes: Int) -> String {
        switch minutes {
        case 30: return "30 мин"
        case 45: return "45 мин"
        case 60: return "1 ч"
        case 90: return "1 ч 30 мин"
        default: return "2 ч"
        }
    }

    /// Слоты, которые увидит клиентка: до семи от начала дня.
    static func previewSlots(start: Int, end: Int, step: Int) -> [String] {
        var result: [String] = []
        var minutes = start * 60
        while minutes + step <= end * 60 && result.count < 7 {
            result.append(SEFormat.clock(minutes: minutes))
            minutes += step
        }
        if end * 60 - start * 60 > step * 7 {
            result.append("…")
        }
        return result
    }
}

enum SELoyalty {
    static let thresholds = [5, 7, 10, 15, 20]
    static let percents = [5, 10, 15, 20]
    static let rubs = [100, 200, 300, 500, 1000]
}

enum SEReminders {
    static let days = [14, 21, 30, 45]
}

struct SEZone: Identifiable {
    let offset: Int
    let title: String
    var id: Int { offset }

    static let all: [SEZone] = [
        SEZone(offset: 2, title: "Калининград (UTC+2)"),
        SEZone(offset: 3, title: "Москва (UTC+3)"),
        SEZone(offset: 4, title: "Самара (UTC+4)"),
        SEZone(offset: 5, title: "Екатеринбург (UTC+5)"),
        SEZone(offset: 6, title: "Омск (UTC+6)"),
        SEZone(offset: 7, title: "Красноярск (UTC+7)"),
        SEZone(offset: 8, title: "Иркутск (UTC+8)"),
        SEZone(offset: 9, title: "Якутск (UTC+9)"),
        SEZone(offset: 10, title: "Владивосток (UTC+10)"),
        SEZone(offset: 11, title: "Магадан (UTC+11)"),
        SEZone(offset: 12, title: "Камчатка (UTC+12)")
    ]
}

// MARK: - Появление блоков

private struct SERevealModifier: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let delay = reduceMotion ? 0 : Double(index) * 0.04
        return content
            .opacity(shown ? 1 : 0)
            .offset(y: (shown || reduceMotion) ? 0 : 12)
            .onAppear {
                withAnimation(DS.springSmooth.delay(delay)) { shown = true }
            }
    }
}

private extension View {
    func seReveal(_ index: Int) -> some View {
        modifier(SERevealModifier(index: index))
    }
}

// MARK: - Тост

private struct SEToastLayer: ViewModifier {
    @ObservedObject var vm: SettingsViewModel

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let info = vm.toast {
                SEToast(info: info)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DS.springSnappy, value: vm.toast?.id)
    }
}

private extension View {
    func seToast(_ vm: SettingsViewModel) -> some View {
        modifier(SEToastLayer(vm: vm))
    }
}

struct SEToast: View {
    let info: SEToastInfo
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: info.isError ? "exclamationmark.circle.fill" : "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(info.isError ? theme.statusRed : theme.statusGreen)
            Text(info.text)
                .font(DS.bodySmall)
                .foregroundColor(theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(theme.backgroundCard)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(info.isError ? theme.statusRed.opacity(0.4) : theme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: theme.accentGlow.opacity(0.2), radius: 12, y: 6)
    }
}

// MARK: - Мелкие элементы

/// Подпись группы: «РАБОТА», «ПРИЛОЖЕНИЕ».
struct SELabel: View {
    let title: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title)
            .font(DS.labelSmall.weight(.bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundColor(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Цветная плитка с иконкой.
struct SEIconTile: View {
    let icon: String
    let tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// Разделитель внутри группы — с отступом под иконку.
struct SEDivider: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.borderSubtle)
            .frame(height: 1)
            .padding(.leading, 56)
    }
}

/// Карточка-группа строк.
struct SEGroup<Content: View>: View {
    private let content: Content
    @Environment(\.theme) private var theme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

/// Заголовок подстраницы 28pt bold rounded.
struct SETitleText: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .font(DS.titleMedium)
            .foregroundColor(theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Пилюля с выбором.
struct SEPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Text(title)
                .font(DS.body)
                .foregroundColor(isSelected ? Color.white : theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.clear : theme.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(CLPressStyle(scale: 0.96))
    }
}

/// Пилюли со строками-вариантами.
struct SEChoicePills: View {
    let titles: [String]
    let selected: String
    let onPick: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(titles, id: \.self) { title in
                SEPill(title: title, isSelected: title == selected) {
                    onPick(title)
                }
            }
        }
    }
}

/// Пилюли с числами.
struct SENumberPills: View {
    let values: [Int]
    let selected: Int
    let label: (Int) -> String
    let onPick: (Int) -> Void
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                SEPill(title: label(value), isSelected: value == selected) {
                    onPick(value)
                }
            }
        }
    }
}

/// Сегмент из двух капсул с переезжающей подложкой.
struct SESegment: View {
    let first: String
    let second: String
    let isFirstSelected: Bool
    let onPick: (Int) -> Void
    @Namespace private var ns
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            segmentItem(0, title: first)
            segmentItem(1, title: second)
        }
        .padding(3)
        .background(theme.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func segmentItem(_ index: Int, title: String) -> some View {
        let isSelected = isFirstSelected ? index == 0 : index == 1
        return Button {
            HapticManager.selection()
            onPick(index)
        } label: {
            Text(title)
                .font(DS.body)
                .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(theme.backgroundCard)
                            .shadow(color: theme.accentGlow.opacity(0.25), radius: 6, y: 2)
                            .matchedGeometryEffect(id: "se.segment", in: ns)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Строка с переключателем.
struct SEToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                Text(subtitle)
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

/// Поле ввода с подписью.
struct SEField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalize: Bool = true
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DS.bodySmall)
                .foregroundColor(theme.textSecondary)
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundColor(theme.textPrimary)
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalize ? .sentences : .none)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(theme.backgroundInput)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.borderSubtle, lineWidth: 1)
                )
        }
    }
}

/// «Пузырь» с примером сообщения клиентке.
struct SEBubble: View {
    let text: String
    let isMuted: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 4,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 16
                )
                .fill(theme.accent.opacity(0.12))
            )
            .opacity(isMuted ? 0.35 : 1)
            .animation(DS.springSmooth, value: isMuted)
    }
}

/// Карточка-превью с подписью.
struct SEPreviewCard<Content: View>: View {
    let title: String
    private let content: Content
    @Environment(\.theme) private var theme

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(DS.labelSmall)
                .tracking(0.6)
                .foregroundColor(theme.textSecondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Строка с круглыми «+» и «−».
struct SEStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var onValueChange: (() -> Void)?
    @State private var isShaking = false
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(title)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
            Spacer()
            HStack(spacing: 10) {
                stepButton(icon: "minus", delta: -1)
                Text(SEFormat.clock(minutes: value * 60))
                    .font(DS.headline)
                    .foregroundColor(theme.textPrimary)
                    .frame(minWidth: 56)
                    .contentTransition(.numericText())
                stepButton(icon: "plus", delta: 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .offset(x: isShaking ? 7 : 0)
        .animation(DS.springSmooth, value: isShaking)
    }

    private func stepButton(icon: String, delta: Int) -> some View {
        let isEdge = delta < 0 ? value <= range.lowerBound : value >= range.upperBound
        return Button {
            guard !isEdge else {
                HapticManager.warning()
                isShaking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isShaking = false }
                return
            }
            HapticManager.light()
            value += delta
            onValueChange?()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isEdge ? theme.textMuted.opacity(0.45) : theme.accent)
                .frame(width: 36, height: 36)
                .background(theme.backgroundInput)
                .clipShape(Circle())
        }
        .buttonStyle(CLPressStyle(scale: 0.9))
    }
}


// MARK: - Строки групп

/// Строка, которая открывает подстраницу.
struct SERow<Destination: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var value: String = ""
    var valueColor: Color?
    private let makeDestination: () -> Destination
    @Environment(\.theme) private var theme

    init(
        icon: String,
        tint: Color,
        title: String,
        value: String = "",
        valueColor: Color? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.makeDestination = destination
    }

    var body: some View {
        NavigationLink(destination: makeDestination()) {
            HStack(spacing: 12) {
                SEIconTile(icon: icon, tint: tint)
                Text(title)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                valueLabel
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle())
    }

    @ViewBuilder
    private var valueLabel: some View {
        if !value.isEmpty {
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(valueColor ?? theme.textSecondary)
                .lineLimit(1)
        }
    }
}

/// Строка-кнопка: ссылка наружу или действие.
struct SERowButton: View {
    let icon: String
    let tint: Color
    let title: String
    var value: String = ""
    var valueColor: Color?
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 12) {
                SEIconTile(icon: icon, tint: tint)
                Text(title)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundColor(valueColor ?? theme.textSecondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle())
    }
}

/// Строка без перехода — с тем, что нужно справа.
struct SERowPlain<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    var titleColor: Color? = nil
    private let makeTrailing: () -> Trailing
    @Environment(\.theme) private var theme

    init(icon: String, tint: Color, title: String, titleColor: Color? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.titleColor = titleColor
        self.makeTrailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            SEIconTile(icon: icon, tint: tint)
            Text(title)
                .font(DS.body)
                .foregroundColor(titleColor ?? theme.textPrimary)
            Spacer()
            makeTrailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Мини-переключатель темы

struct SEMiniTheme: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            capsule(.pink, title: "Розовая", colors: [Color(hex: "#FF2D78"), Color(hex: "#C21BFF")])
            capsule(.platinum, title: "Платина", colors: [Color(hex: "#9A6D35"), Color(hex: "#E3C590")])
        }
        .padding(2)
        .background(theme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func capsule(_ value: AppTheme, title: String, colors: [Color]) -> some View {
        let isSelected = themeManager.current == value
        return Button {
            guard !isSelected else { return }
            HapticManager.selection()
            withAnimation(DS.springSmooth) { themeManager.current = value }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 12, height: 12)
                Text(title)
                    .font(DS.labelSmall)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(isSelected ? AnyShapeStyle(theme.backgroundInput) : AnyShapeStyle(Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 1)
            )
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.95))
    }
}

// MARK: - Карточка профиля

struct SEProfileCard<Destination: View>: View {
    @ObservedObject var vm: SettingsViewModel
    private let makeDestination: () -> Destination
    @Environment(\.theme) private var theme

    init(vm: SettingsViewModel, @ViewBuilder destination: @escaping () -> Destination) {
        self.vm = vm
        self.makeDestination = destination
    }

    var body: some View {
        NavigationLink(destination: makeDestination()) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.gradientPrimary)
                        .frame(width: 56, height: 56)
                    Text(vm.masterInitials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.masterName.isEmpty ? "Мастер" : vm.masterName)
                        .font(DS.headline)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text(vm.profileSubtitle)
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle())
    }
}

// MARK: - Карточка ссылки

struct SELinkCard: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.theme) private var theme
    @State private var isCopied = false
    @State private var isAddressOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            linkText
            hint
            buttons
            manageLinkButton
            addressBlock
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.accent.opacity(0.35), lineWidth: 1)
        )
        .onAppear {
            if vm.bookingLinkSlug.isEmpty { isAddressOpen = true }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.accent)
            Text("Ссылка для записи")
                .font(DS.label)
                .foregroundColor(theme.textPrimary)
        }
    }

    @ViewBuilder
    private var linkText: some View {
        if vm.bookingLinkShort.isEmpty {
            Text("Ссылка ещё не создана")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textMuted)
        } else {
            Text(vm.bookingLinkShort)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(theme.accent)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var hint: some View {
        Text("Клиенты открывают её и записываются сами. Добавь в шапку Instagram и Telegram.")
            .font(DS.bodySmall)
            .foregroundColor(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 8) {
            if let url = URL(string: vm.bookingLink) {
                ShareLink(item: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Поделиться")
                            .font(DS.body)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(theme.gradientPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(CLPressStyle(scale: 0.97))
            }
            Button {
                UIPasteboard.general.string = vm.bookingLink
                HapticManager.success()
                withAnimation(DS.springSnappy) { isCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(DS.springSnappy) { isCopied = false }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isCopied ? "Скопировано ✓" : "Копировать")
                        .font(DS.body)
                }
                .foregroundColor(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(theme.backgroundInput)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(CLPressStyle(scale: 0.97))
        }
    }

    @ViewBuilder
    private var manageLinkButton: some View {
        if !vm.manageLinkShort.isEmpty {
            Button {
                UIPasteboard.general.string = vm.manageLink
                HapticManager.success()
                vm.showToast(text: "Ссылка скопирована")
            } label: {
                HStack(spacing: 6) {
                    Text("Ссылка для отмены и переноса: ")
                        .foregroundColor(theme.textSecondary)
                    Text(vm.manageLinkShort)
                        .foregroundColor(theme.textPrimary)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accent)
                }
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.borderSubtle)
                        .frame(height: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(DS.springSmooth) { isAddressOpen.toggle() }
            } label: {
                Text("Изменить адрес")
                    .font(DS.bodySmall)
                    .foregroundColor(theme.accent)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            if isAddressOpen {
                VStack(alignment: .leading, spacing: 10) {
                    SEField(
                        title: "Адрес ссылки",
                        placeholder: "твой-slug",
                        text: $vm.bookingLinkInput,
                        autocapitalize: false
                    )
                    if let error = vm.bookingLinkError {
                        Text(error)
                            .font(DS.bodySmall)
                            .foregroundColor(theme.statusRed)
                    }
                    Button {
                        Task { await vm.saveBookingLink() }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.bookingLinkSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(vm.bookingLinkSaving ? "Сохраняем…" : "Сохранить адрес")
                                .font(DS.body)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(theme.gradientPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(CLPressStyle(scale: 0.97))
                    .disabled(vm.bookingLinkSaving || vm.bookingLinkInput.isEmpty)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(DS.springSmooth, value: isAddressOpen)
    }
}


// MARK: - Подстраница «Профиль»

struct SEProfilePage: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SETitleText(text: "Профиль")
                avatar
                fields
                SELabel(title: "ЧЕМ ЗАНИМАЕШЬСЯ")
                SEChoicePills(titles: specializations, selected: vm.specialization) { value in
                    HapticManager.selection()
                    vm.specialization = value
                    vm.scheduleSave(.schedule)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .seToast(vm)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(theme.gradientPrimary)
                .frame(width: 88, height: 88)
            Text(vm.masterInitials)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            SEField(title: "Имя", placeholder: "Как вас зовут", text: $vm.masterName)
                .onChange(of: vm.masterName) { _, _ in vm.scheduleSave(.profile) }
            SEField(
                title: "Телефон",
                placeholder: "+7 900 000-00-00",
                text: $vm.phone,
                keyboardType: .phonePad,
                autocapitalize: false
            )
            .onChange(of: vm.phone) { _, _ in vm.scheduleSave(.profile) }
            SEField(
                title: "Email",
                placeholder: "name@mail.ru",
                text: $vm.email,
                keyboardType: .emailAddress,
                autocapitalize: false
            )
            .onChange(of: vm.email) { _, _ in vm.scheduleSave(.profile) }
        }
    }

    /// Текущая специализация всегда в списке, даже если её раньше не было.
    private var specializations: [String] {
        var list = SEProfile.specializations
        let current = vm.specialization
        if !current.isEmpty && !list.contains(current) {
            list.insert(current, at: 0)
        }
        return list
    }
}

// MARK: - Подстраница «Рабочее время»

struct SEHoursPage: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.theme) private var theme
    @State private var showBlockedDays = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SETitleText(text: "Рабочее время")
                daySteppers
                stepPills
                preview
                links
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .seToast(vm)
        .sheet(isPresented: $showBlockedDays) {
            BlockedDaysView()
                .environmentObject(ThemeManager.shared)
                .environment(\.theme, theme)
        }
    }

    private var daySteppers: some View {
        SEGroup {
            SEStepperRow(
                title: "Начало дня",
                value: $vm.workStart,
                range: 5...12,
                onValueChange: { vm.scheduleSave(.schedule) }
            )
            SEDivider()
            SEStepperRow(
                title: "Конец дня",
                value: $vm.workEnd,
                range: 14...23,
                onValueChange: { vm.scheduleSave(.schedule) }
            )
        }
    }

    private var stepPills: some View {
        VStack(alignment: .leading, spacing: 8) {
            SELabel(title: "Шаг онлайн-записи")
            SENumberPills(
                values: SEHours.steps,
                selected: vm.slotDuration,
                label: { SEHours.stepLabel($0) }
            ) { value in
                vm.slotDuration = value
                vm.scheduleSave(.schedule)
            }
        }
    }

    private var preview: some View {
        SEPreviewCard(title: "Так увидят клиенты") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 64), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(SEHours.previewSlots(start: vm.workStart, end: vm.workEnd, step: vm.slotDuration), id: \.self) { slot in
                    Text(slot)
                        .font(DS.bodySmall)
                        .foregroundColor(slot == "…" ? theme.textMuted : theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .animation(DS.springSmooth, value: vm.workStart)
        .animation(DS.springSmooth, value: vm.workEnd)
        .animation(DS.springSmooth, value: vm.slotDuration)
    }

    private var links: some View {
        SEGroup {
            NavigationLink {
                CustomScheduleView()
                    .environment(\.theme, theme)
            } label: {
                SERowPlain(icon: "clock", tint: Color(hex: "#3FA7FF"), title: "Своё расписание по дням") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                }
            }
            .buttonStyle(CLPressStyle())
            SEDivider()
            Button {
                HapticManager.light()
                showBlockedDays = true
            } label: {
                SERowPlain(icon: "doc.text", tint: Color(hex: "#7A8CA3"), title: "Выходные и отпуск") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                }
            }
            .buttonStyle(CLPressStyle())
        }
    }
}


// MARK: - Подстраница «Скидки постоянным»

struct SELoyaltyPage: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SETitleText(text: "Скидки постоянным")
                visitsCard
                visitOptions
                birthdayCard
                birthdayOptions
                SEPreviewCard(title: "ПРИМЕР") { previewText }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .seToast(vm)
    }

    private var visitsCard: some View {
        SEGroup {
            SEToggleRow(
                title: "Скидка за визиты",
                subtitle: "Каждый N-й визит со скидкой",
                isOn: Binding(
                    get: { vm.loyaltyEnabled },
                    set: { value in
                        vm.loyaltyEnabled = value
                        vm.scheduleSave(.loyalty)
                    }
                )
            )
        }
    }

    private var visitOptions: some View {
        dependentBlock(isOn: vm.loyaltyEnabled) {
            VStack(alignment: .leading, spacing: 12) {
                SELabel(title: "Какой визит")
                SENumberPills(
                    values: thresholds,
                    selected: vm.loyaltyThreshold,
                    label: { "каждый \($0)-й" }
                ) { value in
                    vm.loyaltyThreshold = value
                    vm.scheduleSave(.loyalty)
                }
                SELabel(title: "Скидка")
                SESegment(
                    first: "В процентах",
                    second: "В рублях",
                    isFirstSelected: vm.loyaltyDiscountType != "rub"
                ) { index in
                    vm.loyaltyDiscountType = index == 0 ? "percent" : "rub"
                    vm.scheduleSave(.loyalty)
                }
                if vm.loyaltyDiscountType == "rub" {
                    SENumberPills(
                        values: SELoyalty.rubs,
                        selected: vm.loyaltyDiscountRub,
                        label: { "\(rubText($0)) ₽" }
                    ) { value in
                        vm.loyaltyDiscountRub = value
                        vm.scheduleSave(.loyalty)
                    }
                } else {
                    SENumberPills(
                        values: percents,
                        selected: vm.loyaltyDiscount,
                        label: { "\($0)%" }
                    ) { value in
                        vm.loyaltyDiscount = value
                        vm.scheduleSave(.loyalty)
                    }
                }
            }
        }
    }

    private var birthdayCard: some View {
        SEGroup {
            SEToggleRow(
                title: "Скидка в день рождения",
                subtitle: "Клиентка получит поздравление в Telegram",
                isOn: Binding(
                    get: { vm.birthdayDiscountEnabled },
                    set: { value in
                        vm.birthdayDiscountEnabled = value
                        vm.scheduleSave(.loyalty)
                    }
                )
            )
        }
    }

    private var birthdayOptions: some View {
        dependentBlock(isOn: vm.birthdayDiscountEnabled) {
            VStack(alignment: .leading, spacing: 12) {
                SELabel(title: "Размер")
                SENumberPills(
                    values: percents,
                    selected: vm.birthdayDiscount,
                    label: { "\($0)%" }
                ) { value in
                    vm.birthdayDiscount = value
                    vm.scheduleSave(.loyalty)
                }
            }
        }
    }

    @ViewBuilder
    private var previewText: some View {
        if vm.loyaltyEnabled {
            Text("Анастасия пришла в ")
                .foregroundColor(theme.textSecondary)
            + Text("\(vm.loyaltyThreshold)")
                .foregroundColor(theme.accent)
                .fontWeight(.semibold)
            + Text("-й раз на маникюр за \(rubText(examplePrice)) ₽. Цена в записи сама станет ")
                .foregroundColor(theme.textSecondary)
            + Text("\(rubText(max(0, examplePrice - discountAmount)))")
                .foregroundColor(theme.accent)
                .fontWeight(.semibold)
            + Text(" ₽.")
                .foregroundColor(theme.textSecondary)
        } else {
            Text("Скидка за визиты выключена.")
                .foregroundColor(theme.textSecondary)
        }
    }

    private var examplePrice: Int { 2000 }

    private var discountAmount: Int {
        vm.loyaltyDiscountType == "rub" ? vm.loyaltyDiscountRub : examplePrice * vm.loyaltyDiscount / 100
    }

    private var percents: [Int] {
        var list = SELoyalty.percents
        if !list.contains(vm.loyaltyDiscount) { list.append(vm.loyaltyDiscount) }
        return list.sorted()
    }

    private var thresholds: [Int] {
        var list = SELoyalty.thresholds
        if !list.contains(vm.loyaltyThreshold) { list.append(vm.loyaltyThreshold) }
        return list.sorted()
    }

    private func dependentBlock<Content: View>(isOn: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(isOn ? 1 : 0.4)
            .disabled(!isOn)
            .animation(DS.springSmooth, value: isOn)
    }
}

// MARK: - Подстраница «Напоминания»

struct SERemindersPage: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SETitleText(text: "Напоминания")
                Text("Приходят клиенткам в Telegram от твоего имени.")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                appointmentCard
                payoutCard
                returnCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .seToast(vm)
    }

    private var appointmentCard: some View {
        SEGroup {
            VStack(spacing: 0) {
                SEToggleRow(
                    title: "О записи",
                    subtitle: "За 24 часа и за 2 часа до визита",
                    isOn: userFlag(\.remindersEnabled)
                )
                SEDivider()
                SEBubble(
                    text: "Анастасия, напоминаю: завтра в 13:00 маникюр 💅 Если планы поменялись, перенеси запись по ссылке: \(vm.manageLinkShort)",
                    isMuted: !vm.remindersEnabled
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }

    private var payoutCard: some View {
        SEGroup {
            VStack(spacing: 0) {
                SEToggleRow(
                    title: "Реквизиты после визита",
                    subtitle: "Номер карты и банк, чтобы клиентке было удобно перевести",
                    isOn: userFlag(\.paymentReminderEnabled)
                )
                SEDivider()
                SEBubble(
                    text: "Спасибо, что пришла! Перевод по номеру \(vm.paymentPhone.isEmpty ? "+7 ··· ··· ·· ··" : vm.paymentPhone) (\(vm.paymentBanks.isEmpty ? "Сбер" : vm.paymentBanks)). До встречи ✨",
                    isMuted: !vm.paymentReminderEnabled
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }

    private var returnCard: some View {
        SEGroup {
            VStack(spacing: 0) {
                SEToggleRow(
                    title: "Вернуть клиентку",
                    subtitle: "Если давно не приходила",
                    isOn: userFlag(\.returnReminderEnabled)
                )
                if vm.returnReminderEnabled {
                    SEDivider()
                    SENumberPills(
                        values: SEReminders.days,
                        selected: vm.returnReminderDays,
                        label: { "через \($0) дн." }
                    ) { value in
                        vm.returnReminderDays = value
                        vm.showToast(success: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                SEDivider()
                SEBubble(text: returnBubbleText, isMuted: !vm.returnReminderEnabled)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
    }

    private var returnBubbleText: String {
        let days = ruPlural(vm.returnReminderDays, "день", "дня", "дней")
        return "Анастасия, прошло уже \(vm.returnReminderDays) \(days) с маникюра. Пора обновить? Свободные окошки тут: \(vm.bookingLinkShort)"
    }

    /// Переключатели из UserDefaults: показываем «Сохранено» сразу.
    private func userFlag(_ keyPath: ReferenceWritableKeyPath<SettingsViewModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { vm[keyPath: keyPath] },
            set: { value in
                vm[keyPath: keyPath] = value
                vm.showToast(success: true)
            }
        )
    }
}

// MARK: - Подстраница «Реквизиты для перевода»

struct SEPayoutPage: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SETitleText(text: "Реквизиты для перевода")
                Text("Появятся в сообщении клиентке после визита, если включено напоминание «Реквизиты после визита».")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                fields
                banks
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .seToast(vm)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            SEField(
                title: "Номер карты",
                placeholder: "0000 0000 0000 0000",
                text: $vm.paymentCard,
                keyboardType: .numberPad,
                autocapitalize: false
            )
            .onChange(of: vm.paymentCard) { _, _ in vm.scheduleSave(.payout) }
            SEField(
                title: "Телефон для перевода",
                placeholder: "+7 900 000-00-00",
                text: $vm.paymentPhone,
                keyboardType: .phonePad,
                autocapitalize: false
            )
            .onChange(of: vm.paymentPhone) { _, _ in vm.scheduleSave(.payout) }
        }
    }

    private var banks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SELabel(title: "Банки")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(SEBanks.all, id: \.self) { bank in
                    SEPill(title: bank, isSelected: vm.bankList.contains(bank)) {
                        vm.toggleBank(bank)
                        vm.scheduleSave(.payout)
                    }
                }
            }
            if !customBanks.isEmpty {
                Text("Свои банки: \(customBanks.joined(separator: ", "))")
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
            }
        }
    }

    /// Банки, которых нет в списке, — остаются в строке как есть.
    private var customBanks: [String] {
        vm.bankList.filter { !SEBanks.all.contains($0) }
    }
}


// MARK: - Главный экран настроек

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showOnboarding = false
    @State private var showReminderTemplates = false
    @State private var isPushEnabled = false

    var body: some View {
        Color.clear
            .overlay {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header.seReveal(0)
                        SEProfileCard(vm: vm) { SEProfilePage(vm: vm) }
                            .seReveal(1)
                        SELinkCard(vm: vm)
                            .seReveal(2)
                        workBlock.seReveal(3)
                        telegramBlock.seReveal(4)
                        appBlock.seReveal(5)
                        helpBlock.seReveal(6)
                        logoutBlock.seReveal(7)
                        footer.seReveal(8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationTitle("Настройки")
            .task {
                await vm.load()
                await refreshPushStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task {
                    await vm.load()
                    await refreshPushStatus()
                }
            }
            .seToast(vm)
            .alert("Выйти из аккаунта?", isPresented: $showLogoutAlert) {
                Button("Остаться", role: .cancel) {}
                Button("Выйти", role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text("Записи и клиенты сохранятся. Войти можно с теми же данными.")
            }
            .alert("Удалить аккаунт?", isPresented: $showDeleteAccountAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить навсегда", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("Все клиенты, записи и статистика удалятся навсегда. Отменить это нельзя.")
            }
            .sheet(isPresented: $showReminderTemplates) {
                ReminderTemplatesView()
                    .environmentObject(ThemeManager.shared)
                    .environment(\.theme, theme)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onFinish: { showOnboarding = false }, isPreview: true)
                    .environmentObject(ThemeManager.shared)
                    .environment(\.theme, theme)
            }
    }

    // MARK: Шапка

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Всё сохраняется само")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent)
                Text("Настройки")
                    .font(DS.titleMedium)
                    .foregroundColor(theme.textPrimary)
            }
            Spacer()
            HeaderBellButton()
        }
    }

    // MARK: Работа

    private var workBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SELabel(title: "РАБОТА")
            SEGroup {
                SERow(icon: "clock.fill", tint: Color(hex: "#3FA7FF"), title: "Рабочее время", value: vm.hoursText) {
                    SEHoursPage(vm: vm)
                }
                SEDivider()
                SERow(icon: "gift.fill", tint: Color(hex: "#FF6FA3"), title: "Скидки постоянным", value: vm.loyaltySummary) {
                    SELoyaltyPage(vm: vm)
                }
                SEDivider()
                SERow(
                    icon: "creditcard.fill",
                    tint: Color(hex: "#5B8CFF"),
                    title: "Реквизиты для перевода",
                    value: vm.payoutSummary,
                    valueColor: vm.payoutFilled ? nil : theme.statusYellow
                ) {
                    SEPayoutPage(vm: vm)
                }
            }
        }
    }

    // MARK: Клиентам в Telegram

    private var telegramBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SELabel(title: "КЛИЕНТАМ В TELEGRAM")
            SEGroup {
                SERow(icon: "bell.fill", tint: Color(hex: "#FF9F45"), title: "Напоминания", value: vm.remindersSummary) {
                    SERemindersPage(vm: vm)
                }
                SEDivider()
                SERowButton(
                    icon: "text.bubble.fill",
                    tint: Color(hex: "#34C3A0"),
                    title: "Тексты сообщений"
                ) {
                    showReminderTemplates = true
                }
            }
        }
    }

    // MARK: Приложение

    private var appBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SELabel(title: "ПРИЛОЖЕНИЕ")
            SEGroup {
                SERowPlain(icon: "paintpalette.fill", tint: Color(hex: "#FF5C98"), title: "Тема") {
                    SEMiniTheme()
                }
                SEDivider()
                timezoneRow
                SEDivider()
                SERowButton(
                    icon: "app.badge.fill",
                    tint: Color(hex: "#FF9F45"),
                    title: "Уведомления мне",
                    value: isPushEnabled ? "включены" : "выключены"
                ) {
                    openIphoneSettings()
                }
                SEDivider()
                telegramRow
            }
            if let error = vm.errorMessage {
                BBErrorBanner(message: error)
            }
        }
    }

    private var timezoneRow: some View {
        Menu {
            ForEach(SEZone.all) { zone in
                Button(zone.title) {
                    vm.timezoneOffset = zone.offset
                    vm.scheduleSave(.timezone)
                }
            }
        } label: {
            SERowPlain(icon: "globe", tint: Color(hex: "#7A8CA3"), title: "Часовой пояс") {
                HStack(spacing: 4) {
                    Text(currentZoneTitle)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                }
            }
        }
    }

    @ViewBuilder
    private var telegramRow: some View {
        if vm.isTelegramConnected {
            SERowPlain(icon: "paperplane.fill", tint: Color(hex: "#2AABEE"), title: "Telegram") {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.statusGreen)
                    Text("подключён")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.statusGreen)
                }
            }
        } else {
            SERowButton(
                icon: "paperplane.fill",
                tint: Color(hex: "#2AABEE"),
                title: "Telegram",
                value: "Подключить",
                valueColor: theme.accent
            ) {
                Task { await vm.connectTelegram() }
            }
        }
    }

    private var currentZoneTitle: String {
        SEZone.all.first(where: { $0.offset == vm.timezoneOffset })?.title ?? "Москва (UTC+3)"
    }

    // MARK: Помощь

    private var helpBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SELabel(title: "ПОМОЩЬ")
            SEGroup {
                SERowButton(icon: "questionmark.circle.fill", tint: Color(hex: "#7A8CA3"), title: "Как пользоваться") {
                    showOnboarding = true
                }
                SEDivider()
                SERowButton(icon: "paperplane.fill", tint: Color(hex: "#2AABEE"), title: "Написать в поддержку", value: "@Razo0220") {
                    openLink("https://t.me/Razo0220")
                }
                SEDivider()
                SERowButton(icon: "hand.raised.fill", tint: Color(hex: "#7A8CA3"), title: "Политика конфиденциальности") {
                    openLink("https://solvobeauty.vercel.app/privacy.html")
                }
            }
        }
    }

    // MARK: Аккаунт

    private var logoutBlock: some View {
        SEGroup {
            Button {
                HapticManager.light()
                showLogoutAlert = true
            } label: {
                SERowPlain(
                    icon: "rectangle.portrait.and.arrow.right",
                    tint: theme.statusRed,
                    title: "Выйти из аккаунта",
                    titleColor: theme.statusRed
                ) {
                    EmptyView()
                }
            }
            .buttonStyle(CLPressStyle())
        }
        .padding(.top, 4)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                HapticManager.light()
                showDeleteAccountAlert = true
            } label: {
                Text("Удалить аккаунт")
                    .font(DS.bodySmall)
                    .foregroundColor(theme.statusRed.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(vm.versionText)
                .font(.system(size: 12))
                .foregroundColor(theme.textMuted)
        }
    }

    // MARK: Действия

    private func openIphoneSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func openLink(_ address: String) {
        if let url = URL(string: address) {
            UIApplication.shared.open(url)
        }
    }

    private func refreshPushStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = settings.authorizationStatus
        isPushEnabled = status == .authorized || status == .provisional || status == .ephemeral
    }

    private func deleteAccount() async {
        guard let token = KeychainManager.shared.getToken(),
              let url = URL(string: "https://beauty-bot-44ou.onrender.com/api/v1/masters/me") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                await MainActor.run { appState.logout() }
            }
        } catch {}
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
            .environmentObject(ThemeManager.shared)
            .environmentObject(NotificationsViewModel())
            .environment(\.theme, .pink)
    }
}
