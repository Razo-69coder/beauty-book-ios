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
        }
    }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    @ObservedObject var vm: NotificationsViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingAppt: AppNotification? = nil
    @State private var processingId: Int? = nil

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()

                if vm.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                } else if vm.notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(theme.textMuted)
                        Text("Нет уведомлений")
                            .font(DS.body)
                            .foregroundColor(theme.textMuted)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.notifications) { notif in
                                NotificationRow(
                                    notif: notif, theme: theme,
                                    isProcessing: processingId == notif.id,
                                    onRead: { Task { await vm.markRead(notif.id) } },
                                    onConfirm: { confirmingAppt = notif },
                                    onCancel: {
                                        Task {
                                            guard let apptId = notif.appointmentId else { return }
                                            processingId = notif.id
                                            let ok = await vm.updateAppointmentStatus(apptId: apptId, status: .cancelled)
                                            if ok { vm.updateLocalApptStatus(notifId: notif.id, status: "cancelled") }
                                            processingId = nil
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Уведомления")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(theme.accent)
                }
                if vm.unreadCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Прочитать все") {
                            Task { await vm.markAllRead() }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(theme.accent)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await vm.load()
                await vm.markAllRead()
            }
        }
        .alert(confirmingAppt?.type == "client_reschedule" ? "Подтвердить перенос?" : "Подтвердить запись?",
               isPresented: Binding(
                get: { confirmingAppt != nil },
                set: { if !$0 { confirmingAppt = nil } }
               )) {
            Button("Подтвердить") {
                guard let notif = confirmingAppt, let apptId = notif.appointmentId else { return }
                Task {
                    processingId = notif.id
                    let ok = await vm.updateAppointmentStatus(apptId: apptId, status: .confirmed)
                    if ok { vm.updateLocalApptStatus(notifId: notif.id, status: "confirmed") }
                    processingId = nil
                    confirmingAppt = nil
                }
            }
            Button("Отмена", role: .cancel) { confirmingAppt = nil }
        } message: {
            if let a = confirmingAppt?.appointment {
                Text("\(a.clientName ?? "") · \(a.date ?? "") в \(a.time ?? "")")
            }
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notif: AppNotification
    let theme: AppTheme
    let isProcessing: Bool
    let onRead: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var iconAndColor: (String, Color) {
        switch notif.type {
        case "new_booking":     return ("calendar.badge.plus", Color(hex: "#FF69B4"))
        case "client_cancel":   return ("xmark.circle.fill", .red)
        case "client_reschedule": return ("arrow.triangle.2.circlepath", Color(hex: "#9370DB"))
        case "broadcast":       return ("sparkles", Color(hex: "#9370DB"))
        default:                return ("bell.fill", Color(hex: "#FF69B4"))
        }
    }

    private var timeAgo: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: notif.createdAt) ?? {
            let f2 = DateFormatter(); f2.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return f2.date(from: notif.createdAt)
        }() else { return "" }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "только что" }
        if diff < 3600 { return "\(diff/60) мин назад" }
        if diff < 86400 { return "\(diff/3600) ч назад" }
        return "\(diff/86400) дн назад"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconAndColor.1.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconAndColor.0)
                        .font(.system(size: 16))
                        .foregroundColor(iconAndColor.1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notif.title)
                            .font(DS.label)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(timeAgo)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMuted)
                        if !notif.isRead {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                        }
                    }
                    Text(notif.body)
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let appt = notif.appointment,
               notif.type == "new_booking" || notif.type == "client_reschedule" {
                if appt.status == "pending" {
                    HStack(spacing: 8) {
                        Button(action: onCancel) {
                            Group {
                                if isProcessing {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .red)).scaleEffect(0.8)
                                } else {
                                    Text("Отменить").font(DS.labelSmall).foregroundColor(.red)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(DS.r8)
                        }
                        .disabled(isProcessing)
                        Button(action: onConfirm) {
                            Text("Подтвердить")
                                .font(DS.labelSmall)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(theme.gradientPrimary)
                                .cornerRadius(DS.r8)
                        }
                        .disabled(isProcessing)
                    }
                } else if appt.status == "confirmed" {
                    Label("Подтверждено", systemImage: "checkmark.circle.fill")
                        .font(DS.labelSmall)
                        .foregroundColor(.green)
                } else if appt.status == "cancelled" {
                    Label("Отменено", systemImage: "xmark.circle.fill")
                        .font(DS.labelSmall)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(notif.isRead ? theme.backgroundCard : theme.backgroundCard.opacity(1.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(notif.isRead ? theme.borderSubtle : theme.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture { if !notif.isRead { onRead() } }
    }
}
