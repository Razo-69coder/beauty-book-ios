import SwiftUI

struct ClientDetailView: View {
    let client: Client
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var history: [AppointmentHistory] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s20) {
                        avatarSection
                        contactsSection
                        if !history.isEmpty { historySection }
                    }
                    .padding(.horizontal, DS.s20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Карточка клиента")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }.foregroundColor(theme.accent)
                }
            }
            .task {
                isLoading = true
                // Попытка загрузить историю
                if let resp = try? await APIClient.shared.request(.clientDetail(id: client.id), as: ClientDetail.self) {
                    history = resp.history
                } else {
                    history = MockData.history(for: client.id)
                }
                isLoading = false
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var initials: String {
        let parts = client.name.split(separator: " ")
        return ((parts.first.map { String($0.prefix(1)) } ?? "") + (parts.dropFirst().first.map { String($0.prefix(1)) } ?? "")).uppercased()
    }

    private var avatarSection: some View {
        VStack(spacing: DS.s12) {
            ZStack {
                Circle().fill(theme.gradientPrimary).frame(width: 80, height: 80)
                    .shadow(color: theme.accentGlow, radius: 16, x: 0, y: 6)
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(client.name).font(DS.titleSmall).foregroundColor(theme.textPrimary)
            if let notes = client.notes, !notes.isEmpty {
                Text(notes).font(DS.body).foregroundColor(theme.textSecondary)
                    .padding(.horizontal, DS.s16)
                    .padding(.vertical, DS.s8)
                    .background(theme.accent.opacity(0.1))
                    .cornerRadius(DS.r8)
            }
        }
        .padding(.top, DS.s16)
    }

    private var contactsSection: some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: "Контакты").environment(\.theme, theme)

            BBCard {
                VStack(spacing: DS.s12) {
                    ContactRow(icon: "phone.fill", label: "Телефон", value: client.phone, theme: theme)
                    if let username = client.username, !username.isEmpty {
                        Divider().background(theme.borderSubtle)
                        ContactRow(icon: "paperplane.fill", label: "Telegram", value: "@\(username)", theme: theme)
                    }
                    if let lastVisit = client.lastVisit {
                        Divider().background(theme.borderSubtle)
                        ContactRow(icon: "calendar", label: "Последний визит", value: formatDate(lastVisit), theme: theme)
                    }
                }
            }.environment(\.theme, theme)
        }
    }

    private var historySection: some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: "История визитов (\(history.count))").environment(\.theme, theme)
            ForEach(history) { item in
                HistoryCard(item: item, theme: theme)
            }
        }
    }

    private func formatDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        let f2 = DateFormatter(); f2.dateFormat = "d MMMM yyyy"; f2.locale = Locale(identifier: "ru_RU")
        return f2.string(from: d)
    }
}

struct ContactRow: View {
    let icon: String; let label: String; let value: String; let theme: AppTheme
    var body: some View {
        HStack(spacing: DS.s12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(theme.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(DS.caption).foregroundColor(theme.textMuted)
                Text(value).font(DS.body).foregroundColor(theme.textPrimary)
            }
            Spacer()
        }
    }
}

struct HistoryCard: View {
    let item: AppointmentHistory; let theme: AppTheme
    private func formatDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        let f2 = DateFormatter(); f2.dateFormat = "d MMM yyyy"; f2.locale = Locale(identifier: "ru_RU")
        return f2.string(from: d)
    }
    var body: some View {
        HStack(spacing: DS.s12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.procedure).font(DS.label).foregroundColor(theme.textPrimary)
                Text(formatDate(item.appointmentDate)).font(DS.bodySmall).foregroundColor(theme.textMuted)
            }
            Spacer()
            Text("\(item.price)₽").font(DS.headline).foregroundColor(theme.accent)
        }
        .padding(DS.s12)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r12)
        .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

#Preview {
    ClientDetailView(client: MockData.clients[0]).environment(\.theme, .pink)
}
