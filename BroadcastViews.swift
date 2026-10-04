import SwiftUI
import UIKit

// MARK: - Общие помощники

/// Текст ошибки из ответа сервера — detail без технического префикса
func bcErrorText(_ error: Error) -> String {
    guard let networkError: NetworkError = error as? NetworkError else {
        return error.localizedDescription
    }
    switch networkError {
    case .serverError(_, let message):
        return message.isEmpty ? "Что-то пошло не так" : message
    default:
        return networkError.errorDescription ?? "Что-то пошло не так"
    }
}

/// Клиентка для рассылки: только то, что нужно показать в списке
struct BCTarget: Identifiable, Hashable {
    let id: Int
    let name: String
    let hasTelegram: Bool
}

/// Набор клиенток под фильтр списка — правила берём из ClientsViewModel
struct BCRecipientGroup: Identifiable {
    let filter: CLClientFilter
    let targets: [BCTarget]

    var id: String { filter.rawValue }
}

// MARK: - Свободные окна

/// Период, за который мастер хочет посмотреть окна
enum FWPeriod: String, CaseIterable, Identifiable {
    case today
    case tomorrow
    case thisWeek
    case nextWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:    return "Сегодня"
        case .tomorrow: return "Завтра"
        case .thisWeek: return "Эта неделя"
        case .nextWeek: return "След. неделя"
        }
    }

    /// Даты периода: «Эта неделя» — сегодня…воскресенье, «След. неделя» — пн…вс
    func range(calendar: Calendar, now: Date) -> FWDateRange {
        let start: Date = calendar.startOfDay(for: now)
        let weekday: Int = calendar.component(.weekday, from: start)
        switch self {
        case .today:
            return FWDateRange(from: start, to: start)
        case .tomorrow:
            let next: Date = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return FWDateRange(from: next, to: next)
        case .thisWeek:
            let daysToSunday: Int = (7 - weekday) % 7
            let end: Date = calendar.date(byAdding: .day, value: daysToSunday, to: start) ?? start
            return FWDateRange(from: start, to: end)
        case .nextWeek:
            let raw: Int = (2 - weekday + 7) % 7
            let daysToMonday: Int = raw == 0 ? 7 : raw
            let monday: Date = calendar.date(byAdding: .day, value: daysToMonday, to: start) ?? start
            let sunday: Date = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
            return FWDateRange(from: monday, to: sunday)
        }
    }
}

struct FWDateRange {
    let from: Date
    let to: Date
}

/// Дата в формате «yyyy-MM-dd» — тот же, что ждёт сервер
func fwDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

/// Лист «Поделиться окнами»: текст со свободными окнами для Telegram
struct FWShareSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var period: FWPeriod = .thisWeek
    @State private var duration: Int = 0
    @State private var services: [Service] = []
    @State private var slots: [FreeWindowsDay] = []
    @State private var draft: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isCopied: Bool = false
    @State private var loadToken: Int = 0

    /// Есть ли хоть одно окно — от этого зависит редактор и кнопки
    private var hasWindows: Bool {
        slots.contains { !(($0.slots ?? []).isEmpty) }
    }

    var body: some View {
        ZStack {
            theme.backgroundDeep
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    periodSection
                    serviceSection
                    previewSection
                    hintText
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .task {
            await loadServices()
        }
        .task(id: loadToken) {
            await loadWindows()
        }
        .overlay(alignment: .bottom) {
            if isCopied {
                toastView(text: "Скопировано")
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            Text("Свободные окна")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer(minLength: 8)
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
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Период

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Период")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 108, maximum: 220), spacing: 8)],
                spacing: 8
            ) {
                ForEach(FWPeriod.allCases) { item in
                    SVPill(title: item.title, isSelected: period == item, theme: theme) {
                        selectPeriod(item)
                    }
                }
            }
        }
    }

    private func selectPeriod(_ item: FWPeriod) {
        guard period != item else { return }
        HapticManager.selection()
        withAnimation(reduceMotion ? nil : DS.springSnappy) {
            period = item
        }
        loadToken += 1
    }

    // MARK: - Услуга

    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Под услугу")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 108, maximum: 220), spacing: 8)],
                spacing: 8
            ) {
                SVPill(title: "Любая", isSelected: duration == 0, theme: theme) {
                    selectDuration(0)
                }
                ForEach(services, id: \.id) { service in
                    SVPill(
                        title: service.name,
                        isSelected: duration == service.durationMin,
                        theme: theme
                    ) {
                        selectDuration(service.durationMin)
                    }
                }
            }
        }
    }

    private func selectDuration(_ minutes: Int) {
        guard duration != minutes else { return }
        HapticManager.selection()
        withAnimation(reduceMotion ? nil : DS.springSnappy) {
            duration = minutes
        }
        loadToken += 1
    }

    private func loadServices() async {
        guard let response: ServicesResponse = try? await APIClient.shared.request(
            .services,
            as: ServicesResponse.self
        ) else { return }
        services = response.services
    }

    // MARK: - Предпросмотр

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Текст для Telegram")
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
            } else if !hasWindows {
                Text("На выбранные дни свободных окон нет")
                    .font(.system(size: 15))
                    .foregroundColor(theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .frame(minHeight: 160, alignment: .topLeading)
                    .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: DS.r16))
            } else {
                TextEditor(text: $draft)
                    .font(.system(size: 15))
                    .foregroundColor(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 160)
                    .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: DS.r16))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.r16)
                            .stroke(theme.borderSubtle, lineWidth: 1)
                    )
            }
            if let errorMessage = errorMessage {
                BBErrorBanner(message: errorMessage)
            }
        }
    }

    // MARK: - Кнопки

    private var hintText: some View {
        Text("Выберите в Telegram свой канал или чат с клиентками")
            .font(.system(size: 12))
            .foregroundColor(theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            ShareLink(item: draft) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Поделиться")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(theme.gradientPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DS.r16, style: .continuous))
            }
            .buttonStyle(CLPressStyle(scale: 0.97))
            .disabled(!hasWindows)
            .opacity(hasWindows ? 1 : 0.4)

            Button {
                copyText()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Скопировать")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(theme.backgroundInput)
                .clipShape(RoundedRectangle(cornerRadius: DS.r16, style: .continuous))
            }
            .buttonStyle(CLPressStyle(scale: 0.97))
            .disabled(!hasWindows)
            .opacity(hasWindows ? 1 : 0.4)
        }
    }

    private func copyText() {
        UIPasteboard.general.string = draft
        HapticManager.success()
        withAnimation(reduceMotion ? nil : DS.springSnappy) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(reduceMotion ? nil : DS.springSnappy) { isCopied = false }
        }
    }

    // MARK: - Загрузка

    private func loadWindows() async {
        isLoading = true
        errorMessage = nil
        let range: FWDateRange = period.range(calendar: Calendar.current, now: Date())
        do {
            let response: FreeWindowsResponse = try await APIClient.shared.request(
                .freeWindows(
                    dateFrom: fwDateString(range.from),
                    dateTo: fwDateString(range.to),
                    duration: duration
                ),
                as: FreeWindowsResponse.self
            )
            slots = response.days ?? []
            draft = response.text ?? ""
        } catch {
            slots = []
            draft = ""
            errorMessage = bcErrorText(error)
        }
        isLoading = false
    }

    // MARK: - Мелочи

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textMuted)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func toastView(text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(theme.backgroundCard, in: Capsule())
            .overlay(Capsule().stroke(theme.borderSubtle, lineWidth: 1))
            .transition(.opacity)
    }
}

// MARK: - Рассылка: аудитория и шаблоны

enum BCAudience: String, CaseIterable, Identifiable {
    case all
    case away
    case new
    case birthday
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:      return "Все"
        case .away:     return "Давно не были"
        case .new:      return "Новые"
        case .birthday: return "День рождения"
        case .custom:   return "Выбрать"
        }
    }

    /// Соответствующий фильтр списка клиентов
    var filter: CLClientFilter? {
        switch self {
        case .all:      return nil
        case .away:     return .away
        case .new:      return .new
        case .birthday: return .birthday
        case .custom:   return nil
        }
    }
}

enum BCTemplate: String, CaseIterable, Identifiable {
    case freeWindows
    case promo
    case newService
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .freeWindows: return "Свободные окна"
        case .promo:       return "Акция"
        case .newService:  return "Новая услуга"
        case .custom:      return "Своё"
        }
    }

    /// Текст шаблона, который подставляем в редактор
    func text(freeWindows: String) -> String {
        switch self {
        case .freeWindows: return freeWindows
        case .promo:       return "Только на этой неделе — скидка 15% на [услугу]. Записывайтесь по кнопке ниже 💅"
        case .newService:  return "Теперь делаю [услугу]! Первые записи — по особой цене. Записывайтесь по кнопке ниже 💅"
        case .custom:      return ""
        }
    }
}

/// Лист «Рассылка клиенткам»
struct BCComposeSheet: View {
    let allTargets: [BCTarget]
    let groups: [BCRecipientGroup]

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var audience: BCAudience = .all
    @State private var customIds: Set<Int> = []
    @State private var template: BCTemplate = .freeWindows
    @State private var text: String = ""
    @State private var freeWindowsText: String = ""
    @State private var preview: BroadcastPreviewResponse?
    @State private var isPreviewLoading: Bool = false
    @State private var isSending: Bool = false
    @State private var isSent: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showConfirm: Bool = false
    @State private var showPicker: Bool = false
    @State private var showHistory: Bool = false
    @State private var isAskingConsent: Bool = false
    @State private var consentAsked: Bool = false
    @State private var toastText: String? = nil

    private let maxTextLength: Int = 1500

    /// Кого выбрали — по тем же правилам, что у фильтров списка клиентов
    private var selectedIds: [Int] {
        if audience == .custom { return customIds.sorted() }
        if let filter: CLClientFilter = audience.filter {
            return groups.first(where: { $0.filter == filter })?.targets.map { $0.id } ?? []
        }
        return allTargets.map { $0.id }
    }

    private var willReceive: Int {
        preview?.willReceive ?? 0
    }

    private var canSend: Bool {
        willReceive > 0
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.count <= maxTextLength
    }

    var body: some View {
        ZStack {
            theme.backgroundDeep
                .ignoresSafeArea()

            if isSent {
                sentView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        audienceSection
                        previewCountSection
                        textSection
                        bubblePreview
                        actions
                        historyLink
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .task {
            await loadFreeWindowsText()
            applyTemplate(.freeWindows)
            await refreshPreview()
        }
        .onChange(of: audience) { _, _ in
            Task { await refreshPreview() }
        }
        .onChange(of: customIds) { _, _ in
            Task { await refreshPreview() }
        }
        .sheet(isPresented: $showPicker) {
            BCClientPickerSheet(targets: allTargets, selectedIds: $customIds)
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showHistory) {
            BCHistorySheet()
                .environment(\.theme, theme)
        }
        .confirmationDialog(
            "Отправить рассылку \(willReceive) клиенткам? Следующая — только завтра",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Отправить") { send() }
            Button("Отмена", role: .cancel) {}
        }
        .overlay(alignment: .bottom) {
            if let toastText = toastText {
                Text(toastText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(theme.backgroundCard, in: Capsule())
                    .overlay(Capsule().stroke(theme.borderSubtle, lineWidth: 1))
                    .padding(.bottom, 32)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            Text("Рассылка клиенткам")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer(minLength: 8)
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
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Кому

    private var audienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Кому")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 108, maximum: 220), spacing: 8)],
                spacing: 8
            ) {
                ForEach(BCAudience.allCases) { item in
                    SVPill(title: item.title, isSelected: audience == item, theme: theme) {
                        selectAudience(item)
                    }
                }
            }
        }
    }

    private func selectAudience(_ item: BCAudience) {
        guard audience != item else { return }
        HapticManager.selection()
        withAnimation(reduceMotion ? nil : DS.springSnappy) {
            audience = item
        }
        errorMessage = nil
        if item == .custom { showPicker = true }
    }

    // MARK: - Сколько получат

    private var previewCountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isPreviewLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                Text("Получат: \(willReceive)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text(exclusionText)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let notAsked: Int = preview?.notAsked, notAsked > 0, !consentAsked {
                consentCard(notAsked: notAsked)
            }
        }
    }

    private var exclusionText: String {
        let noTelegram: Int = preview?.noTelegram ?? 0
        let noConsent: Int = preview?.noConsent ?? 0
        return "Без Telegram: \(noTelegram) · Не дали согласие на акции: \(noConsent)"
    }

    private func consentCard(notAsked: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(notAsked) клиенток ещё не спрашивали, хотят ли они получать акции")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                askConsent()
            } label: {
                Text(isAskingConsent ? "Спрашиваем…" : "Спросить у них")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: DS.r12))
                    .contentShape(RoundedRectangle(cornerRadius: DS.r12))
            }
            .buttonStyle(CLPressStyle(scale: 0.97))
            .disabled(isAskingConsent)
        }
        .padding(14)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: DS.r16))
    }

    // MARK: - Текст

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Текст")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 108, maximum: 220), spacing: 8)],
                spacing: 8
            ) {
                ForEach(BCTemplate.allCases) { item in
                    SVPill(title: item.title, isSelected: template == item, theme: theme) {
                        selectTemplate(item)
                    }
                }
            }
            TextEditor(text: $text)
                .font(.system(size: 15))
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 140)
                .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: DS.r16))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r16)
                        .stroke(theme.borderSubtle, lineWidth: 1)
                )
            HStack {
                Spacer(minLength: 0)
                Text("\(text.count) / \(maxTextLength)")
                    .font(.system(size: 12))
                    .foregroundColor(text.count > maxTextLength ? theme.statusRed : theme.textMuted)
            }
        }
    }

    private func selectTemplate(_ item: BCTemplate) {
        guard template != item else { return }
        HapticManager.selection()
        withAnimation(reduceMotion ? nil : DS.springSnappy) {
            template = item
        }
        applyTemplate(item)
    }

    private func applyTemplate(_ item: BCTemplate) {
        text = item.text(freeWindows: freeWindowsText)
    }

    // MARK: - Пузырь

    private var bubblePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                Text(text.isEmpty ? "Текст рассылки появится здесь" : text)
                    .font(.system(size: 15))
                    .foregroundColor(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text("💅 Записаться")
                    Text("Не присылать акции")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
            Text("Так увидит клиентка")
                .font(.system(size: 12))
                .foregroundColor(theme.textMuted)
        }
    }

    // MARK: - Кнопки

    private var actions: some View {
        VStack(spacing: 8) {
            if let errorMessage = errorMessage {
                BBErrorBanner(message: errorMessage)
            }
            BBPrimaryButton(
                title: "Отправить \(willReceive) клиенткам",
                isLoading: isSending,
                isDisabled: !canSend
            ) {
                showConfirm = true
            }
            historyLink
        }
    }

    private var historyLink: some View {
        Button {
            showHistory = true
        } label: {
            Text("История рассылок")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Экран отправки

    private var sentView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(theme.statusGreen)
            Text("✓ Рассылка отправляется")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Клиентки получат её в Telegram. Сервер отправляет сообщения по очереди.")
                .font(.system(size: 14))
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 24)
            BBPrimaryButton(title: "Готово") {
                dismiss()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Запросы

    private func loadFreeWindowsText() async {
        let range: FWDateRange = FWPeriod.thisWeek.range(calendar: Calendar.current, now: Date())
        guard let response: FreeWindowsResponse = try? await APIClient.shared.request(
            .freeWindows(
                dateFrom: fwDateString(range.from),
                dateTo: fwDateString(range.to),
                duration: 0
            ),
            as: FreeWindowsResponse.self
        ) else { return }
        freeWindowsText = response.text ?? ""
        if template == .freeWindows { text = freeWindowsText }
    }

    private func refreshPreview() async {
        let ids: [Int] = selectedIds
        guard !ids.isEmpty else {
            preview = nil
            return
        }
        isPreviewLoading = true
        do {
            preview = try await APIClient.shared.request(
                .broadcastPreview(BroadcastPreviewRequest(clientIds: ids)),
                as: BroadcastPreviewResponse.self
            )
        } catch {
            preview = nil
            errorMessage = bcErrorText(error)
        }
        isPreviewLoading = false
    }

    private func askConsent() {
        isAskingConsent = true
        Task {
            do {
                let response: AskConsentResponse = try await APIClient.shared.request(
                    .askBroadcastConsent,
                    as: AskConsentResponse.self
                )
                isAskingConsent = false
                consentAsked = true
                showToast(text: "Отправили вопрос \(response.asked ?? 0) клиенткам")
                await refreshPreview()
            } catch {
                isAskingConsent = false
                errorMessage = bcErrorText(error)
            }
        }
    }

    private func send() {
        isSending = true
        errorMessage = nil
        Task {
            do {
                let _: BroadcastSendResponse = try await APIClient.shared.request(
                    .sendBroadcast(BroadcastSendRequest(clientIds: selectedIds, text: text)),
                    as: BroadcastSendResponse.self
                )
                isSending = false
                isSent = true
                HapticManager.success()
            } catch {
                isSending = false
                errorMessage = bcErrorText(error)
                HapticManager.error()
            }
        }
    }

    private func showToast(text: String) {
        withAnimation(reduceMotion ? nil : DS.springSnappy) { toastText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(reduceMotion ? nil : DS.springSnappy) { toastText = nil }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textMuted)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

// MARK: - Выбор клиенток

/// Список клиенток с галочками для ручного выбора
struct BCClientPickerSheet: View {
    let targets: [BCTarget]
    @Binding var selectedIds: Set<Int>

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            theme.backgroundDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(targets) { target in
                            row(target)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                BBPrimaryButton(title: "Готово") {
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    private var header: some View {
        HStack {
            Text("Выбрать клиенток")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer(minLength: 8)
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
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func row(_ target: BCTarget) -> some View {
        Button {
            HapticManager.selection()
            if selectedIds.contains(target.id) {
                selectedIds.remove(target.id)
            } else {
                selectedIds.insert(target.id)
            }
        } label: {
            HStack(spacing: 12) {
                CLAvatar(
                    name: target.name,
                    size: 36,
                    dotSize: 10,
                    hasTelegram: target.hasTelegram,
                    theme: theme
                )
                Text(target.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: selectedIds.contains(target.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selectedIds.contains(target.id) ? theme.accent : theme.textMuted)
            }
            .padding(12)
            .frame(minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(selectedIds.contains(target.id) ? theme.accent.opacity(0.12) : theme.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(CLPressStyle(scale: 0.98))
    }
}

// MARK: - История рассылок

struct BCHistorySheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var records: [BroadcastRecord] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            theme.backgroundDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if records.isEmpty {
                            Text("Рассылок пока не было")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(records) { record in
                                row(record)
                            }
                        }
                        if let errorMessage = errorMessage {
                            BBErrorBanner(message: errorMessage)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .task {
            await load()
        }
    }

    private var header: some View {
        HStack {
            Text("История рассылок")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer(minLength: 8)
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
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func row(_ record: BroadcastRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dateText(record.createdAt))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                Spacer(minLength: 8)
                Text("Доставлено \(record.delivered ?? 0) из \(record.total ?? 0)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.statusGreen)
            }
            Text(twoLines(record.text))
                .font(.system(size: 14))
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
    }

    /// «4 окт, 18:00» — если формат неожиданный, показываем как есть
    private func dateText(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "" }
        let formats: [String] = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"]
        var parsed: Date?
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = format
            if let date: Date = formatter.date(from: raw) {
                parsed = date
                break
            }
        }
        guard let date: Date = parsed else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "d MMM, HH:mm"
        return out.string(from: date)
    }

    private func twoLines(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "—" }
        return raw.split(separator: "\n", omittingEmptySubsequences: false).prefix(2).joined(separator: "\n")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: BroadcastsResponse = try await APIClient.shared.request(
                .broadcasts,
                as: BroadcastsResponse.self
            )
            records = response.broadcasts ?? []
        } catch {
            records = []
            errorMessage = bcErrorText(error)
        }
        isLoading = false
    }
}