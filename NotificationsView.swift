import SwiftUI

// MARK: - ViewModel

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        if let resp = try? await api.request(.notifications, as: NotificationsResponse.self) {
            notifications = resp.notifications
        }
        isLoading = false
    }

    func refreshUnread() async {
        if let resp = try? await api.request(.unreadCount, as: UnreadCountResponse.self) {
            unreadCount = resp.count
        }
    }

    func markRead(_ id: Int) async {
        let _ = try? await api.request(.markRead(id: id), as: MessageResponse.self)
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            let n = notifications[idx]
            notifications[idx] = AppNotification(
                id: n.id, type: n.type, title: n.title, body: n.body,
                isRead: true, createdAt: n.createdAt,
                appointmentId: n.appointmentId, appointment: n.appointment
            )
        }
        if unreadCount > 0 { unreadCount -= 1 }
    }

    func markAllRead() async {
        let _ = try? await api.request(.markAllRead, as: MessageResponse.self)
        notifications = notifications.map {
            AppNotification(id: $0.id, type: $0.type, title: $0.title, body: $0.body,
                            isRead: true, createdAt: $0.createdAt,
                            appointmentId: $0.appointmentId, appointment: $0.appointment)
        }
        unreadCount = 0
    }

    func updateAppointmentStatus(apptId: Int, status: AppointmentStatus) async -> Bool {
        let result = try? await api.request(.updateAppointmentStatus(id: apptId, status: status.rawValue), as: MessageResponse.self)
        return result != nil
    }

    func updateLocalApptStatus(notifId: Int, status: String) {
        guard let idx = notifications.firstIndex(where: { $0.id == notifId }) else { return }
        let n = notifications[idx]
        let updatedAppt = n.appointment.map {
            AppNotificationAppt(procedure: $0.procedure, date: $0.date, time: $0.time,
                                status: status, clientName: $0.clientName, clientPhone: $0.clientPhone)
        }
        notifications[idx] = AppNotification(id: n.id, type: n.type, title: n.title, body: n.body,
                                             isRead: true, createdAt: n.createdAt,
                                             appointmentId: n.appointmentId, appointment: updatedAppt)
    }
}

// MARK: - Bell Button

struct NotificationBellButton: View {
    @ObservedObject var vm: NotificationsViewModel
    @Binding var isPresented: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: { isPresented = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(theme.textPrimary)
                if vm.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 18, height: 18)
                        Text(vm.unreadCount > 99 ? "99+" : "\(vm.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: -8)
                }
            }
            // Увеличенная и явная тач-зона (Apple HIG: минимум 44x44),
            // иначе на вкладках с плотным контентом рядом (Расписание,
            // Клиенты и т.д.) палец промахивается мимо крошечной иконки
            // и тап "съедает" скролл/контент под кнопкой.
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .zIndex(10)
    }
}

struct HeaderBellButton: View {
    @EnvironmentObject var vm: NotificationsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            HapticManager.light()
            NotificationCenter.default.post(name: .openNotificationsSheet, object: nil)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 18))
                    .foregroundColor(theme.textPrimary)

                if vm.unreadCount > 0 {
                    Text(vm.unreadCount > 99 ? "99+" : "\(vm.unreadCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 18, minHeight: 18, maxHeight: 18)
                        .background(theme.accent, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(theme.backgroundDeep, lineWidth: 2)
                        )
                        .offset(x: 8, y: -8)
                }
            }
            .frame(width: 44, height: 44)
            .background(theme.backgroundCard, in: Circle())
            .overlay(
                Circle()
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Уведомления")
    }
}

// MARK: - Фильтры

/// Фильтры шторки уведомлений. Типы приходят с сервера: new_booking, client_reschedule, client_cancel, broadcast.
enum NTFilter: String, CaseIterable {
    case all
    case bookings
    case pending

    var title: String {
        switch self {
        case .all: return "Все"
        case .bookings: return "Записи"
        case .pending: return "Ждут ответа"
        }
    }

    /// Пустое состояние именно для этого фильтра.
    var emptyKind: NTEmptyKind {
        switch self {
        case .all: return .silent
        case .bookings: return .plain
        case .pending: return .done
        }
    }

    func matches(_ notif: AppNotification) -> Bool {
        switch self {
        case .all:
            return true
        case .bookings:
            return notif.type == "new_booking"
                || notif.type == "client_reschedule"
                || notif.type == "client_cancel"
        case .pending:
            return NTFormat.isActionable(notif)
        }
    }
}

/// Виды пустых состояний шторки
enum NTEmptyKind {
    /// Уведомлений нет вообще
    case silent
    /// Под выбранный фильтр ничего не подошло
    case plain
    /// Все записи обработаны
    case done
}

// MARK: - Форматирование дат и текстов

enum NTFormat {
    /// Разбор createdAt: ISO8601 (с дробной частью и без) и запасной "yyyy-MM-dd HH:mm:ss"
    static func date(from raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fallback.date(from: raw)
    }

    /// Заголовок группы: «Сегодня», «Вчера», «24 сентября», «24 сентября 2025»
    static func groupTitle(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Сегодня" }
        if calendar.isDateInYesterday(date) { return "Вчера" }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
        return sameYear ? dayMonth.string(from: date) : dayMonthYear.string(from: date)
    }

    /// Время под текстом: «8 мин назад», «2 ч назад» для сегодня, иначе «18:00»
    static func timeAgo(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let seconds = Int(now.timeIntervalSince(date))
            if seconds < 60 { return "только что" }
            if seconds < 3600 { return "\(seconds / 60) мин назад" }
            return "\(seconds / 3600) ч назад"
        }
        return clock.string(from: date)
    }

    /// Дата записи из строки "yyyy-MM-dd" → «Пт, 26 сентября»
    static func appointmentDay(_ raw: String?) -> String {
        guard let raw, let date = appointmentDate(raw) else { return raw ?? "" }
        return capitalizeFirst(weekdayDayMonth.string(from: date))
    }

    /// Разбор даты записи "yyyy-MM-dd"
    static func appointmentDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    /// Запись ждёт ответа мастера: онлайн-запись или перенос со статусом pending
    static func isActionable(_ notif: AppNotification) -> Bool {
        guard notif.type == "new_booking" || notif.type == "client_reschedule" else { return false }
        return notif.appointment?.status == "pending"
    }

    /// Первая буква заглавная: «пт, 26 сентября» → «Пт, 26 сентября»
    static func capitalizeFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).uppercased() + String(value.dropFirst())
    }

    private static let weekdayDayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEE, d MMMM"
        return f
    }()

    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    private static let dayMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Группа уведомлений

/// Группа одного дня: заголовок + строки с порядковым номером для staggered-появления
struct NTGroup: Identifiable {
    let id: String
    let title: String
    let items: [NTItem]
}

/// Строка уведомления внутри группы
struct NTItem: Identifiable {
    let index: Int
    let notif: AppNotification

    var id: Int { notif.id }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    @ObservedObject var vm: NotificationsViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var filter: NTFilter = .all
    @State private var processingId: Int? = nil
    @State private var errorId: Int? = nil
    @State private var rejectTarget: AppNotification? = nil

    // MARK: Тело

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                filtersRow
                content
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        // Больше не помечаем всё прочитанным при открытии: точки непрочитанных
        // должны быть видны, пока мастер их не прочитает.
        .onAppear {
            Task { await vm.load() }
        }
        .confirmationDialog(
            "Отклонить запись?",
            isPresented: Binding(
                get: { rejectTarget != nil },
                set: { if !$0 { rejectTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Отклонить", role: .destructive) {
                guard let target = rejectTarget else { return }
                rejectTarget = nil
                reject(target)
            }
            Button("Отмена", role: .cancel) { rejectTarget = nil }
        } message: {
            if let appt = rejectTarget?.appointment {
                Text("\(appt.clientName ?? "") · \(NTFormat.appointmentDay(appt.date)) в \(appt.time ?? "")")
            }
        }
    }

    // MARK: Шапка

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Уведомления")
                .font(DS.titleSmall.weight(.bold))
                .foregroundColor(theme.textPrimary)
            Spacer()
            if vm.unreadCount > 0 {
                Button {
                    Task {
                        await vm.markAllRead()
                        HapticManager.success()
                    }
                } label: {
                    Text("Прочитать все")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(CLPressStyle())
            }
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var closeButton: some View {
        Button {
            HapticManager.light()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .frame(width: 44, height: 44)
                .background(theme.backgroundInput, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(CLPressStyle())
        .accessibilityLabel("Закрыть")
    }

    // MARK: Фильтры

    private var filtersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NTFilter.allCases, id: \.self) { item in
                    NTFilterChip(
                        title: item.title,
                        count: chipCount(for: item),
                        isSelected: filter == item
                    ) {
                        selectFilter(item)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    /// Счётчик показываем только у «Ждут ответа» и только когда он больше нуля
    private func chipCount(for item: NTFilter) -> Int? {
        guard item == .pending else { return nil }
        let value = vm.notifications.filter { item.matches($0) }.count
        return value > 0 ? value : nil
    }

    private func selectFilter(_ item: NTFilter) {
        guard filter != item else { return }
        HapticManager.selection()
        withAnimation(DS.springSnappy) {
            filter = item
        }
    }

    // MARK: Содержимое

    @ViewBuilder
    private var content: some View {
        if visibleNotifications.isEmpty {
            emptyState
        } else {
            list
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if vm.isLoading && vm.notifications.isEmpty {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            NTEmptyState(kind: filter.emptyKind)
        }
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.title.uppercased())
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.textMuted)
                        ForEach(group.items) { item in
                            NTStaggeredRow(index: item.index) {
                                NTRow(
                                    notif: item.notif,
                                    isProcessing: processingId == item.id,
                                    errorText: errorId == item.id ? "Не получилось, попробуй ещё раз" : nil,
                                    onTap: { tap(item.notif) },
                                    onConfirm: { confirm(item.notif) },
                                    onReject: { rejectTarget = item.notif }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 32)
        }
        .refreshable {
            await vm.load()
            await vm.refreshUnread()
        }
        .animation(DS.springSmooth, value: vm.unreadCount)
    }

    // MARK: Группировка по дням

    private var visibleNotifications: [AppNotification] {
        vm.notifications
            .filter { filter.matches($0) }
            .sorted { lhs, rhs in
                let left = NTFormat.date(from: lhs.createdAt) ?? Date.distantPast
                let right = NTFormat.date(from: rhs.createdAt) ?? Date.distantPast
                return left > right
            }
    }

    private var groups: [NTGroup] {
        var titles: [String] = []
        var buckets: [[NTItem]] = []
        var counter = 0
        for notif in visibleNotifications {
            let date = NTFormat.date(from: notif.createdAt) ?? Date()
            let title = NTFormat.groupTitle(for: date)
            let item = NTItem(index: counter, notif: notif)
            counter += 1
            if let last = titles.indices.last, titles[last] == title {
                buckets[last].append(item)
            } else {
                titles.append(title)
                buckets.append([item])
            }
        }
        var result: [NTGroup] = []
        for (position, bucket) in buckets.enumerated() {
            let title = titles[position]
            result.append(NTGroup(id: "\(position)-\(title)", title: title, items: bucket))
        }
        return result
    }

    // MARK: Действия

    /// Нажатие на саму карточку: отмечаем прочитанным, если ещё не прочитано
    private func tap(_ notif: AppNotification) {
        guard !notif.isRead else { return }
        HapticManager.selection()
        Task { await vm.markRead(notif.id) }
    }

    /// Подтверждение записи без alert: спиннер → запрос → плашка «✓ Подтверждено»
    private func confirm(_ notif: AppNotification) {
        guard let apptId = notif.appointmentId else { return }
        processingId = notif.id
        errorId = nil
        Task {
            let ok = await vm.updateAppointmentStatus(apptId: apptId, status: .confirmed)
            if ok {
                vm.updateLocalApptStatus(notifId: notif.id, status: "confirmed")
                if !notif.isRead { await vm.markRead(notif.id) }
                HapticManager.success()
            } else {
                errorId = notif.id
                HapticManager.error()
            }
            processingId = nil
        }
    }

    /// Отклонение записи после подтверждения в диалоге
    private func reject(_ notif: AppNotification) {
        guard let apptId = notif.appointmentId else { return }
        processingId = notif.id
        errorId = nil
        Task {
            let ok = await vm.updateAppointmentStatus(apptId: apptId, status: .cancelled)
            if ok {
                vm.updateLocalApptStatus(notifId: notif.id, status: "cancelled")
                if !notif.isRead { await vm.markRead(notif.id) }
            } else {
                errorId = notif.id
                HapticManager.error()
            }
            processingId = nil
        }
    }
}

// MARK: - Строка уведомления

struct NTRow: View {
    let notif: AppNotification
    let isProcessing: Bool
    let errorText: String?
    let onTap: () -> Void
    let onConfirm: () -> Void
    let onReject: () -> Void

    @Environment(\.theme) private var theme

    /// Запись из уведомления, если сервер её прислал
    private var appt: AppNotificationAppt? { notif.appointment }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                headerContent
            }
            .buttonStyle(CLPressStyle())
            if let appt, notif.type == "new_booking" || notif.type == "client_reschedule" {
                actionArea(for: appt)
            }
            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundColor(theme.statusRed)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(notif.isRead ? theme.backgroundCard : theme.accent.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(notif.isRead ? theme.borderSubtle : theme.accent.opacity(0.25), lineWidth: 1)
        )
        .animation(DS.springSnappy, value: appt?.status)
    }

    // MARK: Шапка строки

    private var headerContent: some View {
        HStack(alignment: .top, spacing: 12) {
            iconBubble
            VStack(alignment: .leading, spacing: 4) {
                if let appt {
                    Text(appt.clientName ?? notif.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text(actionSentence(for: appt))
                        .font(.system(size: 14))
                        .foregroundColor(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(notif.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text(notif.body)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(timeText)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textMuted)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            if !notif.isRead {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
    }

    private var iconBubble: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
        }
    }

    private var iconName: String {
        switch notif.type {
        case "new_booking": return "calendar.badge.plus"
        case "client_reschedule": return "arrow.triangle.2.circlepath"
        case "client_cancel": return "xmark"
        case "broadcast": return "sparkles"
        default: return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch notif.type {
        case "new_booking": return theme.statusYellow
        case "client_cancel": return theme.statusRed
        case "client_reschedule": return theme.accent
        case "broadcast": return theme.accent
        default: return theme.accent
        }
    }

    // MARK: Тексты

    /// Фраза по типу уведомления: записалась / перенесла / отменила
    private func actionSentence(for appt: AppNotificationAppt) -> String {
        let day = NTFormat.appointmentDay(appt.date)
        let time = appt.time ?? ""
        let when = time.isEmpty ? day : "\(day), \(time)"
        let procedure = (appt.procedure ?? "").trimmingCharacters(in: .whitespaces)
        let tail = procedure.isEmpty ? "" : " \(procedure)."
        switch notif.type {
        case "new_booking":
            return "записалась онлайн на \(when).\(tail)"
        case "client_reschedule":
            return "перенесла запись на \(when).\(tail)"
        case "client_cancel":
            return "отменила запись на \(when). Окно снова свободно для онлайн-записи."
        default:
            return notif.body
        }
    }

    private var timeText: String {
        guard let date = NTFormat.date(from: notif.createdAt) else { return "" }
        return NTFormat.timeAgo(for: date)
    }

    // MARK: Действия с записью

    @ViewBuilder
    private func actionArea(for appt: AppNotificationAppt) -> some View {
        if appt.status == "pending" {
            actionButtons
        } else if appt.status == "confirmed" {
            NTStatusBadge(title: "Подтверждено", icon: "checkmark", color: theme.statusGreen)
        } else if appt.status == "cancelled" {
            NTStatusBadge(title: "Отклонено", icon: nil, color: theme.textMuted)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            confirmButton
            rejectButton
        }
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            ZStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text("Подтвердить")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(theme.gradientPrimary, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.97))
        .disabled(isProcessing)
    }

    private var rejectButton: some View {
        Button(action: onReject) {
            Text("Отклонить")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.statusRed)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(theme.statusRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.97))
        .disabled(isProcessing)
    }
}

// MARK: - Плашка статуса записи

struct NTStatusBadge: View {
    let title: String
    let icon: String?
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15), in: Capsule())
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

// MARK: - Чип-фильтр

struct NTFilterChip: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)
                if let count {
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
            // +8 по вертикали: визуально чип 36 pt, а палец попадает в 44 pt
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(CLPressStyle(scale: 0.94))
    }
}

// MARK: - Пустое состояние

struct NTEmptyState: View {
    let kind: NTEmptyKind

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            iconBubble
            Text(title)
                .font(DS.titleSmall.weight(.semibold))
                .foregroundColor(theme.textPrimary)
            Text(subtitle)
                .font(DS.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconBubble: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.14))
                .frame(width: 64, height: 64)
            Image(systemName: iconName)
                .font(.system(size: 26))
                .foregroundColor(iconColor)
        }
    }

    private var iconName: String {
        switch kind {
        case .silent: return "bell"
        case .plain: return "line.3.horizontal.decrease"
        case .done: return "checkmark.circle"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .silent: return theme.accent
        case .plain: return theme.textMuted
        case .done: return theme.statusGreen
        }
    }

    private var title: String {
        switch kind {
        case .silent: return "Пока тихо"
        case .plain: return "Здесь пока пусто"
        case .done: return "Все записи обработаны"
        }
    }

    private var subtitle: String {
        switch kind {
        case .silent: return "Здесь появятся онлайн-записи, переносы и отмены."
        case .plain: return "Попробуй другой фильтр."
        case .done: return "Новые записи появятся здесь."
        }
    }
}

// MARK: - Появление строк по очереди

struct NTStaggeredRow<Content: View>: View {
    let index: Int
    private let content: () -> Content

    init(index: Int, @ViewBuilder content: @escaping () -> Content) {
        self.index = index
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
                guard !reduceMotion else {
                    appeared = true
                    return
                }
                let delay = min(Double(index) * 0.04, 0.3)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    appeared = true
                }
            }
    }

    private var verticalOffset: CGFloat {
        if appeared || reduceMotion { return 0 }
        return 10
    }

    private var animation: Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        return DS.springSmooth.delay(min(Double(index) * 0.04, 0.3))
    }
}
