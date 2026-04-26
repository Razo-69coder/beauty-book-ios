import SwiftUI

// MARK: - Clients ViewModel

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published var clients: [Client]       = []
    @Published var isLoading               = false
    @Published var searchText              = ""
    @Published var selectedClient: Client? = nil
    @Published var showAddSheet            = false

    private let api = APIClient.shared

    var filtered: [Client] {
        guard !searchText.isEmpty else { return clients }
        return clients.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.phone.contains(searchText) }
    }

    var totalVisits: Int {
        clients.reduce(0) { $0 + ($1.appointmentsCount ?? 0) }
    }

    func load() async {
        isLoading = true
        do {
            let resp = try await api.request(.clients(page: 0, search: ""), as: ClientsResponse.self)
            clients = resp.clients
        } catch { clients = MockData.clients }
        isLoading = false
    }

    func delete(client: Client) async {
        clients.removeAll { $0.id == client.id }
        do { let _ = try await api.request(.deleteClient(id: client.id), as: MessageResponse.self) }
        catch { clients.append(client) }
    }

    func add(name: String, phone: String, notes: String) async {
        do {
            let _ = try await api.request(.createClient(ClientCreateRequest(name: name, phone: phone, notes: notes)), as: MessageResponse.self)
            await load()
        } catch {
            let temp = Client(id: Int.random(in: 10000...99999), name: name, phone: phone, notes: notes, lastVisit: nil, username: nil, telegramId: nil)
            clients.insert(temp, at: 0)
        }
    }
}

// MARK: - Clients List View

struct ClientsListView: View {
    @StateObject private var vm = ClientsViewModel()
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            theme.backgroundDeep.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    searchBar
                    if vm.isLoading {
                        Spacer().frame(height: 200)
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                        Spacer()
                    } else if vm.filtered.isEmpty {
                        emptyState
                    } else {
                        clientsList
                    }
                }
            }
            fabButton
        }
        .task { await vm.load() }
        .sheet(isPresented: $vm.showAddSheet) {
            AddClientSheet(vm: vm).environment(\.theme, theme)
        }
        .sheet(item: $vm.selectedClient) { client in
            ClientDetailView(client: client).environment(\.theme, theme)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            ambientGlow
            VStack(alignment: .leading, spacing: 4) {
                Text("Клиентская база")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text("\(vm.clients.count) клиентов")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textMuted)
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

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.textMuted)
                .font(.system(size: 16))
            TextField("Поиск по имени или телефону", text: $vm.searchText)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
            if !vm.searchText.isEmpty {
                Button(action: { vm.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.backgroundInput)
        .cornerRadius(DS.r16)
        .overlay(
            RoundedRectangle(cornerRadius: DS.r16)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Clients List

    private var clientsList: some View {
        VStack(spacing: 8) {
            ForEach(vm.filtered) { client in
                ClientCard(client: client, theme: theme)
                    .onTapGesture { vm.selectedClient = client }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 100)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            if vm.searchText.isEmpty {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 40))
                    .foregroundColor(theme.accent.opacity(0.4))
                Text("Нет клиентов")
                    .font(DS.headline)
                    .foregroundColor(theme.textSecondary)
                Text("Добавьте первого клиента, нажав +")
                    .font(DS.body)
                    .foregroundColor(theme.textMuted)
            } else {
                Image(systemName: "person.slash")
                    .font(.system(size: 40))
                    .foregroundColor(theme.accent.opacity(0.4))
                Text("Клиент не найден")
                    .font(DS.headline)
                    .foregroundColor(theme.textSecondary)
                Text("Попробуйте другой запрос")
                    .font(DS.body)
                    .foregroundColor(theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button(action: {
            HapticManager.medium()
            vm.showAddSheet = true
        }) {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 58, height: 58)
                    .shadow(color: theme.accentGlow, radius: 12, x: 0, y: 6)
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.bottom, 100)
        .padding(.trailing, 20)
    }
}

// MARK: - Client Card

struct ClientCard: View {
    let client: Client
    let theme: AppTheme
    @State private var isPressed = false

    private var initials: String {
        let parts = client.name.split(separator: " ")
        return ((parts.first.map { String($0.prefix(1)) } ?? "") + (parts.dropFirst().first.map { String($0.prefix(1)) } ?? "")).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 48, height: 48)
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(DS.headline)
                    .foregroundColor(theme.textPrimary)
                Text(client.phone)
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(client.appointmentsCount ?? 0) визитов")
                    .font(DS.labelSmall)
                    .foregroundColor(theme.textMuted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textMuted.opacity(0.5))
            }
        }
        .padding(16)
        .background(theme.backgroundCard)
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
}

// MARK: - Add Client Sheet

struct AddClientSheet: View {
    @ObservedObject var vm: ClientsViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var notes = ""
    private var isValid: Bool { !name.isEmpty && !phone.isEmpty }

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            VStack(spacing: DS.s16) {
                BBTextField(placeholder: "Имя клиента", text: $name)
                    .environment(\.theme, theme)
                BBTextField(placeholder: "+7 (___) ___-__-__", text: $phone, keyboardType: .phonePad)
                    .environment(\.theme, theme)
                BBTextField(placeholder: "Заметка (необязательно)", text: $notes)
                    .environment(\.theme, theme)
                BBPrimaryButton(title: "Добавить клиента", isDisabled: !isValid) {
                    Task { await vm.add(name: name, phone: phone, notes: notes) }
                    dismiss()
                }
                .environment(\.theme, theme)
                Spacer()
            }
            .padding(DS.s20)
        }
        .navigationTitle("Новый клиент")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Отмена") { dismiss() }.foregroundColor(theme.accent)
            }
        }
    }
}

#Preview {
    ClientsListView().environment(\.theme, .pink)
}