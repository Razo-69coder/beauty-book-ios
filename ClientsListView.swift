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
            VStack(spacing: 0) {
                header
                searchBar
                if vm.isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    Spacer()
                } else if vm.filtered.isEmpty {
                    emptyState
                } else {
                    clientsList
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

    private var fabButton: some View {
        Button(action: { vm.showAddSheet = true }) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(theme.gradientPrimary)
                .clipShape(Circle())
                .shadow(color: theme.accentGlow, radius: 12, x: 0, y: 6)
        }
        .padding(.bottom, 100)
        .padding(.trailing, 20)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Клиенты").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text("\(vm.clients.count) клиентов").font(DS.body).foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.s20)
        .padding(.top, DS.s16)
        .padding(.bottom, DS.s8)
    }

    private var searchBar: some View {
        HStack(spacing: DS.s8) {
            Image(systemName: "magnifyingglass").foregroundColor(theme.textMuted).font(.system(size: 16))
            ZStack(alignment: .leading) {
                if vm.searchText.isEmpty {
                    Text("Поиск по имени или телефону").foregroundColor(theme.textMuted).font(DS.body)
                }
                TextField("", text: $vm.searchText).font(DS.body).foregroundColor(theme.textPrimary)
            }
        }
        .padding(.horizontal, DS.s12)
        .frame(height: 44)
        .background(theme.backgroundInput)
        .cornerRadius(DS.r12)
        .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.borderSubtle, lineWidth: 1))
        .padding(.horizontal, DS.s20)
        .padding(.bottom, DS.s8)
    }

    private var clientsList: some View {
        List {
            ForEach(vm.filtered) { client in
                ClientRow(client: client, theme: theme)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: DS.s20, bottom: 4, trailing: DS.s20))
                    .onTapGesture { vm.selectedClient = client }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(client: client) }
                        } label: { Label("Удалить", systemImage: "trash") }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.backgroundDeep)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.2.slash").font(.system(size: 48)).foregroundColor(theme.textMuted)
            Text(vm.searchText.isEmpty ? "Нет клиентов" : "Ничего не найдено")
                .font(DS.headline).foregroundColor(theme.textPrimary)
            Text(vm.searchText.isEmpty ? "Добавь первого клиента, нажав +" : "Попробуй другой запрос")
                .font(DS.body).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)
            Spacer()
        }.padding(.horizontal, DS.s32)
    }
}

// MARK: - Client Row

struct ClientRow: View {
    let client: Client
    let theme: AppTheme
    @State private var isPressed = false

    private var initials: String {
        let parts = client.name.split(separator: " ")
        return ((parts.first.map { String($0.prefix(1)) } ?? "") + (parts.dropFirst().first.map { String($0.prefix(1)) } ?? "")).uppercased()
    }

    private var lastVisitText: String {
        guard let lv = client.lastVisit else { return "Нет визитов" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: lv) else { return lv }
        let f2 = DateFormatter(); f2.dateFormat = "d MMM"; f2.locale = Locale(identifier: "ru_RU")
        return f2.string(from: d)
    }

    var body: some View {
        HStack(spacing: DS.s12) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.15)).frame(width: 48, height: 48)
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name).font(DS.label).foregroundColor(theme.textPrimary)
                Text(client.phone).font(DS.body).foregroundColor(theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(lastVisitText).font(DS.caption).foregroundColor(theme.textMuted)
                if let notes = client.notes, !notes.isEmpty {
                    Text(notes).font(DS.caption).foregroundColor(theme.accent.opacity(0.8)).lineLimit(1)
                }
            }
        }
        .padding(DS.s12)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r16)
        .overlay(RoundedRectangle(cornerRadius: DS.r16).stroke(theme.borderSubtle, lineWidth: 1))
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
    @State private var name = ""; @State private var phone = ""; @State private var notes = ""
    private var isValid: Bool { !name.isEmpty && !phone.isEmpty }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()
                VStack(spacing: DS.s16) {
                    BBTextField(placeholder: "Имя клиента", text: $name).environment(\.theme, theme)
                    BBTextField(placeholder: "+7 (___) ___-__-__", text: $phone, keyboardType: .phonePad).environment(\.theme, theme)
                    BBTextField(placeholder: "Заметка (необязательно)", text: $notes).environment(\.theme, theme)
                    BBPrimaryButton(title: "Добавить клиента", isDisabled: !isValid) {
                        Task { await vm.add(name: name, phone: phone, notes: notes) }
                        dismiss()
                    }.environment(\.theme, theme)
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
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ClientsListView().environment(\.theme, .pink)
}
