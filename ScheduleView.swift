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

    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

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

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    dateStrip
                    if vm.isLoading {
                        Spacer().frame(height: 200)
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                        Spacer()
                    } else {
                        appointmentsList
                    }
                }
            }
        }
        .task { await vm.loadSchedule() }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            ambientGlow
            VStack(alignment: .leading, spacing: 4) {
                Text("Привет, Мастер 👋")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textMuted)
                Text("Расписание")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var ambientGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [glowColor, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 80
                )
            )
            .frame(width: 300, height: 200)
            .offset(x: -60, y: -40)
            .blur(radius: 80)
    }

    private var glowColor: Color {
        switch theme {
        case .pink: return theme.accent.opacity(0.15)
        case .platinum: return Color(hex: "#C9A84C").opacity(0.08)
        }
    }

    // MARK: - Date Strip

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
                            Task { await vm.loadSchedule() }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 80)
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
        VStack(alignment: .leading, spacing: 12) {
            if vm.isToday {
                BBSectionHeader(title: "Сегодня, \(formattedDate)")
            } else {
                BBSectionHeader(title: formattedDate)
            }

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
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 100)
    }

    private var formattedDate: String {
        let f = DateFormatter(); f.dateFormat = "d MMMM"; f.locale = Locale(identifier: "ru_RU")
        return f.string(from: vm.selectedDate)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(theme.accent.opacity(0.5))
            Text("Нет записей на этот день")
                .font(DS.headline)
                .foregroundColor(theme.textSecondary)
            Text("Нажмите + чтобы добавить запись")
                .font(DS.body)
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Date Capsule

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
        VStack(spacing: 6) {
            Text(dayName)
                .font(DS.labelSmall)
                .foregroundColor(isSelected ? .white : theme.textMuted)

            Text(dayNumber)
                .font(DS.headline)
                .foregroundColor(isSelected ? .white : theme.textPrimary)
        }
        .frame(width: 44, height: 68)
        .background(
            Capsule()
                .fill(isSelected ? theme.gradientPrimary : (isToday ? theme.backgroundInput : Color.clear))
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.clear : (isToday ? theme.accent.opacity(0.3) : Color.clear), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(color: isSelected ? theme.accentGlow : .clear, radius: isSelected ? 8 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
        HStack(spacing: 0) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(appointment.clientName ?? "Клиент")
                        .font(DS.headline)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Text(appointment.time)
                        .font(DS.labelSmall)
                        .foregroundColor(theme.textMuted)
                }

                Text(appointment.procedure)
                    .font(DS.body)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    statusBadge
                    Spacer()
                    Text("\(appointment.price)₽")
                        .font(DS.label)
                        .foregroundColor(theme.accent)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.r16)
                    .fill(theme.backgroundCard)
                RoundedRectangle(cornerRadius: DS.r16)
                    .fill(.ultraThinMaterial.opacity(0.3))
            }
        )
        .cornerRadius(DS.r16)
        .overlay(
            RoundedRectangle(cornerRadius: DS.r16)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DS.springSnappy, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }

    private var statusBadge: some View {
        Text(appointment.status.displayName)
            .font(DS.caption)
            .fontWeight(.semibold)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .cornerRadius(DS.rFull)
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
    ScheduleView()
        .environment(\.theme, .pink)
}