import SwiftUI

struct ClientDetailView: View {
    let client: Client
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var history: [AppointmentHistory] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroSection
                    statsSection
                    contactsSection
                    if !history.isEmpty {
                        historySection
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .task {
            isLoading = true
            if let resp = try? await APIClient.shared.request(.clientDetail(id: client.id), as: ClientDetail.self) {
                history = resp.history
            } else {
                history = MockData.history(for: client.id)
            }
            isLoading = false
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(theme.gradientPrimary.opacity(0.15))
                .frame(height: 160)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.gradientPrimary)
                        .frame(width: 72, height: 72)
                        .shadow(color: theme.accentGlow, radius: 16)
                    Text(initials.isEmpty ? "?" : initials)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(client.name)
                    .font(DS.titleSmall)
                    .foregroundColor(theme.textPrimary)
                Text(client.phone)
                    .font(DS.body)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.bottom, 20)
        }
    }

    private var initials: String {
        let parts = client.name.split(separator: " ")
        return ((parts.first.map { String($0.prefix(1)) } ?? "") + (parts.dropFirst().first.map { String($0.prefix(1)) } ?? "")).uppercased()
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(visitsCount)", label: "Визитов")
            StatTile(value: totalRevenue, label: "Выручка")
            StatTile(value: lastVisitDate, label: "Последний визит")
        }
        .padding(.horizontal, 20)
    }

    private var visitsCount: Int {
        client.appointmentsCount ?? history.count
    }

    private var totalRevenue: String {
        let total = history.reduce(0) { $0 + $1.price }
        return total > 0 ? "\(total)₽" : "—"
    }

    private var lastVisitDate: String {
        guard let last = history.first?.appointmentDate else { return "—" }
        return formatShortDate(last)
    }

    // MARK: - Contacts Section

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Контакты")

            BBGlassCard {
                VStack(spacing: 12) {
                    ContactRow(icon: "phone.fill", label: "Телефон", value: client.phone, theme: theme)
                    if let username = client.username, !username.isEmpty {
                        Divider().background(theme.borderSubtle)
                        ContactRow(icon: "paperplane.fill", label: "Telegram", value: "@\(username)", theme: theme)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "История визитов")

            ForEach(history) { item in
                AppointmentHistoryCard(item: item, theme: theme)
            }
        }
        .padding(.horizontal, 20)
    }

    private func formatShortDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        let f2 = DateFormatter(); f2.dateFormat = "d MMM"; f2.locale = Locale(identifier: "ru_RU")
        return f2.string(from: d)
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    let value: String
    let label: String
    @Environment(\.theme) private var theme

    var body: some View {
        BBGlassCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(DS.titleSmall)
                    .foregroundColor(theme.accent)
                Text(label)
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let icon: String
    let label: String
    let value: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
                Text(value)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
            }
            Spacer()
        }
    }
}

// MARK: - Appointment History Card

struct AppointmentHistoryCard: View {
    let item: AppointmentHistory
    let theme: AppTheme

    private var statusColor: Color {
        switch item.status.lowercased() {
        case "completed": return theme.statusGreen
        case "cancelled": return theme.statusRed
        default: return theme.statusYellow
        }
    }

    private func formatDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        let f2 = DateFormatter(); f2.dateFormat = "d MMM yyyy"; f2.locale = Locale(identifier: "ru_RU")
        return f2.string(from: d)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.procedure)
                        .font(DS.headline)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(item.time)
                        .font(DS.labelSmall)
                        .foregroundColor(theme.textMuted)
                }

                HStack(spacing: 6) {
                    Text(formatDate(item.appointmentDate))
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                    Spacer()
                    Text("\(item.price)₽")
                        .font(DS.label)
                        .foregroundColor(theme.accent)
                }
            }
            .padding(16)
        }
        .background(theme.backgroundCard)
        .cornerRadius(DS.r16)
        .overlay(
            RoundedRectangle(cornerRadius: DS.r16)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

#Preview {
    ClientDetailView(client: MockData.clients[0])
        .environment(\.theme, .pink)
}