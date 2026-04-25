import SwiftUI

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var selectedDate: Date       = Date()
    @Published var appointments: [Appointment] = []
    @Published var isLoading: Bool          = false
    @Published var selectedAppointment: Appointment? = nil

    private let api = APIClient.shared

    var dates: [Date] {
        let calendar = Calendar.current
        return (-3..<18).compactMap { calendar.date(byAdding: .day, value: $0, to: Date()) }
    }

    var selectedDateFormatted: String {
        let f = DateFormatter(); f.dateFormat = "d MMMM, EEEE"; f.locale = Locale(identifier: "ru_RU")
        return f.string(from: selectedDate)
    }

    func isToday(_ date: Date) -> Bool { Calendar.current.isDateInToday(date) }

    func loadSchedule() async {
        isLoading = true
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: selectedDate)
        if let resp = try? await api.request(.schedule(date: dateStr), as: ScheduleResponse.self) {
            appointments = resp.appointments.sorted { $0.time < $1.time }
        } else {
            appointments = MockData.appointments(for: dateStr)
        }
        isLoading = false
    }

    func cancelAppointment(_ id: Int) async {
        appointments.removeAll { $0.id == id }
        let _ = try? await api.request(.cancelAppointment(id: id), as: MessageResponse.self)
    }
}

struct ScheduleView: View {
    @StateObject private var vm = ScheduleViewModel()
    @Environment(\.theme) private var theme
    @State private var showNewAppointment = false

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            VStack(spacing: 0) {
                headerSection
                dateStrip
                if vm.isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    Spacer()
                } else {
                    appointmentsList
                }
            }
        }
        .task { await vm.loadSchedule() }
        .sheet(isPresented: $showNewAppointment) {
            NewAppointmentView(onCreated: { Task { await vm.loadSchedule() } })
                .environment(\.theme, theme)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Расписание").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text(vm.selectedDateFormatted)
                    .font(DS.body).foregroundColor(theme.textSecondary)
            }
            Spacer()
            HStack(spacing: DS.s12) {
                // Кнопка "сегодня"
                Button(action: {
                    withAnimation(DS.springSnappy) { vm.selectedDate = Date() }
                    Task { await vm.loadSchedule() }
                }) {
                    Text("Сегодня")
                        .font(DS.labelSmall)
                        .foregroundColor(theme.accent)
                        .padding(.horizontal, DS.s12)
                        .padding(.vertical, DS.s8)
                        .background(theme.accent.opacity(0.1))
                        .cornerRadius(DS.r8)
                }

                Button { Task { await vm.loadSchedule() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.accent)
                        .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                        .animation(vm.isLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                                   value: vm.isLoading)
                }
            }
        }
        .padding(.horizontal, DS.s20)
        .padding(.top, DS.s16)
        .padding(.bottom, DS.s12)
    }

    // MARK: - Date Strip

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.s6) {
                    ForEach(vm.dates, id: \.self) { date in
                        DateCell(date: date, isSelected: vm.selectedDate.isSameDay(as: date),
                                 isToday: vm.isToday(date), theme: theme)
                            .id(date)
                            .onTapGesture {
                                withAnimation(DS.springSnappy) { vm.selectedDate = date }
                                Task { await vm.loadSchedule() }
                            }
                    }
                }
                .padding(.horizontal, DS.s20)
            }
            .frame(height: 76)
            .onAppear {
                proxy.scrollTo(vm.selectedDate, anchor: .center)
            }
            .onChange(of: vm.selectedDate) { _, newDate in
                withAnimation(DS.springSnappy) { proxy.scrollTo(newDate, anchor: .center) }
            }
        }
    }

    // MARK: - Appointments List

    private var appointmentsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DS.s10) {
                if vm.appointments.isEmpty {
                    emptyState
                } else {
                    ForEach(vm.appointments) { appt in
                        AppointmentCard(appointment: appt, theme: theme)
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    Task { await vm.cancelAppointment(appt.id) }
                                }) {
                                    Label("Отменить запись", systemImage: "xmark.circle")
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, DS.s20)
            .padding(.top, DS.s12)
            .padding(.bottom, 100)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.s16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(theme.textMuted)
            Text("Нет записей").font(DS.headline).foregroundColor(theme.textPrimary)
            Text("Нажми + чтобы записать клиента").font(DS.body).foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}

// MARK: - Date Cell

struct DateCell: View {
    let date: Date; let isSelected: Bool; let isToday: Bool; let theme: AppTheme

    private var dayName: String {
        let f = DateFormatter(); f.dateFormat = "EEE"; f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date).prefix(2).uppercased()
    }
    private var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayName)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? theme.accent : theme.textMuted)
            ZStack {
                Circle()
                    .fill(isSelected ? theme.accent : (isToday ? theme.accent.opacity(0.15) : Color.clear))
                    .frame(width: 38, height: 38)
                Text(dayNumber)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : (isToday ? theme.accent : theme.textPrimary))
            }
        }
        .frame(width: 50, height: 68)
        .background(isSelected ? theme.accent.opacity(0.12) : Color.clear)
        .cornerRadius(DS.r12)
        .animation(DS.springSnappy, value: isSelected)
    }
}

// MARK: - Appointment Card

struct AppointmentCard: View {
    let appointment: Appointment
    let theme: AppTheme
    @State private var isPressed = false

    private var statusColor: Color {
        Color(hex: appointment.status.hexColor)
    }

    var body: some View {
        HStack(spacing: DS.s12) {
            // Время + статус-точка
            VStack(spacing: 6) {
                Text(appointment.time)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Circle().fill(statusColor).frame(width: 8, height: 8)
            }
            .frame(width: 44)

            // Контент
            VStack(alignment: .leading, spacing: 5) {
                Text(appointment.clientName ?? "Клиент")
                    .font(DS.label).foregroundColor(theme.textPrimary)
                HStack(spacing: DS.s6) {
                    Text(appointment.procedure)
                        .font(DS.body).foregroundColor(theme.textSecondary)
                    Text("·").foregroundColor(theme.textMuted)
                    Text("\(appointment.price)₽")
                        .font(DS.body).foregroundColor(theme.accent).fontWeight(.medium)
                }
                if let notes = appointment.notes, !notes.isEmpty {
                    Text(notes).font(DS.bodySmall).foregroundColor(theme.textMuted).lineLimit(1)
                }
            }

            Spacer()

            // Статус-бейдж
            Text(appointment.status.displayName)
                .font(DS.caption).fontWeight(.semibold)
                .foregroundColor(statusColor)
                .padding(.horizontal, DS.s8)
                .padding(.vertical, DS.s4)
                .background(statusColor.opacity(0.14))
                .cornerRadius(DS.r8)
        }
        .padding(DS.s14)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r16)
        .overlay(
            RoundedRectangle(cornerRadius: DS.r16)
                .stroke(statusColor.opacity(0.25), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DS.springSnappy, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}

// MARK: - DS Extension

extension DS {
    static let s6:  CGFloat = 6
    static let s10: CGFloat = 10
    static let s14: CGFloat = 14
}

// MARK: - Date Extension

extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

#Preview {
    ScheduleView().environment(\.theme, .pink)
}
