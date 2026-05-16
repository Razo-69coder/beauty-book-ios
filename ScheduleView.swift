import SwiftUI

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var appointments: [Appointment] = []
    @Published var isLoading: Bool = false
    @Published var selectedAppointment: Appointment? = nil
    @Published var showNewAppointment: Bool = false
    @Published var preselectedTime: String? = nil

    private let api = APIClient.shared
    private let calendar = Calendar.current

    var dates: [Date] {
        (-180..<185).compactMap { offset -> Date? in
            guard let d = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            return calendar.startOfDay(for: d)
        }
    }

    var selectedDateFormatted: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"; f.locale = Locale(identifier: "ru_RU")
        return f.string(from: selectedDate)
    }

    var isToday: Bool { calendar.isDateInToday(selectedDate) }

    func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }

    func hourSlots() -> [Int] {
        Array(8...22)
    }

    func appointmentsForHour(_ hour: Int) -> [Appointment] {
        appointments.filter { appt in
            let timeParts = appt.time.split(separator: ":")
            guard let hourStr = timeParts.first,
                  let apptHour = Int(hourStr) else { return false }
            return apptHour == hour
        }
    }

    func appointmentsBeforeHour(_ hour: Int) -> [Appointment] {
        appointments.filter { appt in
            let timeParts = appt.time.split(separator: ":")
            guard let hourStr = timeParts.first,
                  let apptHour = Int(hourStr) else { return false }
            return apptHour < hour
        }
    }

    func positionForAppointment(_ appt: Appointment) -> CGFloat {
        let timeParts = appt.time.split(separator: ":")
        guard let hourStr = timeParts.first,
              let hour = Int(hourStr) else { return 0 }
        let minute: Int
        if timeParts.count > 1, let m = Int(timeParts[1]) {
            minute = m
        } else {
            minute = 0
        }
        let startHour = 8.0
        let hourHeight: CGFloat = 60
        return CGFloat(hour - Int(startHour)) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }

    func heightForAppointment(_ appt: Appointment) -> CGFloat {
        let duration = appt.duration ?? 60
        let hourHeight: CGFloat = 60
        return CGFloat(duration) / 60.0 * hourHeight
    }

    func loadSchedule() async {
        isLoading = true
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: selectedDate)
        if let resp = try? await api.request(.schedule(date: dateStr), as: ScheduleResponse.self) {
            appointments = resp.appointments.filter { $0.status != .cancelled }.sorted { $0.time < $1.time }
        } else {
            appointments = []
        }
        isLoading = false
    }

    func cancelAppointment(_ id: Int) async {
        appointments.removeAll { $0.id == id }
        let _ = try? await api.request(.cancelAppointment(id: id), as: MessageResponse.self)
    }

    func selectSlot(hour: Int) {
        preselectedTime = String(format: "%02d:00", hour)
        showNewAppointment = true
    }
}

struct ScheduleView: View {
    @StateObject private var vm = ScheduleViewModel()
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            theme.backgroundDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                monthHeader
                    .padding(.horizontal, 20)
                dateStrip
                summaryBar

                if vm.isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    Spacer()
                } else {
                    timelineView
                }
            }

            fabButton
        }
        .sheet(isPresented: $vm.showNewAppointment) {
            NewAppointmentView(preselectedTime: vm.preselectedTime, selectedDate: vm.selectedDate)
                .environment(\.theme, theme)
        }
        .sheet(item: $vm.selectedAppointment) { appt in
            AppointmentDetailSheet(appointment: appt, theme: theme, onCancel: {
                Task { await vm.cancelAppointment(appt.id) }
                vm.selectedAppointment = nil
            }, onEdit: {
                vm.selectedAppointment = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    editingAppointment = appt
                }
            })
        }
        .sheet(item: $editingAppointment) { appt in
            EditAppointmentView(appointment: appt, onUpdated: {
                editingAppointment = nil
                Task { await vm.loadSchedule() }
            })
                .environment(\.theme, theme)
        }
        .task { await vm.loadSchedule() }
        .onChange(of: vm.selectedDate) { _, _ in
            Task { await vm.loadSchedule() }
        }
    }

    @State private var statusActionAppointment: Appointment? = nil
    @State private var editingAppointment: Appointment? = nil
    @State private var showMonthPicker = false
    @State private var pickerMonth = Date()

    private func showStatusActions(for appt: Appointment) {
        statusActionAppointment = appt
    }

    private func changeStatus(for appt: Appointment, to newStatus: AppointmentStatus) {
        guard appt.status != newStatus else { return }
        Task {
            try? await APIClient.shared.updateAppointmentStatus(id: appt.id, status: newStatus)
            if let idx = vm.appointments.firstIndex(where: { $0.id == appt.id }) {
                var updated = vm.appointments[idx]
                updated = Appointment(
                    id: updated.id, clientId: updated.clientId, masterId: updated.masterId,
                    procedure: updated.procedure, appointmentDate: updated.appointmentDate,
                    time: updated.time, price: updated.price, notes: updated.notes,
                    status: newStatus, depositStatus: updated.depositStatus,
                    depositAmount: updated.depositAmount, clientName: updated.clientName,
                    clientPhone: updated.clientPhone, serviceDoneAt: updated.serviceDoneAt,
                    duration: updated.duration
                )
                vm.appointments[idx] = updated
            }
            HapticManager.success()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Привет, Мастер 👋")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textMuted)
                    Text(vm.selectedDateFormatted)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var monthHeader: some View {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.locale = Locale(identifier: "ru_RU")
        let text = f.string(from: vm.selectedDate)
        return Text(text.prefix(1).uppercased() + text.dropFirst())
            .font(DS.headline)
            .foregroundColor(theme.textPrimary)
            .onTapGesture {
                pickerMonth = vm.selectedDate
                showMonthPicker = true
            }
            .sheet(isPresented: $showMonthPicker) {
                MonthPickerView(
                    selectedDate: $vm.selectedDate,
                    pickerMonth: $pickerMonth,
                    dates: vm.dates,
                    theme: theme
                )
            }
    }

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.dates, id: \.self) { date in
                        DateCapsule(
                            date: date,
                            isSelected: vm.selectedDate.isSameDay(as: date),
                            isToday: vm.isToday(date),
                            theme: theme
                        )
                        .id(date)
                        .onTapGesture {
                            HapticManager.selection()
                            withAnimation(DS.springSnappy) { vm.selectedDate = date }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 76)
            .background(theme.backgroundDeep.opacity(0.95))
            .onAppear {
                proxy.scrollTo(vm.selectedDate, anchor: .center)
            }
            .onChange(of: vm.selectedDate) { _, newDate in
                withAnimation(DS.springSnappy) { proxy.scrollTo(newDate, anchor: .center) }
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(vm.appointments.count)")
                        .font(DS.label)
                    Text("записей")
                        .font(DS.caption)
                }
            }
            .foregroundColor(theme.textMuted)

            HStack(spacing: 6) {
                Image(systemName: "rublesign.circle")
                    .font(.system(size: 12))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(vm.appointments.reduce(0) { $0 + $1.price })")
                        .font(DS.label)
                    Text("выручка")
                        .font(DS.caption)
                }
            }
            .foregroundColor(theme.accent)

            Spacer()
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(theme.backgroundCard.opacity(0.5))
    }

    private var timelineView: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                hoursColumn

                appointmentsLayer
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    private var hoursColumn: some View {
        VStack(spacing: 0) {
            ForEach(vm.hourSlots(), id: \.self) { hour in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textMuted.opacity(0.7))
                        .frame(width: 42, alignment: .trailing)

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(
                                theme == .platinum
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color(hex: "#C9A96E").opacity(0.0),
                                             Color(hex: "#C9A96E").opacity(0.25),
                                             Color(hex: "#C9A96E").opacity(0.0)],
                                    startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Color.clear,
                                             Color(hex: "#FF2D78").opacity(0.15),
                                             Color.clear],
                                    startPoint: .leading, endPoint: .trailing))
                            )
                            .frame(height: 1)
                        Spacer()
                    }
                }
                .frame(height: 60, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.selection()
                    vm.selectSlot(hour: hour)
                }
            }
        }
        .padding(.leading, 4)
    }

    private var appointmentsLayer: some View {
        GeometryReader { geometry in
            let hourWidth: CGFloat = geometry.size.width - 52

            ForEach(Array(vm.appointments.enumerated()), id: \.element.id) { index, appt in
                AppointmentBlock(
                    appointment: appt,
                    theme: theme,
                    hourWidth: hourWidth,
                    colorIndex: index
                )
                .offset(y: vm.positionForAppointment(appt))
                .frame(height: vm.heightForAppointment(appt))
                .onTapGesture {
                    HapticManager.selection()
                    vm.selectedAppointment = appt
                }
            }
        }
    }

    private var fabButton: some View {
        Button {
            HapticManager.medium()
            vm.preselectedTime = nil
            vm.showNewAppointment = true
        } label: {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 52, height: 52)
                    .shadow(color: theme.accentGlow, radius: 12, x: 0, y: 6)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 20)
        .padding(.bottom, 120)
    }
}

struct AppointmentBlock: View {
    let appointment: Appointment
    let theme: AppTheme
    let hourWidth: CGFloat
    let colorIndex: Int
    
    private let pinkPalette = ["#501260", "#7E367A", "#B05994", "#E37DAC", "#FFB1C4"]
    private let platinumPalette = ["#C49994", "#CEA39E", "#D8B2AE", "#EBD0C2", "#CFB0A2"]
    
    private var palette: [String] {
        theme == .platinum ? platinumPalette : pinkPalette
    }
    
    private var blockColor: Color {
        Color(hex: palette[colorIndex % palette.count])
    }
    
    private var textColor: Color {
        let hex = palette[colorIndex % palette.count].lowercased().replacingOccurrences(of: "#", with: "")
        let darkColors = ["501260", "7e367a", "b05994", "c49994", "cea39e", "d8b2ae"]
        return darkColors.contains(where: { hex.hasPrefix($0) }) ? .white : Color(hex: "#3D2B2B")
    }

    private var statusColor: Color { Color(hex: appointment.status.hexColor) }

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.leading, 6)

            RoundedRectangle(cornerRadius: 2)
                .fill(
                    theme == .platinum
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "#C9A96E"), Color(hex: "#E8C99A")],
                        startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "#FF2D78"), Color(hex: "#7B2FFF")],
                        startPoint: .top, endPoint: .bottom))
                )
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.clientName ?? "Клиент")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                Text(appointment.procedure)
                    .font(.system(size: 11))
                    .foregroundColor(textColor.opacity(0.85))
                    .lineLimit(1)

                if (appointment.duration ?? 60) > 30 {
                    Text("\(appointment.time) · \(appointment.duration ?? 60) мин")
                        .font(.system(size: 10))
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(appointment.price)₽")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(textColor.opacity(0.9))
                .padding(.trailing, 8)
        }
        .frame(width: hourWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(blockColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(blockColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AppointmentDetailSheet: View {
    let appointment: Appointment
    let theme: AppTheme
    let onCancel: () -> Void
    var onEdit: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private var statusColor: Color { Color(hex: appointment.status.hexColor) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(theme.gradientPrimary)
                                .frame(width: 72, height: 72)
                            Text((appointment.clientName ?? "К").prefix(1).uppercased())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text(appointment.clientName ?? "Клиент")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textPrimary)

                        Text(appointment.procedure)
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 0) {
                        detailRow(icon: "calendar", title: "Дата", value: appointment.appointmentDate)
                        Divider().background(theme.borderSubtle)
                        detailRow(icon: "clock", title: "Время", value: appointment.time)
                        Divider().background(theme.borderSubtle)
                        detailRow(icon: "timer", title: "Длительность", value: "\(appointment.duration ?? 60) мин")
                        Divider().background(theme.borderSubtle)
                        detailRow(icon: "rublesign.circle", title: "Цена", value: "\(appointment.price)₽")
                        if appointment.status != .completed && appointment.status != .cancelled {
                            Divider().background(theme.borderSubtle)
                            detailRow(icon: "clock.badge.checkmark", title: "Статус", value: appointment.status.displayName, valueColor: statusColor)
                        }
                    }
                    .background(theme.backgroundCard)
                    .cornerRadius(DS.r16)

                    VStack(spacing: 12) {
                        if let onEdit = onEdit {
                            Button {
                                onEdit()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Редактировать")
                                }
                                .font(DS.body)
                                .foregroundColor(theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(theme.accent.opacity(0.1))
                                .cornerRadius(DS.r12)
                            }
                        }

                        Menu {
                            ForEach(AppointmentStatus.allCases.filter { $0 != appointment.status }, id: \.self) { status in
                                Button {
                                    Task {
                                        try? await APIClient.shared.updateAppointmentStatus(id: appointment.id, status: status)
                                        dismiss()
                                    }
                                } label: {
                                    HStack {
                                        Circle().fill(Color(hex: status.hexColor)).frame(width: 10, height: 10)
                                        Text(status.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.swap")
                                Text("Изменить статус")
                            }
                            .font(DS.body)
                            .foregroundColor(theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(theme.accent.opacity(0.1))
                            .cornerRadius(DS.r12)
                        }

                        if appointment.status != .completed && appointment.status != .cancelled && appointment.status != .noShow {
                            Button(role: .destructive) {
                                onCancel()
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text("Отменить запись")
                                }
                                .font(DS.body)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(DS.r12)
                            }
                        }
                    }
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
    }

    private func detailRow(icon: String, title: String, value: String, valueColor: Color? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 24)

            Text(title)
                .font(DS.body)
                .foregroundColor(theme.textSecondary)

            Spacer()

            Text(value)
                .font(DS.body)
                .foregroundColor(valueColor ?? theme.textPrimary)
        }
        .padding(16)
    }
}

struct DateCapsule: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let theme: AppTheme

    private var dayName: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; f.locale = Locale(identifier: "ru_RU")
        return String(f.string(from: date).prefix(2)).uppercased()
    }

    private var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayName)
                .font(DS.labelSmall)
                .foregroundColor(isSelected ? .white : theme.textMuted)

            Text(dayNumber)
                .font(DS.headline)
                .foregroundColor(isSelected ? .white : theme.textPrimary)
        }
        .frame(width: 44, height: 64)
        .background(
            Capsule()
                .fill(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(Color.clear))
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.clear : (isToday ? theme.accent.opacity(0.4) : Color.clear), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(color: isSelected ? theme.accentGlow : .clear, radius: isSelected ? 8 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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

#Preview {
    ScheduleView()
        .environment(\.theme, .pink)
}