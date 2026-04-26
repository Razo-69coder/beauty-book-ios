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

    func add(name: String, phone: String, notes: String, birthday: String) async {
        do {
            let _ = try await api.request(.createClient(ClientCreateRequest(name: name, phone: phone, notes: notes)), as: MessageResponse.self)
            await load()
        } catch {
            let temp = Client(id: Int.random(in: 10000...99999), name: name, phone: phone, notes: notes, lastVisit: nil, username: nil, telegramId: nil, birthday: birthday.isEmpty ? nil : birthday)
            clients.insert(temp, at: 0)
        }
    }
}

// MARK: - Clients List View

struct ClientsListView: View {
    @StateObject private var vm = ClientsViewModel()
    @Environment(\.theme) private var theme

    var body: some View {
        Color.clear
            .overlay {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                        searchBar
                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else if vm.filtered.isEmpty {
                            emptyState
                        } else {
                            clientsList
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
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
        .padding(.bottom, 120)
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
        .padding(.bottom, 110)
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

    private var loyaltyThreshold: Int {
        UserDefaults.standard.integer(forKey: "loyalty_threshold") == 0 ? 10 : UserDefaults.standard.integer(forKey: "loyalty_threshold")
    }

    private var visitCount: Int { client.appointmentsCount ?? 0 }

    private var progressToNextReward: String {
        let threshold = loyaltyThreshold
        let remainder = threshold - (visitCount % threshold)
        if remainder == threshold { return "🏆 Скидка!" }
        return "\(remainder) до скидки"
    }

    private var isBirthdayToday: Bool {
        guard let bday = client.birthday else { return false }
        let parts = bday.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[0]), let day = Int(parts[1]) else { return false }
        let cal = Calendar.current; let now = Date()
        return cal.component(.month, from: now) == month && cal.component(.day, from: now) == day
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

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    if isBirthdayToday {
                        Text("🎂")
                            .font(.system(size: 14))
                    }
                    Text("\(visitCount) визитов")
                        .font(DS.labelSmall)
                        .foregroundColor(theme.textMuted)
                }
                Text(progressToNextReward)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(progressToNextReward == "🏆 Скидка!" ? theme.accent : theme.textMuted.opacity(0.7))
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
    @State private var birthday = ""
    @State private var showBirthdayPicker = false
    @State private var birthdayDate = Date()
    private var isValid: Bool { !name.isEmpty && !phone.isEmpty }

    private func formattedBirthday(_ bday: String) -> String {
        let parts = bday.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[0]), let day = Int(parts[1]) else { return bday }
        let months = ["","Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]
        guard month >= 1 && month <= 12 else { return bday }
        return "\(day) \(months[month])"
    }

    var body: some View {
        ZStack {
            Color(hex: "#0D0B0E").ignoresSafeArea()
            if let img = UIImage(named: "bg_pink") {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.6)
            }
            Color.black.opacity(0.4).ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.s16) {
                    BBTextField(placeholder: "Имя клиента", text: $name)
                    BBTextField(placeholder: "+7 (___) ___-__-__", text: $phone, keyboardType: .phonePad)
                    BBTextField(placeholder: "Заметка (необязательно)", text: $notes)

                    Button(action: { showBirthdayPicker.toggle() }) {
                        HStack {
                            Image(systemName: "gift")
                                .foregroundColor(birthday.isEmpty ? theme.textMuted : theme.accent)
                            Text(birthday.isEmpty ? "День рождения (необязательно)" : formattedBirthday(birthday))
                                .font(DS.body)
                                .foregroundColor(birthday.isEmpty ? theme.textMuted : theme.textPrimary)
                            Spacer()
                            if !birthday.isEmpty {
                                Button(action: { birthday = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(theme.textMuted)
                                }
                            }
                        }
                        .padding(16)
                        .background(theme.backgroundInput)
                        .cornerRadius(DS.r12)
                        .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.borderSubtle, lineWidth: 1))
                    }

                    if showBirthdayPicker {
                        DatePicker("", selection: $birthdayDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .accentColor(theme.accent)
                            .colorScheme(.dark)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .onChange(of: birthdayDate) { _, newDate in
                                let f = DateFormatter(); f.dateFormat = "MM-dd"
                                birthday = f.string(from: newDate)
                                showBirthdayPicker = false
                            }
                    }

                    BBPrimaryButton(title: "Добавить клиента", isDisabled: !isValid) {
                        Task { await vm.add(name: name, phone: phone, notes: notes, birthday: birthday) }
                        dismiss()
                    }
                    Spacer()
                }
                .padding(DS.s20)
            }
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