import SwiftUI
import UIKit

// MARK: - Helpers

fileprivate func naMinutes(_ time: String) -> Int? {
    let parts = time.split(separator: ":")
    guard let hour = Int(parts.first ?? ""),
          let minute = Int(parts.count > 1 ? parts[1] : "0"),
          (0..<24).contains(hour),
          (0..<60).contains(minute) else { return nil }
    return hour * 60 + minute
}

fileprivate func naTimeString(_ totalMinutes: Int) -> String {
    let normalized = max(0, totalMinutes)
    return String(format: "%02d:%02d", normalized / 60, normalized % 60)
}

fileprivate func naDayKey(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

fileprivate func naCapitalized(_ value: String) -> String {
    guard let first = value.first else { return value }
    return String(first).uppercased() + String(value.dropFirst())
}

fileprivate func naRub(_ value: Int) -> String {
    let digits = String(max(value, 0))
    var grouped = ""
    for (index, character) in digits.enumerated() {
        if index > 0 && (digits.count - index) % 3 == 0 {
            grouped.append(" ")
        }
        grouped.append(character)
    }
    return grouped + " ₽"
}

fileprivate func naRoundToTen(_ value: Int) -> Int {
    Int((Double(max(value, 0)) / 10.0).rounded()) * 10
}

struct NewAppointmentInterval: Identifiable {
    let start: Int
    let end: Int

    var id: Int { start }

    static func merged(from appointments: [Appointment]) -> [NewAppointmentInterval] {
        let intervals: [NewAppointmentInterval] = appointments.compactMap { appointment in
            guard let start = naMinutes(appointment.time) else { return nil }
            let end = start + max(appointment.duration ?? 60, 0)
            guard end > start else { return nil }
            return NewAppointmentInterval(start: start, end: end)
        }
        .sorted { $0.start < $1.start }

        var merged: [NewAppointmentInterval] = []
        for interval in intervals {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = NewAppointmentInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}

struct NewAppointmentSlotSection: Identifiable {
    let title: String
    let times: [String]

    var id: String { title }
}

// MARK: - ViewModel

@MainActor
final class NewAppointmentViewModel: ObservableObject {
    @Published var selectedClient: Client? = nil
    @Published var selectedServices: [Service] = []
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var selectedTime: String = ""
    @Published var searchText: String = ""
    @Published var isAddingClient = false
    @Published var newClientName = ""
    @Published var newClientPhone = ""
    @Published var isNewClientNameValid = true
    @Published var nameErrorNonce = 0
    @Published var isCreatingClient = false
    @Published var priceInput = ""
    @Published var notes = ""
    @Published var isMoreOpen = false
    @Published var clients: [Client] = []
    @Published var services: [Service] = []
    @Published var profile: MasterProfile? = nil
    @Published var blockedDays: Set<String> = []
    @Published var workStart = 9
    @Published var workEnd = 20
    @Published var ribbonDays: [Date] = []
    @Published var dayBusyIntervals: [String: [NewAppointmentInterval]] = [:]
    @Published var serverSlots: [Int] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isSaved = false
    @Published var errorMessage: String? = nil

    var onCreated: (() -> Void)?

    private let api = APIClient.shared
    private let calendar = Calendar.current
    private let slotStep = 30
    private let slotGroupBounds: [(title: String, from: Int, to: Int)] = [
        ("Утро", 0, 720),
        ("День", 720, 1020),
        ("Вечер", 1020, 1440)
    ]

    // MARK: Totals

    var selectedDayKey: String { naDayKey(selectedDate) }

    var serviceDuration: Int { selectedServices.reduce(0) { $0 + max($1.durationMin, 0) } }

    var requiredDuration: Int { serviceDuration > 0 ? serviceDuration : 60 }

    var basePrice: Int { selectedServices.reduce(0) { $0 + max($1.priceDefault, 0) } }

    var isReady: Bool { selectedClient != nil && !selectedServices.isEmpty && !selectedTime.isEmpty }

    // MARK: Loyalty

    var loyaltyThreshold: Int {
        guard let threshold = profile?.loyaltyThreshold, threshold > 0 else { return 10 }
        return threshold
    }

    var clientVisitNumber: Int { (selectedClient?.appointmentsCount ?? 0) + 1 }

    var loyaltyPercent: Int {
        guard profile?.loyaltyDiscountEnabled == true,
              profile?.loyaltyDiscountType != "rub" else { return 0 }
        return max(profile?.loyaltyDiscountPercent ?? 0, 0)
    }

    var loyaltyRub: Int {
        guard profile?.loyaltyDiscountEnabled == true,
              profile?.loyaltyDiscountType == "rub" else { return 0 }
        return max(profile?.loyaltyDiscountRub ?? 0, 0)
    }

    var hasLoyaltyDiscount: Bool {
        guard clientVisitNumber % loyaltyThreshold == 0 else { return false }
        return loyaltyPercent > 0 || loyaltyRub > 0
    }

    var loyaltyLabel: String {
        if loyaltyRub > 0 { return "\(loyaltyRub) ₽" }
        return "\(loyaltyPercent)%"
    }

    var autoPrice: Int {
        let base = basePrice
        guard base > 0 else { return 0 }
        if hasLoyaltyDiscount {
            if loyaltyRub > 0 { return naRoundToTen(base - loyaltyRub) }
            return naRoundToTen(base - Int((Double(base) * Double(loyaltyPercent) / 100.0).rounded()))
        }
        return base
    }

    var displayPrice: Int { Int(priceInput) ?? autoPrice }

    var discountHint: String? {
        guard hasLoyaltyDiscount, basePrice > 0 else { return nil }
        return "Скидка \(loyaltyLabel) уже учтена, без неё \(naRub(basePrice))"
    }

    var clientDiscountNote: String? {
        guard hasLoyaltyDiscount, selectedClient != nil else { return nil }
        return "\(clientVisitNumber)-й визит: скидка \(loyaltyLabel) применится сама"
    }

    // MARK: Clients

    var clientSearchResults: [Client] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = query.lowercased()
        let digits = query.filter(\.isNumber)
        let matched = clients.filter { client in
            if query.isEmpty { return true }
            if client.name.lowercased().contains(lowered) { return true }
            return !digits.isEmpty && client.phone.filter(\.isNumber).contains(digits)
        }
        return Array(matched.prefix(query.isEmpty ? 4 : 5))
    }

    var isSearchEmpty: Bool { searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var newClientRowTitle: String {
        isSearchEmpty ? "Новый клиент" : "Новый клиент «\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))»"
    }

    var newClientRowSubtitle: String { "Имя и телефон, 10 секунд" }

    func clientSubtitle(_ client: Client) -> String {
        let phone = client.phone.isEmpty ? "без телефона" : client.phone
        let visits = client.appointmentsCount ?? 0
        let visitsText = visits > 0
            ? "\(visits) \(ruPlural(visits, "визит", "визита", "визитов"))"
            : "новый клиент"
        return "\(phone) · \(visitsText)"
    }

    func clientNote(_ client: Client) -> String? {
        let raw = (client.allergies?.isEmpty == false ? client.allergies : client.notes) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: Days and times

    func isBlocked(_ date: Date) -> Bool { blockedDays.contains(naDayKey(date)) }

    func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    func dayNumber(for date: Date) -> Int { calendar.component(.day, from: date) }

    func freeMinutes(forKey key: String) -> Int {
        let bounds = availabilityBounds(forKey: key)
        guard bounds.end > bounds.start else { return 0 }
        let busy = (dayBusyIntervals[key] ?? []).reduce(0) { $0 + ($1.end - $1.start) }
        return max(bounds.end - bounds.start - busy, 0)
    }

    func freeLabel(for date: Date) -> String {
        let key = naDayKey(date)
        if blockedDays.contains(key) { return "выходной" }
        let minutes = freeMinutes(forKey: key)
        guard minutes > 0 else { return "занято" }
        let hours = (Double(minutes) / 60.0 * 10).rounded() / 10
        if hours == hours.rounded() { return "\(Int(hours)) ч" }
        return "\(String(format: "%.1f", hours).replacingOccurrences(of: ".", with: ",")) ч"
    }

    var selectedStartTimes: [Int] { startTimes(forKey: selectedDayKey) }

    var slotSections: [NewAppointmentSlotSection] {
        let starts = selectedStartTimes
        return slotGroupBounds.compactMap { bound in
            let values = starts.filter { $0 >= bound.from && $0 < bound.to }
            guard !values.isEmpty else { return nil }
            return NewAppointmentSlotSection(title: bound.title, times: values.map(naTimeString))
        }
    }

    var noWindowMessage: String {
        "В этот день нет свободного окна на \(requiredDuration) мин. Выбери другой день."
    }

    var blockedMessage: String { "Этот день выходной. Выбери другой день." }

    // MARK: Footer

    var actionTitle: String {
        if selectedClient == nil { return "Выбери клиента" }
        if selectedServices.isEmpty { return "Выбери услугу" }
        if selectedTime.isEmpty { return "Выбери время" }
        return "Записать на \(selectedTime)"
    }

    var footerSummary: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE, d MMMM"
        let day = naCapitalized(formatter.string(from: selectedDate))
        if !selectedTime.isEmpty, let start = naMinutes(selectedTime) {
            return "\(day) · \(selectedTime)–\(naTimeString(start + requiredDuration))"
        }
        if serviceDuration > 0 { return "\(day) · \(serviceDuration) мин" }
        return day
    }

    // MARK: Loading

    func loadData(
        preselectedTime: String?,
        preselectedDate: Date?,
        preselectedClient: Client?,
        onCreated: (() -> Void)?
    ) async {
        isLoading = true
        self.onCreated = onCreated

        let today = calendar.startOfDay(for: Date())
        let requestedDate = calendar.startOfDay(for: preselectedDate ?? today)
        selectedDate = max(requestedDate, today)
        if let client = preselectedClient { selectedClient = client }
        ribbonDays = (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: selectedDate) }

        async let clientsTask: Void = loadClients()
        async let servicesTask: Void = loadServices()
        async let profileTask: Void = loadProfile()
        async let blockedTask: Void = loadBlockedDays()
        _ = await (clientsTask, servicesTask, profileTask, blockedTask)

        if blockedDays.contains(selectedDayKey),
           let firstOpenDay = ribbonDays.first(where: { !isBlocked($0) }) {
            selectedDate = firstOpenDay
        }

        await loadDayIntervals()
        await loadSlots()
        applyPreselectedTime(preselectedTime)
        refreshPrice()
        isLoading = false
    }

    private func loadClients() async {
        if let response = try? await api.request(.clients(page: 0, search: ""), as: ClientsResponse.self) {
            clients = response.clients
        } else {
            clients = []
        }
    }

    private func loadServices() async {
        if let response = try? await api.request(.services, as: ServicesResponse.self) {
            services = response.services
        } else {
            services = []
        }
    }

    private func loadProfile() async {
        guard let loaded = try? await api.request(.me, as: MasterProfile.self) else { return }
        profile = loaded
        guard loaded.workStart >= 0,
              loaded.workStart < 24,
              loaded.workEnd > loaded.workStart,
              loaded.workEnd <= 24 else { return }
        workStart = loaded.workStart
        workEnd = loaded.workEnd
    }

    private func loadBlockedDays() async {
        guard let response = try? await api.request(.getBlockedDays, as: BlockedDaysResponse.self) else { return }
        blockedDays = Set(response.blockedDays)
    }

    private func loadDayIntervals() async {
        let apiClient = api
        let keys = ribbonDays.map(naDayKey)
        let loaded = await withTaskGroup(
            of: (String, [NewAppointmentInterval]).self,
            returning: [String: [NewAppointmentInterval]].self
        ) { group in
            for key in keys {
                group.addTask { [apiClient] in
                    let response = try? await apiClient.request(.schedule(date: key), as: ScheduleResponse.self)
                    let appointments = (response?.appointments ?? []).filter { $0.status != .cancelled }
                    return (key, NewAppointmentInterval.merged(from: appointments))
                }
            }

            var result: [String: [NewAppointmentInterval]] = [:]
            for await (key, intervals) in group {
                guard !Task.isCancelled else { return result }
                result[key] = intervals
            }
            return result
        }

        var intervals: [String: [NewAppointmentInterval]] = [:]
        for (key, value) in loaded {
            intervals[key] = value
        }
        dayBusyIntervals = intervals
    }

    private func loadSlots() async {
        let key = selectedDayKey
        serverSlots = []
        guard !isBlocked(selectedDate) else {
            validateSelectedTime()
            return
        }

        let response = try? await api.request(.slots(date: key), as: SlotsResponse.self)
        guard key == selectedDayKey else { return }
        serverSlots = (response?.slots ?? []).compactMap(naMinutes).sorted()
        validateSelectedTime()
    }

    private func applyPreselectedTime(_ time: String?) {
        guard let time, !time.isEmpty else { return }
        guard selectedStartTimes.contains(naMinutes(time) ?? -1) else { return }
        selectedTime = naTimeString(naMinutes(time) ?? 0)
    }

    private func validateSelectedTime() {
        guard !selectedTime.isEmpty else { return }
        guard let minutes = naMinutes(selectedTime), selectedStartTimes.contains(minutes) else {
            selectedTime = ""
            return
        }
        selectedTime = naTimeString(minutes)
    }

    private func availabilityBounds(forKey key: String) -> (start: Int, end: Int) {
        let start = workStart * 60
        let end = workEnd * 60
        guard key == naDayKey(Date()) else { return (start, end) }
        let components = calendar.dateComponents([.hour, .minute], from: Date())
        let now = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return (max(start, min(now, end)), end)
    }

    private func startTimes(forKey key: String) -> [Int] {
        let need = requiredDuration
        let bounds = availabilityBounds(forKey: key)
        guard bounds.end - bounds.start >= need else { return [] }
        let busy = dayBusyIntervals[key] ?? []

        let candidates: [Int]
        if key == selectedDayKey, !serverSlots.isEmpty {
            candidates = serverSlots
        } else {
            var grid: [Int] = []
            var start = bounds.start
            while start + need <= bounds.end {
                grid.append(start)
                start += slotStep
            }
            candidates = grid
        }

        return candidates.filter { start in
            let end = start + need
            guard start >= bounds.start, end <= bounds.end else { return false }
            return !busy.contains { interval in
                start < interval.end && end > interval.start
            }
        }
        .sorted()
    }

    // MARK: Actions

    func selectDay(_ date: Date) {
        guard !isBlocked(date) else { return }
        selectedDate = calendar.startOfDay(for: date)
        serverSlots = []
        validateSelectedTime()
        Task { await loadSlots() }
    }

    func toggleService(_ service: Service) {
        if let index = selectedServices.firstIndex(where: { $0.id == service.id }) {
            selectedServices.remove(at: index)
        } else {
            selectedServices.append(service)
        }
        refreshPrice()
        validateSelectedTime()
    }

    func isServiceSelected(_ service: Service) -> Bool {
        selectedServices.contains { $0.id == service.id }
    }

    func selectTime(_ time: String) {
        selectedTime = time
    }

    func toggleMore() {
        isMoreOpen.toggle()
    }

    func setPriceInput(_ value: String) {
        priceInput = String(value.filter(\.isNumber).prefix(7))
    }

    func refreshPrice() {
        let auto = autoPrice
        priceInput = auto > 0 ? String(auto) : ""
    }

    func selectClient(_ client: Client) {
        selectedClient = client
        resetClientForm()
        refreshPrice()
    }

    func resetClientSelection() {
        selectedClient = nil
        searchText = ""
        resetClientForm()
        refreshPrice()
    }

    func beginAddingClient() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = query.filter(\.isNumber)
        if query.isEmpty {
            newClientName = ""
            newClientPhone = ""
        } else if digits.count == query.count {
            newClientName = ""
            newClientPhone = digits
        } else {
            newClientName = query
            newClientPhone = ""
        }
        isNewClientNameValid = true
        isAddingClient = true
    }

    func cancelAddingClient() {
        resetClientForm()
    }

    func addClient() async {
        let name = newClientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = newClientPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            isNewClientNameValid = false
            nameErrorNonce += 1
            HapticManager.error()
            return
        }

        isCreatingClient = true
        errorMessage = nil
        let request = ClientCreateRequest(name: name, phone: phone, notes: "", source: "", allergies: "")
        do {
            let _ = try await api.request(.createClient(request), as: MessageResponse.self)
            await loadClients()
            if let created = clients.first(where: { client in
                phone.isEmpty ? client.name == name : client.phone == phone
            }) {
                selectClient(created)
            } else {
                resetClientSelection()
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Не удалось добавить клиента"
        }
        isCreatingClient = false
    }

    private func resetClientForm() {
        isAddingClient = false
        newClientName = ""
        newClientPhone = ""
        isNewClientNameValid = true
    }

    func save() async {
        guard let client = selectedClient, !selectedServices.isEmpty, !selectedTime.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        let request = AppointmentCreateRequest(
            clientId: client.id,
            procedure: selectedServices.map(\.name).joined(separator: " + "),
            appointmentDate: selectedDayKey,
            time: selectedTime,
            price: displayPrice,
            notes: notes,
            durationMin: requiredDuration
        )
        do {
            let _ = try await api.request(.createAppointment(request), as: MessageResponse.self)
            isSaving = false
            isSaved = true
            HapticManager.success()
            try? await Task.sleep(nanoseconds: 500_000_000)
            onCreated?()
        } catch let error as NetworkError {
            isSaving = false
            errorMessage = error.errorDescription
        } catch {
            isSaving = false
            errorMessage = "Не удалось сохранить запись"
        }
    }
}

// MARK: - View

struct NewAppointmentView: View {
    @StateObject private var vm = NewAppointmentViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var preselectedTime: String? = nil
    var selectedDate: Date? = nil
    var preselectedClient: Client? = nil

    @State private var appeared = false
    @State private var pricePulsed = false
    @State private var nameShake: CGFloat = 0
    @State private var nameFieldFocused = false
    @State private var phoneFieldFocused = false

    private var timeColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 68, maximum: 110), spacing: 8)]
    }

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()

            if vm.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            clientSection
                            servicesSection
                            whenSection
                            moreSection
                            if let message = vm.errorMessage {
                                BBErrorBanner(message: message)
                                    .padding(.top, 16)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    footer
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .task {
            await vm.loadData(
                preselectedTime: preselectedTime,
                preselectedDate: selectedDate,
                preselectedClient: preselectedClient
            ) { dismiss() }
            appeared = true
        }
        .onChange(of: vm.displayPrice) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(DS.springBouncy) { pricePulsed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(DS.springSmooth) { pricePulsed = false }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("Новая запись")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer(minLength: 8)
            Button {
                HapticManager.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(theme.backgroundInput))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    // MARK: Client

    private var clientSection: some View {
        section(0) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Клиент", topPadding: 0)
                if let client = vm.selectedClient {
                    selectedClientCard(client)
                    if let note = vm.clientNote(client) {
                        noteBanner(note, isWarning: true)
                    }
                    if let note = vm.clientDiscountNote {
                        noteBanner(note, isWarning: false)
                    }
                } else if vm.isAddingClient {
                    addClientForm
                } else {
                    clientSearch
                }
            }
        }
    }

    private func selectedClientCard(_ client: Client) -> some View {
        HStack(spacing: 12) {
            avatar(for: client)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Text(vm.clientSubtitle(client))
                    .font(.system(size: 12.5))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                HapticManager.light()
                vm.resetClientSelection()
            } label: {
                Text("Изменить")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(theme.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.accent.opacity(0.28), lineWidth: 1)
        )
    }

    private var clientSearch: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textMuted)

                TextField("", text: $vm.searchText)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)

                if !vm.isSearchEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Очистить поиск")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(theme.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )

            if vm.isSearchEmpty {
                subLabel("Недавние")
                    .padding(.top, 6)
            }

            ForEach(vm.clientSearchResults) { client in
                clientRow(client)
            }

            addClientRow
        }
    }

    private func clientRow(_ client: Client) -> some View {
        Button {
            HapticManager.selection()
            vm.selectClient(client)
        } label: {
            HStack(spacing: 12) {
                avatar(for: client)
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text(vm.clientSubtitle(client))
                        .font(.system(size: 12.5))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addClientRow: some View {
        Button {
            HapticManager.selection()
            vm.beginAddingClient()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(theme.backgroundInput))

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.newClientRowTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .lineLimit(1)
                    Text(vm.newClientRowSubtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addClientForm: some View {
        VStack(spacing: 8) {
            BBTextField(
                placeholder: "Имя",
                text: $vm.newClientName,
                isValid: vm.isNewClientNameValid,
                contentType: .name
            )
            .focused($nameFieldFocused)
            .modifier(NewAppointmentShake(animatableData: nameShake))

            BBTextField(
                placeholder: "+7 900 000-00-00",
                text: $vm.newClientPhone,
                keyboardType: .phonePad,
                contentType: .telephoneNumber
            )
            .focused($phoneFieldFocused)

            HStack(spacing: 8) {
                BBSecondaryButton(title: "Отмена") {
                    vm.cancelAddingClient()
                }
                BBPrimaryButton(title: "Добавить", isLoading: vm.isCreatingClient) {
                    Task { await vm.addClient() }
                }
            }
            .padding(.top, 2)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if vm.newClientName.isEmpty {
                    nameFieldFocused = true
                } else {
                    phoneFieldFocused = true
                }
            }
        }
        .onChange(of: vm.isAddingClient) { _, isAdding in
            if !isAdding {
                nameFieldFocused = false
                phoneFieldFocused = false
            }
        }
        .onChange(of: vm.nameErrorNonce) { _, nonce in
            guard nonce > 0 else { return }
            nameShake = 0
            withAnimation(.linear(duration: 0.4)) { nameShake = 1 }
        }
    }

    private func avatar(for client: Client) -> some View {
        Text(initials(for: client))
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 42, height: 42)
            .background(Circle().fill(theme.gradientPrimary))
    }

    private func initials(for client: Client) -> String {
        let parts = client.name.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)) } ?? "?"
        let second = parts.count > 1 ? String(parts[1].prefix(1)) : ""
        let value = (first + second).uppercased()
        return value.isEmpty ? "?" : value
    }

    // MARK: Services

    private var servicesSection: some View {
        section(1) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Услуги", hint: "можно несколько")
                VStack(spacing: 8) {
                    ForEach(vm.services) { service in
                        serviceRow(service)
                    }
                }
            }
        }
    }

    private func serviceRow(_ service: Service) -> some View {
        let isSelected = vm.isServiceSelected(service)
        return Button {
            HapticManager.selection()
            vm.toggleService(service)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.clear : theme.borderSubtle, lineWidth: 1.5)
                    )
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text("\(service.durationMin) мин")
                        .font(.system(size: 12.5))
                        .foregroundColor(theme.textSecondary)
                }

                Spacer(minLength: 4)

                Text(naRub(service.priceDefault))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
            }
            .padding(12)
            .background(isSelected ? theme.accent.opacity(0.1) : theme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? theme.accent : theme.borderSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: When

    private var whenSection: some View {
        section(2) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Когда")
                dayRibbon
                slotsBlock
            }
        }
    }

    private var dayRibbon: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.ribbonDays, id: \.self) { date in
                        dayCell(date)
                            .id(date)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                proxy.scrollTo(vm.selectedDate, anchor: .center)
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = date.isSameDay(as: vm.selectedDate)
        let isBlocked = vm.isBlocked(date)
        return Button {
            guard !isBlocked else { return }
            HapticManager.selection()
            withAnimation(reduceMotion ? nil : DS.springSnappy) {
                vm.selectDay(date)
            }
        } label: {
            VStack(spacing: 1) {
                Text(vm.weekdayLabel(for: date))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .white : theme.textMuted)
                    .textCase(.uppercase)
                Text("\(vm.dayNumber(for: date))")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : theme.textPrimary)
                Text(vm.freeLabel(for: date))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 62)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundCard))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : theme.borderSubtle, lineWidth: 1)
            )
            .opacity(isBlocked ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isBlocked)
    }

    @ViewBuilder
    private var slotsBlock: some View {
        if vm.isBlocked(vm.selectedDate) {
            emptyMessage(vm.blockedMessage)
        } else if vm.slotSections.isEmpty {
            emptyMessage(vm.noWindowMessage)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(vm.slotSections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        subLabel(section.title)
                        LazyVGrid(columns: timeColumns, spacing: 8) {
                            ForEach(section.times, id: \.self) { time in
                                timePill(time)
                            }
                        }
                    }
                }
            }
        }
    }

    private func timePill(_ time: String) -> some View {
        let isSelected = vm.selectedTime == time
        return Button {
            HapticManager.selection()
            withAnimation(reduceMotion ? nil : DS.springSnappy) {
                vm.selectTime(time)
            }
        } label: {
            Text(time)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: DS.r12)
                        .fill(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Price and notes

    private var moreSection: some View {
        section(3) {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(theme.borderSubtle)
                    .frame(height: 1)

                Button {
                    HapticManager.light()
                    withAnimation(reduceMotion ? nil : DS.springSmooth) {
                        vm.toggleMore()
                    }
                } label: {
                    HStack {
                        Text("Цена и заметка")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                            .rotationEffect(.degrees(vm.isMoreOpen ? 90 : 0))
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if vm.isMoreOpen {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Цена, ₽")
                            BBTextField(
                                placeholder: "0",
                                text: Binding(
                                    get: { vm.priceInput },
                                    set: { vm.setPriceInput($0) }
                                ),
                                keyboardType: .numberPad
                            )
                        }

                        if let hint = vm.discountHint {
                            subLabel(hint)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Заметка")
                            BBTextField(
                                placeholder: "Например: снять старое покрытие",
                                text: $vm.notes
                            )
                        }
                    }
                    .padding(.bottom, 6)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(vm.footerSummary)
                    .font(.system(size: 13.5))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                Text(naRub(vm.displayPrice))
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .scaleEffect(pricePulsed ? 1.06 : 1)
            }

            if vm.isSaved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text("Готово")
                        .font(DS.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: DS.r16)
                        .fill(theme.statusGreen)
                )
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            } else {
                BBPrimaryButton(
                    title: vm.actionTitle,
                    isLoading: vm.isSaving,
                    isDisabled: !vm.isReady
                ) {
                    Task { await vm.save() }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 26)
        .background(theme.backgroundDeep)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.borderSubtle)
                .frame(height: 1)
        }
        .animation(reduceMotion ? .none : DS.springBouncy, value: vm.isSaved)
    }

    // MARK: Small builders

    private func section<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
            .animation(
                reduceMotion ? .none : DS.springSmooth.delay(Double(index) * 0.07),
                value: appeared
            )
    }

    private func sectionLabel(_ title: String, hint: String? = nil, topPadding: CGFloat = 16) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
            if let hint {
                Text(hint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, topPadding)
        .padding(.bottom, 8)
    }

    private func subLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(theme.textMuted)
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
    }

    private func noteBanner(_ text: String, isWarning: Bool) -> some View {
        let color = isWarning ? theme.statusYellow : theme.statusGreen
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundColor(isWarning ? theme.textPrimary : color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Slot Picker

struct SlotPicker: View {
    let slots: [String]
    @Binding var selected: String
    let theme: AppTheme

    var columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(slots, id: \.self) { slot in
                Text(slot)
                    .font(DS.label)
                    .foregroundColor(selected == slot ? .white : theme.textSecondary)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DS.r8)
                            .fill(selected == slot ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                    )
                    .cornerRadius(DS.r8)
                    .onTapGesture {
                        HapticManager.selection()
                        withAnimation(DS.springSnappy) { selected = slot }
                    }
            }
        }
    }
}

// MARK: - Shake

private struct NewAppointmentShake: GeometryEffect {
    var amount: CGFloat = 8
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
    NewAppointmentView()
        .environment(\.theme, .pink)
}
