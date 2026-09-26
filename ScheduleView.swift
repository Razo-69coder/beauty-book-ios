import SwiftUI
import UIKit

fileprivate struct ScheduleFreeWindow: Identifiable {
    let startMinute: Int
    let endMinute: Int

    var id: Int { startMinute }
}

private func minutes(from time: String) -> Int? {
    let parts = time.split(separator: ":")
    guard let hour = Int(parts.first ?? ""),
          let minute = Int(parts.count > 1 ? parts[1] : "0"),
          (0..<24).contains(hour),
          (0..<60).contains(minute) else { return nil }
    return hour * 60 + minute
}

private func timeString(fromMinutes totalMinutes: Int) -> String {
    let normalized = max(0, totalMinutes)
    return String(format: "%02d:%02d", normalized / 60, normalized % 60)
}

private func appointmentStartDate(_ appointment: Appointment) -> Date? {
    let dateParts = appointment.appointmentDate.split(separator: "-").compactMap { Int($0) }
    let timeParts = appointment.time.split(separator: ":").compactMap { Int($0) }
    guard dateParts.count == 3,
          let hour = timeParts.first else { return nil }
    let year = dateParts[0]
    let month = dateParts[1]
    let day = dateParts[2]
    let minute = timeParts.count > 1 ? timeParts[1] : 0

    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = Calendar.current.timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components)
}

private func appointmentEndTime(_ appointment: Appointment) -> String {
    let start = minutes(from: appointment.time) ?? 0
    return timeString(fromMinutes: start + max(appointment.duration ?? 60, 0))
}

private func appointmentIsPast(_ appointment: Appointment, at date: Date = Date()) -> Bool {
    if appointment.status == .completed || appointment.status == .noShow { return true }
    guard let start = appointmentStartDate(appointment) else { return false }
    return start.addingTimeInterval(TimeInterval(max(appointment.duration ?? 60, 0))) <= date
}

private func capitalizedFirst(_ value: String) -> String {
    guard let first = value.first else { return value }
    return String(first).uppercased() + value.dropFirst()
}

private func formattedRubles(_ value: Int) -> String {
    let prefix = value < 0 ? "−" : ""
    let digits = String(value.magnitude)
    var grouped = ""
    for (index, character) in digits.enumerated() {
        if index > 0 && (digits.count - index) % 3 == 0 {
            grouped.append(" ")
        }
        grouped.append(character)
    }
    return prefix + grouped + " ₽"
}

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var appointments: [Appointment] = []
    @Published var notes: [PersonalNote] = []
    @Published var dayCounts: [String: Int] = [:]
    @Published var blockedDays: Set<String> = []
    @Published var workStart = 9
    @Published var workEnd = 20
    @Published var bookingLink = ""
    @Published var isLoading = false
    @Published var selectedAppointment: Appointment? = nil
    @Published var showNewAppointment = false
    @Published var showNewNote = false
    @Published var preselectedTime: String? = nil

    private let api = APIClient.shared
    private let calendar = Calendar.current
    private var activeScheduleRequestID: UUID?

    var dates: [Date] {
        (-180..<185).compactMap { offset -> Date? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            return calendar.startOfDay(for: date)
        }
    }

    var selectedDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        formatter.locale = Locale(identifier: "ru_RU")
        return capitalizedFirst(formatter.string(from: selectedDate))
    }

    var relativeDayLabel: String {
        if calendar.isDateInToday(selectedDate) { return "Сегодня" }
        if calendar.isDateInTomorrow(selectedDate) { return "Завтра" }
        if calendar.isDateInYesterday(selectedDate) { return "Вчера" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return capitalizedFirst(formatter.string(from: selectedDate))
    }

    var isToday: Bool { calendar.isDateInToday(selectedDate) }

    var timelineStartHour: Int {
        let earliestAppointment = appointments.compactMap { minutes(from: $0.time) }.min() ?? workStart * 60
        return max(0, min(23, min(workStart, earliestAppointment / 60)))
    }

    var timelineEndHour: Int {
        let latestEnd = appointments.compactMap { appointment -> Int? in
            guard let start = minutes(from: appointment.time) else { return nil }
            return start + max(appointment.duration ?? 60, 0)
        }.max() ?? workEnd * 60
        let requiredEnd = max(workEnd, Int(ceil(Double(latestEnd) / 60.0)))
        return max(timelineStartHour + 1, min(24, requiredEnd))
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func isBlocked(_ date: Date) -> Bool {
        blockedDays.contains(dateString(date))
    }

    func dayCount(for date: Date) -> Int {
        dayCounts[dateString(date)] ?? 0
    }

    func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func hourSlots() -> [Int] {
        let end = max(timelineStartHour + 1, timelineEndHour)
        return Array(timelineStartHour..<end)
    }

    func positionForAppointment(_ appointment: Appointment) -> CGFloat {
        positionForMinutes(minutes(from: appointment.time) ?? 0)
    }

    func positionForTime(_ time: String) -> CGFloat {
        positionForMinutes(minutes(from: time) ?? 0)
    }

    func positionForMinutes(_ totalMinutes: Int) -> CGFloat {
        CGFloat(totalMinutes - timelineStartHour * 60) / 60.0 * 64
    }

    func heightForAppointment(_ appointment: Appointment) -> CGFloat {
        CGFloat(max(appointment.duration ?? 60, 0)) / 60.0 * 64
    }

    fileprivate func heightForFreeWindow(_ window: ScheduleFreeWindow) -> CGFloat {
        min(max(CGFloat(window.endMinute - window.startMinute) / 60.0 * 64 - 4, 0), 56)
    }

    func containsTimelineTime(_ date: Date) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return currentMinutes >= timelineStartHour * 60 && currentMinutes <= timelineEndHour * 60
    }

    func nextAppointment(at date: Date) -> Appointment? {
        appointments
            .filter { $0.status == .confirmed || $0.status == .pending }
            .filter { !appointmentIsPast($0, at: date) }
            .sorted { $0.time < $1.time }
            .first
    }

    func countdownText(to appointment: Appointment, at date: Date) -> String {
        guard let targetMinutes = minutes(from: appointment.time) else { return "Следующая запись" }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let remaining = max(targetMinutes - currentMinutes, 0)
        if remaining < 60 { return "Следующая через \(remaining) мин" }
        let hours = remaining / 60
        let minutes = remaining % 60
        return minutes == 0
            ? "Следующая через \(hours) ч"
            : "Следующая через \(hours) ч \(minutes) мин"
    }

    func freeMinutes(at date: Date) -> Int {
        let bounds = availabilityBounds(at: date)
        let busyMinutes = mergedBusyIntervals(from: bounds.start, to: bounds.end)
            .reduce(0) { $0 + ($1.end - $1.start) }
        return max(bounds.end - bounds.start - busyMinutes, 0)
    }

    fileprivate func freeWindows(at date: Date) -> [ScheduleFreeWindow] {
        let bounds = availabilityBounds(at: date)
        guard bounds.end > bounds.start else { return [] }
        let intervals = mergedBusyIntervals(from: bounds.start, to: bounds.end)
        var windows: [ScheduleFreeWindow] = []
        var cursor = bounds.start

        for interval in intervals {
            if interval.start - cursor >= 60 {
                windows.append(ScheduleFreeWindow(startMinute: cursor, endMinute: interval.start))
            }
            cursor = max(cursor, interval.end)
        }

        if bounds.end - cursor >= 60 {
            windows.append(ScheduleFreeWindow(startMinute: cursor, endMinute: bounds.end))
        }
        return windows
    }

    func hoursLabel(minutes totalMinutes: Int) -> String {
        let hours = Double(totalMinutes) / 60.0
        if hours.rounded() == hours { return String(Int(hours)) }
        return String(format: "%.1f", hours)
            .replacingOccurrences(of: ".", with: ",")
    }

    func selectSlot(hour: Int) {
        preselectedTime = String(format: "%02d:00", hour)
        showNewAppointment = true
    }

    func loadInitialData() async {
        async let configuration: Void = loadConfiguration()
        async let schedule: Void = loadSchedule()
        _ = await (configuration, schedule)
        await loadDayCountsIfNeeded()
    }

    func loadSelectedDayData() async {
        await loadSchedule()
        guard !Task.isCancelled else { return }
        await loadDayCountsIfNeeded()
    }

    func loadSchedule() async {
        let requestedDate = dateString(selectedDate)
        let requestID = UUID()
        activeScheduleRequestID = requestID
        isLoading = true

        async let appointmentResponse = api.request(.schedule(date: requestedDate), as: ScheduleResponse.self)
        async let notesResponse = api.request(.getNotes(date: requestedDate), as: PersonalNotesResponse.self)
        let loadedAppointments = (try? await appointmentResponse)?.appointments
            .filter { $0.status != .cancelled }
            .sorted { $0.time < $1.time } ?? []
        let loadedNotes = (try? await notesResponse)?.notes.sorted { $0.time < $1.time } ?? []

        guard activeScheduleRequestID == requestID,
              dateString(selectedDate) == requestedDate,
              !Task.isCancelled else { return }
        appointments = loadedAppointments
        dayCounts[requestedDate] = loadedAppointments.count
        notes = loadedNotes
        isLoading = false
    }

    func deleteNote(_ note: PersonalNote) async {
        notes.removeAll { $0.id == note.id }
        let _ = try? await api.request(.deleteNote(id: note.id), as: MessageResponse.self)
    }

    func cancelAppointment(_ id: Int) async {
        appointments.removeAll { $0.id == id }
        let key = dateString(selectedDate)
        dayCounts[key] = max((dayCounts[key] ?? 0) - 1, 0)
        let _ = try? await api.request(.cancelAppointment(id: id), as: MessageResponse.self)
    }

    private func loadConfiguration() async {
        async let profile: Void = loadWorkHours()
        async let blocked: Void = loadBlockedDays()
        async let link: Void = loadBookingLink()
        _ = await (profile, blocked, link)
    }

    private func loadWorkHours() async {
        guard let profile = try? await api.request(.me, as: MasterProfile.self) else { return }
        guard profile.workStart >= 0,
              profile.workStart < 24,
              profile.workEnd > profile.workStart,
              profile.workEnd <= 24 else { return }
        workStart = profile.workStart
        workEnd = profile.workEnd
    }

    private func loadBlockedDays() async {
        guard let response = try? await api.request(.getBlockedDays, as: BlockedDaysResponse.self) else { return }
        blockedDays = Set(response.blockedDays)
    }

    private func loadBookingLink() async {
        guard let response = try? await api.request(.getBookingLink, as: BookingLinkResponse.self) else { return }
        let slug = response.bookingLink.trimmingCharacters(in: .whitespacesAndNewlines)
        bookingLink = slug.isEmpty ? "" : "https://beauty-bot-44ou.onrender.com/book/\(slug)"
    }

    private func loadDayCountsIfNeeded() async {
        let visibleDates = (-7...14).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: selectedDate)
        }
        let missingDates = visibleDates.filter { dayCounts[dateString($0)] == nil }
        guard !missingDates.isEmpty else { return }

        let loadedCounts = await withTaskGroup(
            of: (String, Int).self,
            returning: [String: Int].self
        ) { group in
            for date in missingDates {
                let key = dateString(date)
                group.addTask { [api] in
                    let response = try? await api.request(.schedule(date: key), as: ScheduleResponse.self)
                    let count = response?.appointments.filter { $0.status != .cancelled }.count ?? 0
                    return (key, count)
                }
            }

            var result: [String: Int] = [:]
            for await (key, count) in group {
                guard !Task.isCancelled else { return result }
                result[key] = count
            }
            return result
        }

        for (key, count) in loadedCounts where dayCounts[key] == nil {
            dayCounts[key] = count
        }
    }

    private func availabilityBounds(at date: Date) -> (start: Int, end: Int) {
        let start = workStart * 60
        let end = workEnd * 60
        guard isToday else { return (start, end) }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return (max(start, min(currentMinutes, end)), end)
    }

    private func mergedBusyIntervals(from start: Int, to end: Int) -> [(start: Int, end: Int)] {
        let intervals: [(start: Int, end: Int)] = appointments.compactMap { appointment in
            guard let appointmentStart = minutes(from: appointment.time) else { return nil }
            let intervalStart = max(start, appointmentStart)
            let intervalEnd = min(end, appointmentStart + max(appointment.duration ?? 60, 0))
            guard intervalEnd > intervalStart else { return nil }
            return (intervalStart, intervalEnd)
        }
        .sorted { $0.start < $1.start }

        var merged: [(start: Int, end: Int)] = []
        for interval in intervals {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1].end = max(last.end, interval.end)
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}

struct ScheduleView: View {
    @StateObject private var vm = ScheduleViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var editingAppointment: Appointment? = nil
    @State private var showMonthPicker = false
    @State private var pickerMonth = Date()
    @State private var showFabMenu = false
    @State private var isFabPressed = false

    private let timelineHourHeight: CGFloat = 64
    private let timelineGutter: CGFloat = 58

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            theme.backgroundDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                dateStrip
                summaryCard
                dayContent
            }

            fabButton
                .padding(.trailing, 20)
                .padding(.bottom, 120)
        }
        .sheet(isPresented: $vm.showNewAppointment) {
            NewAppointmentView(preselectedTime: vm.preselectedTime, selectedDate: vm.selectedDate)
                .environment(\.theme, theme)
        }
        .sheet(item: $vm.selectedAppointment) { appointment in
            AppointmentDetailSheet(
                appointment: appointment,
                theme: theme,
                onCancel: {
                    Task { await vm.cancelAppointment(appointment.id) }
                    vm.selectedAppointment = nil
                },
                onEdit: {
                    vm.selectedAppointment = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editingAppointment = appointment
                    }
                },
                onStatusChange: { newStatus in
                    if let index = vm.appointments.firstIndex(where: { $0.id == appointment.id }) {
                        let old = vm.appointments[index]
                        vm.appointments[index] = Appointment(
                            id: old.id,
                            clientId: old.clientId,
                            masterId: old.masterId,
                            procedure: old.procedure,
                            appointmentDate: old.appointmentDate,
                            time: old.time,
                            price: old.price,
                            notes: old.notes,
                            status: newStatus,
                            depositStatus: old.depositStatus,
                            depositAmount: old.depositAmount,
                            clientName: old.clientName,
                            clientPhone: old.clientPhone,
                            serviceDoneAt: old.serviceDoneAt,
                            duration: old.duration
                        )
                    }
                    vm.selectedAppointment = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(item: $editingAppointment) { appointment in
            EditAppointmentView(appointment: appointment, onUpdated: {
                editingAppointment = nil
                Task { await vm.loadSelectedDayData() }
            })
            .environment(\.theme, theme)
        }
        .task {
            await vm.loadInitialData()
        }
        .onChange(of: vm.selectedDate) { _, _ in
            Task { await vm.loadSelectedDayData() }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        pickerMonth = vm.selectedDate
                        showMonthPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(vm.relativeDayLabel)
                                .foregroundColor(theme.accent)
                            Text("· \(monthTitle)")
                                .foregroundColor(theme.textSecondary)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Выбрать месяц")

                    Text(vm.selectedDateFormatted)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)
                HeaderBellButton()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerView(
                selectedDate: $vm.selectedDate,
                pickerMonth: $pickerMonth,
                dates: vm.dates,
                theme: theme
            )
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return capitalizedFirst(formatter.string(from: vm.selectedDate))
    }

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.dates, id: \.self) { date in
                        DateCapsule(
                            date: date,
                            isSelected: vm.selectedDate.isSameDay(as: date),
                            isToday: vm.isToday(date),
                            isBlocked: vm.isBlocked(date),
                            loadCount: vm.dayCount(for: date),
                            theme: theme
                        ) {
                            HapticManager.selection()
                            withAnimation(reduceMotion ? nil : DS.springSnappy) {
                                vm.selectedDate = date
                            }
                        }
                        .id(date)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 5)
            }
            .frame(height: 76)
            .background(theme.backgroundDeep.opacity(0.95))
            .onAppear {
                proxy.scrollTo(vm.selectedDate, anchor: .center)
            }
            .onChange(of: vm.selectedDate) { _, newDate in
                withAnimation(reduceMotion ? nil : DS.springSnappy) {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
        }
    }

    private var summaryCard: some View {
        TimelineView(.everyMinute) { context in
            let nextAppointment = vm.isToday ? vm.nextAppointment(at: context.date) : nil
            let revenue = vm.appointments.reduce(0) { $0 + $1.price }
            let freeMinutes = vm.freeMinutes(at: context.date)

            BBGlassCard {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        summaryMetric(
                            value: "\(vm.appointments.count)",
                            label: ruPlural(vm.appointments.count, "запись", "записи", "записей"),
                            color: theme.textPrimary
                        )
                        verticalDivider
                        summaryMetric(
                            value: formattedRubles(revenue),
                            label: "выручка",
                            color: theme.accent
                        )
                        verticalDivider
                        summaryMetric(
                            value: vm.hoursLabel(minutes: freeMinutes) + " ч",
                            label: "свободно",
                            color: theme.textPrimary
                        )
                    }

                    if let nextAppointment {
                        Divider()
                            .background(theme.borderSubtle)
                            .padding(.vertical, 12)

                        Button {
                            HapticManager.selection()
                            vm.selectedAppointment = nextAppointment
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(theme.statusGreen.opacity(0.2))
                                        .frame(width: 16, height: 16)
                                    Circle()
                                        .fill(theme.statusGreen)
                                        .frame(width: 8, height: 8)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(vm.countdownText(to: nextAppointment, at: context.date))
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textSecondary)
                                    Text("\(nextAppointment.time) · \(nextAppointment.clientName ?? "Клиент")")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(theme.textPrimary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.textMuted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .id(vm.selectedDate)
            .transition(reduceMotion
                ? .opacity
                : .opacity.combined(with: .move(edge: .top)))
            .animation(reduceMotion ? .none : DS.springSmooth, value: vm.selectedDate)
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(theme.borderSubtle)
            .frame(width: 1, height: 42)
    }

    private func summaryMetric(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(reduceMotion ? .identity : .numericText())
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var dayContent: some View {
        ZStack {
            loadedDayContent

            if vm.isLoading {
                Group {
                    if reduceMotion {
                        Image(systemName: "hourglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.accent)
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 12)
                .padding(.trailing, 20)
                .allowsHitTesting(false)
                .accessibilityLabel("Обновление расписания")
            }
        }
    }

    @ViewBuilder
    private var loadedDayContent: some View {
        if vm.isBlocked(vm.selectedDate) {
            EmptyDayCard(
                theme: theme,
                isDayOff: true,
                bookingLink: vm.bookingLink,
                onShare: shareBookingLink,
                onCreate: openManualAppointment
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            Spacer(minLength: 0)
        } else {
            if vm.appointments.isEmpty && vm.notes.isEmpty {
                EmptyDayCard(
                    theme: theme,
                    isDayOff: false,
                    bookingLink: vm.bookingLink,
                    onShare: shareBookingLink,
                    onCreate: openManualAppointment
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            timelineView
        }
    }

    private var timelineView: some View {
        TimelineView(.everyMinute) { context in
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        hoursColumn
                        freeWindowsLayer(at: context.date)
                        appointmentsLayer(at: context.date)
                        notesLayer
                        if vm.isToday && vm.containsTimelineTime(context.date) {
                            Color.clear
                                .frame(width: 1, height: 1)
                                .position(
                                    x: timelineGutter,
                                    y: vm.positionForTime(dateStringForClock(context.date))
                                )
                                .id("schedule-now-line")
                            currentTimeLayer(at: context.date)
                        }
                    }
                    .frame(
                        height: CGFloat(max(vm.timelineEndHour - vm.timelineStartHour, 1)) * timelineHourHeight
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 110)
                }
                .onAppear {
                    scrollToCurrentTime(proxy: proxy)
                }
                .onChange(of: vm.selectedDate) { _, _ in
                    scrollToCurrentTime(proxy: proxy)
                }
            }
        }
    }

    private var hoursColumn: some View {
        VStack(spacing: 0) {
            ForEach(vm.hourSlots(), id: \.self) { hour in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textMuted.opacity(0.8))
                        .frame(width: 42, alignment: .trailing)

                    Rectangle()
                        .fill(theme.borderSubtle)
                        .frame(height: 1)
                }
                .frame(height: timelineHourHeight, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.selection()
                    vm.selectSlot(hour: hour)
                }
            }
        }
        .padding(.leading, 4)
    }

    private func appointmentsLayer(at date: Date) -> some View {
        GeometryReader { geometry in
            let hourWidth = max(geometry.size.width, 0)

            ForEach(Array(vm.appointments.enumerated()), id: \.element.id) { index, appointment in
                AppointmentBlock(
                    appointment: appointment,
                    theme: theme,
                    hourWidth: hourWidth,
                    height: vm.heightForAppointment(appointment),
                    isPast: appointmentIsPast(appointment, at: date),
                    onOpen: {
                        HapticManager.selection()
                        vm.selectedAppointment = appointment
                    }
                )
                .offset(y: vm.positionForAppointment(appointment))
                .transition(reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .offset(y: 8)))
                .animation(
                    reduceMotion
                        ? .none
                        : DS.springSmooth.delay(Double(index) * 0.03),
                    value: vm.appointments.map(\.id)
                )
                .zIndex(2)
            }
        }
        .padding(.leading, timelineGutter)
    }

    private func freeWindowsLayer(at date: Date) -> some View {
        GeometryReader { geometry in
            let hourWidth = max(geometry.size.width, 0)

            ForEach(vm.freeWindows(at: date)) { window in
                FreeTimeBlock(
                    window: window,
                    theme: theme,
                    hourWidth: hourWidth,
                    height: vm.heightForFreeWindow(window)
                ) {
                    HapticManager.selection()
                    vm.preselectedTime = timeString(fromMinutes: window.startMinute)
                    vm.showNewAppointment = true
                }
                .offset(y: vm.positionForMinutes(window.startMinute))
                .zIndex(1)
            }
        }
        .padding(.leading, timelineGutter)
    }

    private var notesLayer: some View {
        GeometryReader { geometry in
            let hourWidth: CGFloat = geometry.size.width - 52

            ForEach(vm.notes) { note in
                NoteBlock(note: note, hourWidth: hourWidth)
                    .offset(y: vm.positionForTime(note.time))
                    .frame(height: 36)
                    .onLongPressGesture {
                        HapticManager.medium()
                        Task { await vm.deleteNote(note) }
                    }
            }
        }
    }

    private func currentTimeLayer(at date: Date) -> some View {
        HStack(spacing: 16) {
            Color.clear
                .frame(width: 42, height: 1)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(theme.accent)
                    .frame(height: 2)

                Circle()
                    .fill(theme.accent)
                    .frame(width: 10, height: 10)
                    .offset(x: -5)

                Text(dateStringForClock(date))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .offset(x: 8)
            }
        }
        .frame(height: timelineHourHeight)
        .offset(y: vm.positionForTime(dateStringForClock(date)))
        .zIndex(4)
    }

    private func dateStringForClock(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func scrollToCurrentTime(proxy: ScrollViewProxy) {
        guard vm.isToday else { return }
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? nil : DS.springSmooth) {
                proxy.scrollTo("schedule-now-line", anchor: UnitPoint(x: 0, y: 0.28))
            }
        }
    }

    private var fabButton: some View {
        Button {
            HapticManager.medium()
            showFabMenu = true
        } label: {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 60, height: 60)
                    .shadow(color: theme.accentGlow, radius: 12, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isFabPressed ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(reduceMotion ? nil : DS.springBouncy) {
                        isFabPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(reduceMotion ? nil : DS.springBouncy) {
                        isFabPressed = false
                    }
                }
        )
        .confirmationDialog("Добавить", isPresented: $showFabMenu, titleVisibility: .visible) {
            Button("Новая запись") {
                vm.preselectedTime = nil
                vm.showNewAppointment = true
            }
            Button("Личная заметка") {
                vm.preselectedTime = nil
                vm.showNewNote = true
            }
            Button("Отмена", role: .cancel) {}
        }
        .sheet(isPresented: $vm.showNewNote) {
            NewNoteView(selectedDate: vm.selectedDate, theme: theme) {
                Task { await vm.loadSchedule() }
            }
        }
    }

    private func openManualAppointment() {
        vm.preselectedTime = nil
        vm.showNewAppointment = true
    }

    private func shareBookingLink() {
        guard !vm.bookingLink.isEmpty else { return }
        HapticManager.medium()
        let activityViewController = UIActivityViewController(
            activityItems: [vm.bookingLink],
            applicationActivities: nil
        )
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let rootViewController = scene.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController else { return }

        var presenter = rootViewController
        while let presentedViewController = presenter.presentedViewController {
            presenter = presentedViewController
        }
        presenter.present(activityViewController, animated: true, completion: nil)
    }
}

struct EmptyDayCard: View {
    let theme: AppTheme
    let isDayOff: Bool
    let bookingLink: String
    let onShare: () -> Void
    let onCreate: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        BBGlassCard {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.accent.opacity(0.14))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: isDayOff ? "moon" : "calendar")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundColor(theme.accent)
                    }

                Text(isDayOff ? "Выходной" : "День свободен")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                if isDayOff {
                    Text("Клиенты не видят этот день в онлайн-записи.")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 270)
                } else {
                    Text("Записей пока нет. Отправь ссылку клиентам, и они запишутся сами на свободное время.")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 270)

                    BBPrimaryButton(
                        title: "Поделиться ссылкой",
                        isDisabled: bookingLink.isEmpty,
                        action: onShare
                    )
                    .environment(\.theme, theme)

                    Button(action: onCreate) {
                        Text("Записать вручную")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(theme.backgroundInput)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .scaleEffect(isVisible ? 1 : 0.96)
        .opacity(isVisible ? 1 : 0)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : DS.springBouncy) {
                isVisible = true
            }
        }
    }
}

fileprivate struct FreeTimeBlock: View {
    let window: ScheduleFreeWindow
    let theme: AppTheme
    let hourWidth: CGFloat
    let height: CGFloat
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHighlighted = false

    var body: some View {
        Button {
            isHighlighted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isHighlighted = false
            }
            action()
        } label: {
            HStack(spacing: 8) {
                Text("Свободно \(timeString(fromMinutes: window.startMinute))–\(timeString(fromMinutes: window.endMinute))")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 4)

                Text("+ Записать")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(width: hourWidth, height: height, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHighlighted ? theme.accent.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        theme.borderSubtle,
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? .none : DS.springMicro, value: isHighlighted)
    }
}

struct AppointmentBlock: View {
    let appointment: Appointment
    let theme: AppTheme
    let hourWidth: CGFloat
    let height: CGFloat
    let isPast: Bool
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    private var isMuted: Bool {
        isPast || appointment.status == .completed || appointment.status == .cancelled
    }

    private var stripeColor: Color {
        if appointment.status == .noShow { return theme.statusRed }
        if isMuted { return theme.textMuted }
        return appointment.status == .pending ? theme.statusYellow : theme.accent
    }

    private var backgroundColor: Color {
        if isMuted { return theme.backgroundCard }
        if appointment.status == .pending { return theme.statusYellow.opacity(0.12) }
        return theme == .platinum ? theme.backgroundCard : theme.accent.opacity(0.14)
    }

    private var borderColor: Color {
        if isMuted { return theme.borderSubtle }
        if appointment.status == .pending { return theme.statusYellow }
        return theme.accent.opacity(0.28)
    }

    private var borderStyle: StrokeStyle {
        if !isMuted && appointment.status == .pending {
            return StrokeStyle(lineWidth: 1, dash: [4, 3])
        }
        return StrokeStyle(lineWidth: 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(stripeColor)
                .frame(width: 4)
                .padding(.vertical, 9)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 5) {
                        if isMuted && appointment.status != .noShow {
                            Text("✓")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(theme.textSecondary)
                        }

                        Text(appointment.clientName ?? "Клиент")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        if appointment.status == .noShow {
                            statusBadge(text: "не пришла", color: theme.statusRed)
                        } else if appointment.status == .pending {
                            statusBadge(text: "ждёт подтверждения", color: theme.statusYellow)
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 4)

                    Text(formattedRubles(appointment.price))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }

                HStack(spacing: 0) {
                    Text("\(appointment.time)–\(appointmentEndTime(appointment))")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Text(" · ")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Text(appointment.procedure)
                        .font(.system(size: 12.5))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: hourWidth, height: height)
        .background(RoundedRectangle(cornerRadius: 16).fill(backgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, style: borderStyle)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: onOpen)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(reduceMotion ? nil : DS.springSnappy) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(reduceMotion ? nil : DS.springSnappy) {
                        isPressed = false
                    }
                }
        )
        .scaleEffect(isPressed ? 0.985 : 1)
        .opacity(isMuted ? 0.62 : 1)
        .animation(reduceMotion ? .none : DS.springSnappy, value: isPressed)
        .accessibilityAddTraits(.isButton)
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct AppointmentDetailSheet: View {
    let appointment: Appointment
    let theme: AppTheme
    let onCancel: () -> Void
    var onEdit: (() -> Void)? = nil
    var onStatusChange: ((AppointmentStatus) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirming = false
    @State private var statusUpdateError: String?

    private var clientInitials: String {
        let name = (appointment.clientName ?? "К").trimmingCharacters(in: .whitespaces)
        let parts = name.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)) } ?? "К"
        let second = parts.count > 1 ? String(parts[1].prefix(1)) : ""
        return (first + second).uppercased()
    }

    private var statusTitle: String {
        switch appointment.status {
        case .confirmed: return "Подтверждена"
        case .pending: return "Ждёт подтверждения"
        case .completed: return "Визит состоялся"
        case .cancelled: return "Отменена"
        case .noShow: return "Не пришла"
        }
    }

    private var statusColor: Color {
        switch appointment.status {
        case .confirmed: return theme.statusGreen
        case .pending: return theme.statusYellow
        case .completed, .cancelled: return theme.textMuted
        case .noShow: return theme.statusRed
        }
    }

    private var appointmentWhen: String {
        let date: String
        if let startDate = appointmentStartDate(appointment) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, d MMMM"
            formatter.locale = Locale(identifier: "ru_RU")
            date = capitalizedFirst(formatter.string(from: startDate))
        } else {
            date = appointment.appointmentDate
        }
        return "\(date) · \(appointment.time)–\(appointmentEndTime(appointment))"
    }

    private var canCancel: Bool {
        appointment.status != .completed && appointment.status != .cancelled && appointment.status != .noShow
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    clientHeader

                    if appointment.status == .pending {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(theme.statusYellow)
                            Text("Клиентка записалась сама по ссылке. Подтверди, и ей придёт сообщение в Telegram.")
                                .font(.system(size: 13))
                                .foregroundColor(theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.statusYellow.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        BBPrimaryButton(
                            title: isConfirming ? "Подтверждение..." : "Подтвердить запись",
                            isLoading: isConfirming,
                            action: confirmPending
                        )
                        .environment(\.theme, theme)
                    }

                    detailsCard
                    actionButtons
                }
                .padding(20)
            }
            .background(theme.backgroundDeep)
            .navigationTitle("Детали записи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
        }
        .alert(
            "Не удалось изменить статус",
            isPresented: Binding(
                get: { statusUpdateError != nil },
                set: { isPresented in
                    if !isPresented { statusUpdateError = nil }
                }
            )
        ) {
            Button("Понятно", role: .cancel) {
                statusUpdateError = nil
            }
        } message: {
            Text(statusUpdateError ?? "Повторите попытку позже")
        }
    }

    private var clientHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 52, height: 52)
                Text(clientInitials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.clientName ?? "Клиент")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Text(appointment.clientPhone ?? "Телефон не указан")
                    .font(.system(size: 13.5))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                statusBadge
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private var statusBadge: some View {
        Text(statusTitle)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.14))
            .clipShape(Capsule())
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(title: "Когда", value: appointmentWhen)
            Divider()
                .background(theme.borderSubtle)
                .padding(.horizontal, 14)
            detailRow(
                title: "Услуги и цена",
                value: "\(appointment.procedure) · \(formattedRubles(appointment.price))"
            )
            Divider()
                .background(theme.borderSubtle)
                .padding(.horizontal, 14)
            HStack {
                Text("Итого")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text(formattedRubles(appointment.price))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(theme.accent)
            }
            .padding(14)
        }
        .background(theme.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let onEdit = onEdit {
                    Button {
                        onEdit()
                        dismiss()
                    } label: {
                        actionButtonLabel(icon: "pencil", title: "Редактировать", color: theme.accent)
                    }
                    .buttonStyle(.plain)
                }

                Menu {
                    ForEach(
                        AppointmentStatus.allCases.filter { $0 != appointment.status },
                        id: \.self
                    ) { status in
                        Button {
                            updateStatus(status)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: status.hexColor))
                                    .frame(width: 10, height: 10)
                                Text(status.displayName)
                            }
                        }
                    }
                } label: {
                    actionButtonLabel(icon: "arrow.triangle.swap", title: "Статус", color: theme.accent)
                }
            }

            if canCancel {
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    actionButtonLabel(icon: "xmark.circle", title: "Отменить запись", color: theme.statusRed)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionButtonLabel(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(theme.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(14)
    }

    private func confirmPending() {
        guard !isConfirming else { return }
        isConfirming = true
        updateStatus(.confirmed)
    }

    private func updateStatus(_ status: AppointmentStatus) {
        Task { @MainActor in
            do {
                try await APIClient.shared.updateAppointmentStatus(id: appointment.id, status: status)
                isConfirming = false
                onStatusChange?(status)
                dismiss()
            } catch {
                isConfirming = false
                statusUpdateError = error.localizedDescription
            }
        }
    }
}

struct DateCapsule: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isBlocked: Bool
    let loadCount: Int
    let theme: AppTheme
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var pointCount: Int {
        switch loadCount {
        case 1...2: return 1
        case 3...4: return 2
        case 5...: return 3
        default: return 0
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.textMuted)

            Text(dayNumber)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundColor(numberColor)

            HStack(spacing: 3) {
                ForEach(0..<pointCount, id: \.self) { _ in
                    Circle()
                        .fill(isSelected ? .white : theme.accent)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(width: 46, height: 66)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(Color.clear))
        )
        .shadow(color: isSelected ? theme.accentGlow : .clear, radius: 10, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture(perform: action)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(reduceMotion ? nil : DS.springSnappy) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(reduceMotion ? nil : DS.springSnappy) {
                        isPressed = false
                    }
                }
        )
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(reduceMotion ? .none : DS.springSnappy, value: isSelected)
        .animation(reduceMotion ? .none : DS.springSnappy, value: isPressed)
        .accessibilityAddTraits(.isButton)
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isBlocked { return theme.textMuted }
        if isToday { return theme.accent }
        return theme.textPrimary
    }
}

extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

struct MonthPickerView: View {
    @Binding var selectedDate: Date
    @Binding var pickerMonth: Date
    let dates: [Date]
    let theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current
    private let months = Array(1...12)

    private var currentYear: Int {
        calendar.component(.year, from: pickerMonth)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    Button {
                        if let d = calendar.date(byAdding: .year, value: -1, to: pickerMonth) {
                            pickerMonth = d
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.accent)
                    }

                    Text("\(String(currentYear))")
                        .font(DS.titleSmall)
                        .foregroundColor(theme.textPrimary)

                    Button {
                        if let d = calendar.date(byAdding: .year, value: 1, to: pickerMonth) {
                            pickerMonth = d
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.accent)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(months, id: \.self) { m in
                        Button {
                            if let target = findFirstOfMonth(month: m, year: currentYear) {
                                selectedDate = calendar.startOfDay(for: target)
                            }
                            dismiss()
                        } label: {
                            Text(monthName(m))
                                .font(DS.body)
                                .foregroundColor(monthColor(m))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(monthBg(m))
                                .cornerRadius(DS.r12)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.backgroundDeep.ignoresSafeArea())
            .navigationTitle("Выберите месяц")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
        }
    }

    private func findFirstOfMonth(month: Int, year: Int) -> Date? {
        dates.first { d in
            calendar.component(.month, from: d) == month &&
            calendar.component(.year, from: d) == year &&
            calendar.component(.day, from: d) == 1
        } ?? dates.first { d in
            calendar.component(.month, from: d) == month &&
            calendar.component(.year, from: d) == year
        }
    }

    private func monthName(_ m: Int) -> String {
        let months = ["","Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]
        return months[m]
    }

    private func monthColor(_ m: Int) -> Color {
        let curMonth = calendar.component(.month, from: selectedDate)
        let curYear = calendar.component(.year, from: selectedDate)
        if m == curMonth && currentYear == curYear { return .white }
        return theme.textPrimary
    }

    private func monthBg(_ m: Int) -> some View {
        let curMonth = calendar.component(.month, from: selectedDate)
        let curYear = calendar.component(.year, from: selectedDate)
        if m == curMonth && currentYear == curYear {
            return AnyView(theme.gradientPrimary)
        }
        return AnyView(Color.clear)
    }
}

struct NoteBlock: View {
    let note: PersonalNote
    let hourWidth: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "#4ECDC4"))
                .frame(width: 3)
                .padding(.vertical, 4)

            Image(systemName: "pencil.line")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#4ECDC4"))

            Text(note.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            Text(note.time)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.trailing, 6)
        }
        .frame(width: hourWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#1A3A38"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#4ECDC4").opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct NewNoteView: View {
    let selectedDate: Date
    let theme: AppTheme
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @State private var selectedHour = 9
    @State private var selectedMinute = 0
    @State private var isSaving = false

    private let hours = Array(8...22)
    private let minutes = [0, 15, 30, 45]

    private var timeString: String {
        String(format: "%02d:%02d", selectedHour, selectedMinute)
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: selectedDate)
    }

    private var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "d MMMM"; f.locale = Locale(identifier: "ru_RU")
        return f.string(from: selectedDate)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ДАТА")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 4)

                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(theme.accent)
                            Text(dateLabel)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ВРЕМЯ")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 4)

                        HStack(spacing: 0) {
                            Picker("Час", selection: $selectedHour) {
                                ForEach(hours, id: \.self) { h in
                                    Text(String(format: "%02d", h)).tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .clipped()

                            Text(":")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(theme.textPrimary)

                            Picker("Минуты", selection: $selectedMinute) {
                                ForEach(minutes, id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        }
                        .frame(height: 120)
                        .background(theme.backgroundCard)
                        .cornerRadius(12)
                        .colorScheme(theme == .platinum ? .light : .dark)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ЗАМЕТКА")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 4)

                        TextField("Что нужно сделать?", text: $noteText, axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(theme.backgroundCard)
                            .cornerRadius(12)
                            .tint(theme.accent)
                    }

                    Button {
                        guard !noteText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        isSaving = true
                        Task {
                            let req = PersonalNoteCreateRequest(date: dateString, time: timeString, text: noteText)
                            let _ = try? await APIClient.shared.request(.createNote(req), as: MessageResponse.self)
                            await MainActor.run {
                                isSaving = false
                                onSaved()
                                dismiss()
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Сохранить заметку")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .background(
                        noteText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? AnyShapeStyle(Color.gray.opacity(0.3))
                        : AnyShapeStyle(theme.gradientPrimary)
                    )
                    .cornerRadius(16)
                    .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
                .padding(20)
            }
            .background(theme.backgroundDeep.ignoresSafeArea())
            .navigationTitle("Личная заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
        }
    }
}

#Preview {
    ScheduleView()
        .environment(\.theme, .pink)
        .environmentObject(NotificationsViewModel())
}