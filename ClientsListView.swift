import SwiftUI
import Contacts

// MARK: - Contacts Importer

struct ContactImporter {
    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    static func fetchContacts() async -> [(name: String, phone: String)] {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        var contacts: [(name: String, phone: String)] = []

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                for phoneNumber in contact.phoneNumbers {
                    let phone = phoneNumber.value.stringValue
                    if !name.isEmpty && !phone.isEmpty {
                        contacts.append((name: name, phone: phone))
                    }
                }
            }
        } catch {
            print("Error fetching contacts: \(error)")
        }

        return contacts
    }
}

// MARK: - Contacts Picker Sheet

struct ContactsPickerSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var contacts: [(name: String, phone: String)] = []
    @State private var isLoading = true
    @State private var hasAccess = false
    @State private var searchText = ""

    let onSelect: (String, String) -> Void

    private var filteredContacts: [(name: String, phone: String)] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.contains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                        Text("Загрузка контактов...")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                    }
                } else if !hasAccess {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(theme.textMuted)
                        Text("Доступ к контактам запрещён")
                            .font(DS.headline)
                            .foregroundColor(theme.textPrimary)
                        Text("Разрешите доступ в Настройки → Конфиденциальность → Контакты")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else if contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(theme.textMuted)
                        Text("Контакты не найдены")
                            .font(DS.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(theme.textMuted)
                            TextField("Поиск", text: $searchText)
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                        }
                        .padding(12)
                        .background(theme.backgroundInput)
                        .cornerRadius(DS.r12)
                        .padding(20)

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(filteredContacts.enumerated()), id: \.offset) { _, contact in
                                    Button {
                                        onSelect(contact.name, contact.phone)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(theme.gradientPrimary)
                                                    .frame(width: 40, height: 40)
                                                Text(contact.name.prefix(1).uppercased())
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(contact.name)
                                                    .font(DS.body)
                                                    .foregroundColor(theme.textPrimary)
                                                Text(contact.phone)
                                                    .font(DS.bodySmall)
                                                    .foregroundColor(theme.textMuted)
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle")
                                                .foregroundColor(theme.accent)
                                        }
                                        .padding(12)
                                        .background(theme.backgroundCard)
                                        .cornerRadius(DS.r12)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .navigationTitle("Импорт из контактов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
        }
        .task {
            hasAccess = await ContactImporter.requestAccess()
            if hasAccess {
                contacts = await ContactImporter.fetchContacts()
            }
            isLoading = false
        }
    }
}

// MARK: - Clients View Model

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published var clients: [Client]       = []
    @Published var isLoading               = false
    @Published var searchText              = ""
    @Published var selectedClient: Client? = nil
    @Published var showAddSheet            = false
    @Published var prefillName: String      = ""
    @Published var prefillPhone: String    = ""

    var name: String {
        get { prefillName }
        set { prefillName = newValue }
    }

    var phone: String {
        get { prefillPhone }
        set { prefillPhone = newValue }
    }

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
    @State private var showImportContacts = false

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
            .sheet(isPresented: $showImportContacts) {
                ContactsPickerSheet { name, phone in
                    vm.name = name
                    vm.phone = phone
                    vm.showAddSheet = true
                }
                .environment(\.theme, theme)
            }
            .sheet(item: $vm.selectedClient) { client in
                ClientDetailView(client: client).environment(\.theme, theme)
            }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            ambientGlow
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Клиентская база")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    Text("\(vm.clients.count) клиентов")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
                Button {
                    showImportContacts = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 22))
                        .foregroundColor(theme.accent)
                }
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
        .padding(.bottom, 140)
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
        Button {
            HapticManager.medium()
            vm.showAddSheet = true
        } label: {
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
        let name = client.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return "?" }
        let first = name[name.startIndex]
        if name.count > 1 {
            if let spaceIdx = name.firstIndex(of: " ") {
                let afterSpace = name.index(after: spaceIdx)
                if afterSpace < name.endIndex {
                    let second = name[afterSpace]
                    return "\(first)\(second)".uppercased()
                }
            }
        }
        return String(first).uppercased()
    }

    private var loyaltyThreshold: Int {
        UserDefaults.standard.integer(forKey: "loyalty_threshold") == 0 ? 10 : UserDefaults.standard.integer(forKey: "loyalty_threshold")
    }

    private var visitCount: Int { client.appointmentsCount ?? 0 }

    private func visitWord(_ count: Int) -> String {
        let rem100 = count % 100
        let rem10  = count % 10
        if rem100 >= 11 && rem100 <= 19 { return "визитов" }
        switch rem10 {
        case 1:        return "визит"
        case 2, 3, 4:  return "визита"
        default:       return "визитов"
        }
    }

    private var progressToNextReward: String {
        let threshold = loyaltyThreshold
        let remainder = threshold - (visitCount % threshold)
        if remainder == threshold { return "🏆 Скидка!" }
        return "\(remainder) до скидки"
    }

    private var isBirthdayToday: Bool {
        guard let bday = client.birthday else { return false }
        let parts = bday.split(separator: "-").map { String($0) }
        guard let monthStr = parts.first,
              let dayStr = parts.dropFirst().first,
              let month = Int(monthStr),
              let day = Int(dayStr) else { return false }
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
                    Text("\(visitCount) \(visitWord(visitCount))")
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
        let parts = bday.split(separator: "-").map { String($0) }
        guard let monthStr = parts.first,
              let dayStr = parts.dropFirst().first,
              let month = Int(monthStr),
              let day = Int(dayStr) else { return bday }
        let months = ["","Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]
        guard month >= 1 && month <= 12 else { return bday }
        return "\(day) \(months[month])"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0D0B0E").ignoresSafeArea()
                if let img = UIImage(named: "bg_pink") {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: UIScreen.main.bounds.width,
                            height: UIScreen.main.bounds.height
                        )
                        .clipped()
                        .ignoresSafeArea()
                }
                Color.black.opacity(0.5).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s12) {
                        BBTextField(placeholder: "Имя клиента", text: $name)
                            .environment(\.theme, theme)
                        BBTextField(placeholder: "+7 (___) ___-__-__", text: $phone, keyboardType: .phonePad)
                            .environment(\.theme, theme)
                        BBTextField(placeholder: "Заметка (необязательно)", text: $notes)
                            .environment(\.theme, theme)

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
                        .environment(\.theme, theme)
                    }
                    .padding(DS.s20)
                    .padding(.top, 8)
                }
                .ignoresSafeArea(.keyboard)
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
}

#Preview {
    ClientsListView().environment(\.theme, .pink)
}