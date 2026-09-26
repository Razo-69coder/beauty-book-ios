import SwiftUI
import PhotosUI
import UIKit

// MARK: - Формат дат для карточки клиента

private enum CLDetailFormat {
    static let monthsShort: [String] = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
    static let monthsGenitive: [String] = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
    static let weekdaysShort: [String] = ["вс", "пн", "вт", "ср", "чт", "пт", "сб"]

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

    /// Полная дата визита: дата + время
    static func visitDate(_ item: AppointmentHistory) -> Date? {
        guard let day: Date = isoDay(item.appointmentDate) else { return nil }
        let parts: [Substring] = item.time.split(separator: ":")
        var components: DateComponents = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = parts.count > 0 ? (Int(parts[0]) ?? 0) : 0
        components.minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        components.second = 0
        return Calendar.current.date(from: components)
    }

    static func isUpcoming(_ item: AppointmentHistory) -> Bool {
        let status: String = (item.status ?? "").lowercased()
        if status == "cancelled" || status == "completed" || status == "no_show" { return false }
        guard let date: Date = visitDate(item) else { return false }
        return date > Date()
    }

    /// Через сколько дней день рождения (nil — не указан или некорректный формат)
    static func birthdayIn(raw: String?) -> Int? {
        guard let raw = raw else { return nil }
        let parts: [Substring] = raw.trimmingCharacters(in: .whitespaces).split(separator: "-")
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

// MARK: - Блок карточки с номером для поочерёдного появления

private struct CLDetailBlock: Identifiable {
    let index: Int
    let view: AnyView

    var id: Int { index }
}

// MARK: - Отслеживание шапки (имя уезжает в панель навигации)

private struct CLDetailMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Быстрая кнопка

struct CLQuickAction: View {
    let icon: String
    let title: String
    let theme: AppTheme
    let isEnabled: Bool
    var isMain: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isMain ? .white : theme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isMain ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(CLPressStyle(scale: 0.95))
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
    }
}

// MARK: - Строка истории визитов

struct CLHistoryRow: View {
    let item: AppointmentHistory
    let isUpcoming: Bool
    let theme: AppTheme

    private var status: String { (item.status ?? "").lowercased() }
    private var isCancelled: Bool { status == "cancelled" }
    private var isNoShow: Bool { status == "no_show" }
    private var isPending: Bool { status == "pending" }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            dateColumn
            VStack(alignment: .leading, spacing: 3) {
                Text(item.procedure)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(rubText(item.price))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.textPrimary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isUpcoming ? theme.accent.opacity(0.08) : theme.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUpcoming ? theme.accent.opacity(0.3) : theme.borderSubtle, lineWidth: 1)
        )
        .opacity(isCancelled ? 0.55 : 1)
    }

    private var dateColumn: some View {
        VStack(spacing: 1) {
            Text(dayString)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Text(monthString)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.textMuted)
        }
        .frame(width: 44)
    }

    private var dayString: String {
        guard let date: Date = CLDetailFormat.isoDay(item.appointmentDate) else { return "—" }
        return "\(Calendar.current.component(.day, from: date))"
    }

    private var monthString: String {
        guard let date: Date = CLDetailFormat.isoDay(item.appointmentDate) else { return "" }
        let index: Int = Calendar.current.component(.month, from: date) - 1
        guard index >= 0 && index < CLDetailFormat.monthsShort.count else { return "" }
        return CLDetailFormat.monthsShort[index]
    }

    private var subtitle: String {
        var result: String = prefixText
        result += weekdayAndTime
        return result
    }

    private var prefixText: String {
        if isCancelled { return "Отменена · " }
        if isNoShow { return "Не пришла · " }
        if isUpcoming {
            return isPending ? "Ждёт подтверждения · " : "Предстоит · "
        }
        return ""
    }

    private var weekdayAndTime: String {
        let time: String = item.time
        guard let date: Date = CLDetailFormat.isoDay(item.appointmentDate) else { return time }
        let index: Int = Calendar.current.component(.weekday, from: date) - 1
        guard index >= 0 && index < CLDetailFormat.weekdaysShort.count else { return time }
        return CLDetailFormat.weekdaysShort[index] + ", " + time
    }
}

// MARK: - Деление полоски лояльности

struct CLLoyaltySegment: View {
    let isFilled: Bool
    let isLast: Bool
    let index: Int
    let theme: AppTheme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)
                .frame(maxWidth: .infinity)
                .frame(height: 8)

            if isLast {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                Image(systemName: "gift")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 10)
        .animation(segmentAnimation, value: appeared)
        .onAppear { appeared = true }
    }

    private var fillColor: Color {
        isLast ? theme.accent.opacity(0.14) : (isFilled ? theme.accent : theme.borderSubtle)
    }

    private var segmentAnimation: Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        return DS.springSmooth.delay(Double(index) * 0.03)
    }
}

// MARK: - Плитка фото работы

struct CLPhotoTile: View {
    let image: UIImage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(CLPressStyle(scale: 0.95))
    }
}

// MARK: - Client Detail View

struct ClientDetailView: View {
    @State var client: Client
    var onDelete: (() -> Void)? = nil

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var history: [AppointmentHistory] = []
    @State private var photos: [ClientPhoto] = []
    @State private var uiPhotos: [UIImage] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showGalleryPicker = false
    @State private var selectedPhoto: UIImage? = nil
    @State private var isLoading = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showAppointmentSheet = false
    @State private var showAllHistory = false
    @State private var bookingLink = ""
    @State private var loyaltyEnabled = false
    @State private var loyaltyThreshold = 10
    @State private var discountLabel = "10%"
    @State private var showNavTitle = false
    @State private var appeared = false

    // MARK: - Тело экрана

    var body: some View {
        theme.backgroundDeep
            .ignoresSafeArea()
            .overlay { scrollContent }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onPreferenceChange(CLDetailMinYKey.self) { value in
                updateNavTitle(minY: value)
            }
            .task {
                appeared = true
                await loadEverything()
            }
            .sheet(isPresented: $showAppointmentSheet, onDismiss: {
                Task { await loadHistory() }
            }) {
                NewAppointmentView(preselectedTime: nil, selectedDate: nil, preselectedClient: client)
                    .environment(\.theme, theme)
            }
            .sheet(isPresented: $showEditSheet) {
                ClientEditView(client: client, onSave: { updatedClient in
                    client = updatedClient
                    Task { await loadHistory() }
                })
                .environment(\.theme, theme)
            }
            .fullScreenCover(isPresented: photoCoverBinding) {
                photoViewer
            }
            .alert("Удалить клиента?", isPresented: $showDeleteConfirm) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    Task { await deleteClient() }
                }
            } message: {
                Text("История визитов и фото клиента будут удалены безвозвратно.")
            }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CLDetailMinYKey.self,
                        value: geo.frame(in: .named("cdScroll")).minY
                    )
                }
                .frame(height: 0)

                VStack(spacing: 14) {
                    ForEach(detailBlocks, id: \.index) { block in
                        blockContent(at: block.index) { block.view }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
        }
        .coordinateSpace(name: "cdScroll")
    }

    @ViewBuilder
    private func blockContent(at index: Int, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .animation(
                reduceMotion ? .easeOut(duration: 0.22) : DS.springSmooth.delay(Double(index) * 0.05),
                value: appeared
            )
    }

    /// Блоки карточки с порядковыми номерами для поочерёдного появления
    private var detailBlocks: [CLDetailBlock] {
        var items: [CLDetailBlock] = []
        var next: Int = 0

        items.append(CLDetailBlock(index: next, view: AnyView(heroSection)))
        next += 1
        items.append(CLDetailBlock(index: next, view: AnyView(quickActions)))
        next += 1

        if let allergies: String = client.allergies, !allergies.isEmpty {
            items.append(CLDetailBlock(index: next, view: AnyView(allergyBanner(allergies))))
            next += 1
        }
        if let notes: String = client.notes, !notes.isEmpty {
            items.append(CLDetailBlock(index: next, view: AnyView(noteBanner(notes))))
            next += 1
        }
        if visits > 0 {
            items.append(CLDetailBlock(index: next, view: AnyView(statsCard)))
            next += 1
        }
        if loyaltyEnabled {
            items.append(CLDetailBlock(index: next, view: AnyView(loyaltyCard)))
            next += 1
        }
        items.append(CLDetailBlock(index: next, view: AnyView(infoCard)))
        next += 1
        items.append(CLDetailBlock(index: next, view: AnyView(historySection)))
        next += 1
        items.append(CLDetailBlock(index: next, view: AnyView(photoGallery)))

        return items
    }

    // MARK: - Панель навигации

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(client.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .opacity(showNavTitle ? 1 : 0)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            moreMenu
        }
    }

    private var moreMenu: some View {
        Menu {
            Button {
                showEditSheet = true
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Удалить клиента", systemImage: "trash")
            }
            .disabled(isDeleting)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
                .foregroundColor(theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Ещё")
    }

    private func updateNavTitle(minY: CGFloat) {
        let shouldShow: Bool = minY < -120
        guard shouldShow != showNavTitle else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : DS.springSmooth) {
            showNavTitle = shouldShow
        }
    }

    // MARK: - Расчёты по клиентке

    private var visits: Int { client.appointmentsCount ?? history.count }

    private var phoneDigits: String { client.phone.filter { $0.isNumber } }

    private var isNextDiscount: Bool {
        guard loyaltyEnabled, loyaltyThreshold > 0 else { return false }
        return (visits + 1) % loyaltyThreshold == 0
    }

    private var upcomingVisits: [AppointmentHistory] {
        history.filter { CLDetailFormat.isUpcoming($0) }.sorted(by: sortAscending)
    }

    private var pastVisits: [AppointmentHistory] {
        history.filter { !CLDetailFormat.isUpcoming($0) }.sorted(by: sortDescending)
    }

    private var visiblePastVisits: [AppointmentHistory] {
        showAllHistory ? pastVisits : Array(pastVisits.prefix(4))
    }

    private func sortAscending(_ lhs: AppointmentHistory, _ rhs: AppointmentHistory) -> Bool {
        if lhs.appointmentDate != rhs.appointmentDate { return lhs.appointmentDate < rhs.appointmentDate }
        return lhs.time < rhs.time
    }

    private func sortDescending(_ lhs: AppointmentHistory, _ rhs: AppointmentHistory) -> Bool {
        if lhs.appointmentDate != rhs.appointmentDate { return lhs.appointmentDate > rhs.appointmentDate }
        return lhs.time > rhs.time
    }

    /// Прошедшие визиты, которые засчитываются в деньгах
    private var paidPastVisits: [AppointmentHistory] {
        pastVisits.filter { item in
            let status: String = (item.status ?? "").lowercased()
            return status != "cancelled" && status != "no_show"
        }
    }

    private var totalSpent: Int {
        paidPastVisits.reduce(0) { $0 + $1.price }
    }

    private var averageCheck: Int {
        let count: Int = paidPastVisits.count
        guard count > 0 else { return 0 }
        let raw: Double = Double(totalSpent) / Double(count)
        return Int((raw / 10.0).rounded()) * 10
    }

    // MARK: - Шапка

    private var heroSection: some View {
        VStack(spacing: 10) {
            CLAvatar(
                name: client.name,
                size: 76,
                dotSize: 16,
                hasTelegram: client.telegramId != nil,
                theme: theme
            )
            .shadow(color: theme.accentGlow, radius: 20)

            Text(client.name)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(client.phone)
                .font(.system(size: 15))
                .foregroundColor(theme.textSecondary)

            heroTags
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var heroTags: some View {
        HStack(spacing: 6) {
            if let source: String = client.source, !source.isEmpty {
                CLTag(text: source, color: theme.textSecondary)
            }
            if client.telegramId != nil {
                CLTag(text: "Telegram подключён", color: theme.statusGreen)
            } else {
                CLTag(text: "Без Telegram: напоминания не придут", color: theme.statusYellow)
            }
        }
    }

    // MARK: - Быстрые кнопки

    private var quickActions: some View {
        HStack(spacing: 8) {
            CLQuickAction(
                icon: "calendar.badge.plus",
                title: "Записать",
                theme: theme,
                isEnabled: true,
                isMain: true
            ) {
                showAppointmentSheet = true
            }
            CLQuickAction(
                icon: "phone.fill",
                title: "Позвонить",
                theme: theme,
                isEnabled: !phoneDigits.isEmpty
            ) {
                callClient()
            }
            CLQuickAction(
                icon: "paperplane.fill",
                title: "Написать",
                theme: theme,
                isEnabled: telegramURLString != nil
            ) {
                openTelegram()
            }
            CLQuickAction(
                icon: "bell.fill",
                title: "Напомнить",
                theme: theme,
                isEnabled: !phoneDigits.isEmpty
            ) {
                remindClient()
            }
        }
    }

    private func callClient() {
        let plus: String = client.phone.trimmingCharacters(in: .whitespaces).hasPrefix("+") ? "+" : ""
        guard let url: URL = URL(string: "tel:\(plus)\(phoneDigits)") else { return }
        HapticManager.light()
        openURL(url)
    }

    private var telegramURLString: String? {
        if let username: String = client.username, !username.isEmpty {
            let clean: String = username.hasPrefix("@") ? String(username.dropFirst()) : username
            return "https://t.me/\(clean)"
        }
        guard !phoneDigits.isEmpty else { return nil }
        var normalized: String = phoneDigits
        if normalized.hasPrefix("8") {
            normalized = "7" + String(normalized.dropFirst())
        }
        return "https://t.me/+\(normalized)"
    }

    private func openTelegram() {
        guard let raw: String = telegramURLString,
              let url: URL = URL(string: raw) else { return }
        HapticManager.light()
        openURL(url)
    }

    private func remindClient() {
        guard !phoneDigits.isEmpty else { return }
        let firstName: String = client.name.split(separator: " ").first.map(String.init) ?? client.name
        var text: String = "Здравствуйте, \(firstName)! Давно не виделись 💅 Есть свободные окна, записать вас?"
        if !bookingLink.isEmpty {
            text += "\nЗаписаться онлайн: \(bookingLink)"
        }
        let encoded: String = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        guard let url: URL = URL(string: "sms:\(phoneDigits)&body=\(encoded)") else { return }
        HapticManager.light()
        openURL(url)
    }

    // MARK: - Плашки сверху

    private func allergyBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.statusYellow)
            Text("Аллергия: \(text)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.statusYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.statusYellow.opacity(0.35), lineWidth: 1)
        )
    }

    private func noteBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.accent)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Цифры

    private var statsCard: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(visits)", label: ruPlural(visits, "визит", "визита", "визитов"))
            statDivider
            statColumn(value: rubText(totalSpent), label: "всего")
            statDivider
            statColumn(value: rubText(averageCheck), label: "средний чек")
        }
        .padding(.vertical, 16)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    private var statDivider: some View {
        Rectangle()
            .fill(theme.borderSubtle)
            .frame(width: 1, height: 40)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(reduceMotion ? .identity : .numericText())
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Лояльность

    private var loyaltyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(loyaltyTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Text("каждый \(loyaltyThreshold)-й")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textMuted)
            }
            loyaltyProgress
        }
        .padding(16)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    private var loyaltyTitle: String {
        if isNextDiscount && visits > 0 {
            return "Следующий визит со скидкой \(discountLabel)"
        }
        let left: Int = max(1, loyaltyThreshold - (visits % loyaltyThreshold))
        let word: String = ruPlural(left, "визит", "визита", "визитов")
        return "До скидки \(discountLabel): \(left) \(word)"
    }

    @ViewBuilder
    private var loyaltyProgress: some View {
        if loyaltyThreshold > 12 {
            loyaltyBar
        } else {
            loyaltySegments
        }
    }

    /// Полоска прогресса — если делений слишком много
    private var loyaltyBar: some View {
        let progress: CGFloat = loyaltyThreshold > 0
            ? CGFloat(visits % loyaltyThreshold) / CGFloat(loyaltyThreshold)
            : 0
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(theme.borderSubtle)
                .frame(height: 8)
            GeometryReader { geo in
                Capsule()
                    .fill(theme.gradientPrimary)
                    .frame(width: max(8, geo.size.width * progress), height: 8)
            }
            .frame(height: 8)
        }
        .frame(height: 8)
    }

    private var loyaltySegments: some View {
        HStack(spacing: 5) {
            ForEach(0..<loyaltyThreshold, id: \.self) { index in
                CLLoyaltySegment(
                    isFilled: index < visits % loyaltyThreshold,
                    isLast: index == loyaltyThreshold - 1,
                    index: index,
                    theme: theme
                )
            }
        }
    }

    // MARK: - Информация

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(key: "Последний визит", value: lastVisitText, isMuted: false)
            if let frequency: String = usualFrequencyText {
                infoDivider
                infoRow(key: "Обычно ходит", value: frequency, isMuted: false)
            }
            infoDivider
            infoRow(key: "День рождения", value: birthdayText, isMuted: client.birthday == nil)
            infoDivider
            infoRow(key: "Откуда пришла", value: sourceText, isMuted: sourceText == "—")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    private var infoDivider: some View {
        Rectangle()
            .fill(theme.borderSubtle)
            .frame(height: 1)
    }

    private func infoRow(key: String, value: String, isMuted: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isMuted ? theme.textMuted : theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 11)
    }

    private var lastVisitText: String {
        guard let date: Date = CLDetailFormat.isoDay(client.lastVisit) else { return "ещё не было" }
        var result: String = shortDayText(date)
        if let days: Int = daysAway, days > 35 {
            result += " · \(days / 7) нед. назад"
        }
        return result
    }

    private func shortDayText(_ date: Date) -> String {
        let index: Int = Calendar.current.component(.month, from: date) - 1
        let day: Int = Calendar.current.component(.day, from: date)
        guard index >= 0 && index < CLDetailFormat.monthsShort.count else { return "\(day)" }
        return "\(day) \(CLDetailFormat.monthsShort[index])"
    }

    private var daysAway: Int? {
        guard let date: Date = CLDetailFormat.isoDay(client.lastVisit) else { return nil }
        let calendar = Calendar.current
        let from: Date = calendar.startOfDay(for: date)
        let to: Date = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: from, to: to).day
    }

    /// «раз в 3 недели» по последним пяти прошедшим визитам
    private var usualFrequencyText: String? {
        let sample: [AppointmentHistory] = Array(pastVisits.prefix(5))
        let count: Int = sample.count
        guard count >= 2 else { return nil }
        guard let newest: Date = CLDetailFormat.visitDate(sample[0]),
              let oldest: Date = CLDetailFormat.visitDate(sample[count - 1]) else { return nil }
        let days: Int = Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 0
        let gaps: Double = Double(count - 1)
        let weeks: Int = max(1, Int((Double(days) / gaps / 7.0).rounded()))
        return "раз в \(weeks) \(ruPlural(weeks, "неделю", "недели", "недель"))"
    }

    private var birthdayText: String {
        guard let raw: String = client.birthday else { return "не указан" }
        let parts: [Substring] = raw.trimmingCharacters(in: .whitespaces).split(separator: "-")
        guard parts.count == 2,
              let month: Int = Int(parts[0]),
              let day: Int = Int(parts[1]),
              month >= 1, month <= 12,
              month <= CLDetailFormat.monthsGenitive.count else { return raw }
        var result: String = "\(day) \(CLDetailFormat.monthsGenitive[month - 1])"
        if let days: Int = CLDetailFormat.birthdayIn(raw: raw), days <= 14 {
            let word: String = ruPlural(days, "день", "дня", "дней")
            result += ", через \(days) \(word)"
        }
        return result
    }

    private var sourceText: String {
        guard let source: String = client.source, !source.isEmpty else { return "—" }
        return source
    }

    // MARK: - История визитов

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("История визитов")
            historyList
        }
    }

    @ViewBuilder
    private var historyList: some View {
        let upcoming: [AppointmentHistory] = upcomingVisits
        let past: [AppointmentHistory] = visiblePastVisits

        if upcoming.isEmpty && pastVisits.isEmpty {
            Text("Визитов пока не было")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
        } else {
            VStack(spacing: 8) {
                ForEach(Array(upcoming.enumerated()), id: \.offset) { _, item in
                    CLHistoryRow(item: item, isUpcoming: true, theme: theme)
                }
                ForEach(Array(past.enumerated()), id: \.offset) { _, item in
                    CLHistoryRow(item: item, isUpcoming: false, theme: theme)
                }
            }
            if !showAllHistory && pastVisits.count > 4 {
                Button {
                    HapticManager.light()
                    withAnimation(reduceMotion ? nil : DS.springSmooth) {
                        showAllHistory = true
                    }
                } label: {
                    Text("Показать все \(pastVisits.count)")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textMuted)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    // MARK: - Фото работ

    private var photoGallery: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("Фото работ")
                Spacer(minLength: 8)
                Button {
                    showPhotoPicker = true
                } label: {
                    Text("+ Добавить")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            photoStrip
        }
        .confirmationDialog("Добавить фото", isPresented: $showPhotoPicker) {
            Button("Камера") {
                showCamera = true
            }
            Button("Галерея") {
                showGalleryPicker = true
            }
            Button("Отмена", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                uiPhotos.append(image)
                ClientPhotoStorage.save(image, clientId: client.id)
            }
        }
        .sheet(isPresented: $showGalleryPicker) {
            PHPickerViewWrapper { image in
                uiPhotos.append(image)
                ClientPhotoStorage.save(image, clientId: client.id)
            }
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(uiPhotos.enumerated()), id: \.offset) { _, image in
                    CLPhotoTile(image: image) {
                        HapticManager.light()
                        selectedPhoto = image
                    }
                }
                addPhotoTile
            }
            .padding(.vertical, 2)
        }
    }

    private var addPhotoTile: some View {
        Button {
            showPhotoPicker = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.backgroundInput)
                    .frame(width: 88, height: 110)
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.borderSubtle, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: 88, height: 110)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(CLPressStyle(scale: 0.95))
        .accessibilityLabel("Добавить фото")
    }

    private var photoCoverBinding: Binding<Bool> {
        Binding(
            get: { selectedPhoto != nil },
            set: { newValue in
                if !newValue { selectedPhoto = nil }
            }
        )
    }

    private var photoViewer: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let photo: UIImage = selectedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
            }
            Button {
                selectedPhoto = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .contentShape(Circle())
            }
            .padding(16)
            .accessibilityLabel("Закрыть фото")
        }
    }

    // MARK: - Загрузка данных

    private func loadEverything() async {
        await loadHistory()
        await loadProfile()
        await loadBookingLink()
    }

    private func loadHistory() async {
        isLoading = true
        if let resp: ClientDetail = try? await APIClient.shared.request(.clientDetail(id: client.id), as: ClientDetail.self) {
            history = resp.history
            client = mergeDetail(resp)
        } else {
            history = []
        }
        photos = []
        uiPhotos = ClientPhotoStorage.load(clientId: client.id)
        isLoading = false
    }

    /// Подтягиваем свежие источник, аллергии и заметку из карточки
    private func mergeDetail(_ detail: ClientDetail) -> Client {
        let freshNotes: String? = (detail.notes?.isEmpty == false) ? detail.notes : client.notes
        return Client(
            id: client.id,
            name: client.name,
            phone: client.phone,
            notes: freshNotes,
            lastVisit: client.lastVisit,
            username: client.username,
            telegramId: client.telegramId,
            appointmentsCount: client.appointmentsCount,
            birthday: client.birthday,
            source: detail.source,
            allergies: detail.allergies
        )
    }

    private func loadProfile() async {
        guard let me: MasterProfile = try? await APIClient.shared.request(.me, as: MasterProfile.self) else { return }
        loyaltyEnabled = me.loyaltyDiscountEnabled ?? false
        if let threshold: Int = me.loyaltyThreshold, threshold > 0 {
            loyaltyThreshold = threshold
        } else {
            loyaltyThreshold = 10
        }
        discountLabel = CLDetailFormat.discountLabel(me)
    }

    private func loadBookingLink() async {
        guard let resp: BookingLinkResponse = try? await APIClient.shared.request(.getBookingLink, as: BookingLinkResponse.self) else { return }
        let slug = resp.bookingLink.trimmingCharacters(in: .whitespacesAndNewlines)
        bookingLink = slug.isEmpty ? "" : "https://beauty-bot-44ou.onrender.com/book/\(slug)"
    }

    private func deleteClient() async {
        isDeleting = true
        do {
            let _ = try await APIClient.shared.request(.deleteClient(id: client.id), as: MessageResponse.self)
            onDelete?()
            dismiss()
        } catch {
            isDeleting = false
        }
    }
}

// MARK: - Client Photo Storage

struct ClientPhotoStorage {
    static func directory(for clientId: Int) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ClientPhotos/\(clientId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ image: UIImage, clientId: Int) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let file = directory(for: clientId).appendingPathComponent("\(UUID().uuidString).jpg")
        try? data.write(to: file)
    }

    static func load(clientId: Int) -> [UIImage] {
        let dir = directory(for: clientId)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.compactMap { UIImage(contentsOfFile: $0.path) }
    }
}

#Preview {
    NavigationStack {
        ClientDetailView(client: MockData.clients[0])
            .environment(\.theme, .pink)
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - PHPicker Wrapper

struct PHPickerViewWrapper: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerViewWrapper

        init(_ parent: PHPickerViewWrapper) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                if let img = image as? UIImage {
                    DispatchQueue.main.async { self.parent.onImagePicked(img) }
                }
            }
        }
    }
}
