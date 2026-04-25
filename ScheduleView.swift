import SwiftUI

struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var calendarOffset: CGFloat = 0
    @State private var selectedDateOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            dateSelector
            
            appointmentsList
        }
        .background(Color(hex: "#080810"))
        .onAppear {
            Task { await viewModel.loadSchedule() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                selectedDateOpacity = 1.0
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Расписание")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let date = viewModel.selectedDateFormatted {
                    Text(date)
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "#A0A0C0"))
                }
            }
            Spacer()
            
            Button {
                Task { await viewModel.loadSchedule() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#FF2D78"))
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
    
    private var dateSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.dates, id: \.self) { date in
                        DateCell(
                            date: date,
                            isSelected: viewModel.selectedDate == date,
                            isToday: viewModel.isToday(date)
                        )
                        .id(date)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedDate = date
                            }
                            Task { await viewModel.loadSchedule() }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .opacity(selectedDateOpacity)
            .onChange(of: viewModel.selectedDate) { newDate in
                withAnimation(.spring(response: 0.3)) {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
        }
        .frame(height: 72)
    }
    
    private var appointmentsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FF2D78")))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.appointments.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.appointments) { appointment in
                        AppointmentCard(appointment: appointment)
                            .onTapGesture {
                                viewModel.selectedAppointment = appointment
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#5A5A7A"))
            
            Text("Нет записей")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Нажми + чтобы создать запись")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#5A5A7A"))
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}

struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitaled
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayName)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? Color(hex: "#FF2D78") : Color(hex: "#5A5A7A"))
            
            ZStack {
                Circle()
                    .fill(isSelected ? Color(hex: "#FF2D78") : Color.clear)
                    .frame(width: 36, height: 36)
                
                Text(dayNumber)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : (isToday ? Color(hex: "#FF2D78") : .white))
            }
        }
        .frame(width: 48, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color(hex: "#FF2D78").opacity(0.15) : Color.clear)
        )
    }
}

struct AppointmentCard: View {
    let appointment: Appointment
    @State private var isPressed = false
    
    private var statusColor: Color {
        switch appointment.status {
        case .confirmed: return Color(hex: "#00E5A0")
        case .pending: return Color(hex: "#FFD166")
        case .completed: return Color(hex: "#4ECDC4")
        case .cancelled: return Color(hex: "#FF4757")
        }
    }
    
    private var timeFormatted: String {
        appointment.time
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(timeFormatted)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(appointment.clientName ?? "Клиент")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(appointment.procedure)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#A0A0C0"))
                    
                    Text("•")
                        .foregroundColor(Color(hex: "#5A5A7A"))
                    
                    Text("\(appointment.price)₽")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#FF2D78"))
                }
                
                if let notes = appointment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#5A5A7A"))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            statusBadge
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#11111E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    private var statusBadge: some View {
        Text(appointment.status.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .cornerRadius(8)
    }
}

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var appointments: [Appointment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedAppointment: Appointment? = nil
    
    private let api = APIClient.shared
    
    private var dates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<14).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 3, to: today)
        }
    }
    
    var selectedDateFormatted: String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, EEEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: selectedDate)
    }
    
    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    func loadSchedule() async {
        isLoading = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)
        
        do {
            let response = try await api.request(.schedule(date: dateString), type: ScheduleResponse.self)
            appointments = response.appointments.sorted { $0.time < $1.0.time }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    ScheduleView()
        .preferredColorScheme(.dark)
}