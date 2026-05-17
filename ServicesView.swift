import SwiftUI

struct ServicesView: View {
    @StateObject private var viewModel = ServicesViewModel()
    @State private var searchText: String = ""
    @State private var listOpacity: Double = 0
    @State private var showAddSheet: Bool = false
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            searchBar
            servicesList
            addButton
        }
        .background(theme.backgroundDeep)
        .sheet(isPresented: $showAddSheet) {
            AddServiceSheet(viewModel: viewModel)
        }
        .onAppear {
            Task { await viewModel.loadServices() }
            withAnimation(DS.springSmooth.delay(0.1)) {
                listOpacity = 1.0
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Услуги")
                        .font(DS.titleLarge)
                        .foregroundColor(theme.textPrimary)
                    Text("\(viewModel.total) услуг")
                        .font(DS.body)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
                Button {
                    Task { await viewModel.loadServices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.accent)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(theme.textMuted)

            TextField("Поиск услуг", text: $searchText)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.backgroundInput)
        .cornerRadius(DS.r12)
        .overlay(
            RoundedRectangle(cornerRadius: DS.r12)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var filteredServices: [Service] {
        if searchText.isEmpty {
            return viewModel.services
        }
        return viewModel.services.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedServices: [(String, [Service])] {
        let grouped = Dictionary(grouping: filteredServices) { $0.category }
        return grouped.sorted { $0.key < $1.key }
    }

    private var servicesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.services.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedServices, id: \.0) { category, services in
                        VStack(alignment: .leading, spacing: 8) {
                            BBSectionHeader(title: category)

                            ForEach(services) { service in
                                ServiceCard(service: service, onDelete: {
                                    Task { await viewModel.deleteService(service) }
                                }, onEdit: { name, price, duration, category in
                                    Task { await viewModel.updateService(service, name: name, price: price, duration: duration, category: category) }
                                })
                                .environment(\.theme, theme)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .opacity(listOpacity)
        .scrollDismissesKeyboard(.immediately)
    }

    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Добавить услугу")
                    .font(DS.label)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.gradientPrimary)
            .cornerRadius(DS.r16)
            .shadow(color: theme.accentGlow, radius: 20, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 120)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scissors")
                .font(.system(size: 40))
                .foregroundColor(theme.textMuted)
            Text("Нет услуг")
                .font(DS.headline)
                .foregroundColor(theme.textPrimary)
            Text("Добавьте свои услуги")
                .font(DS.body)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}

struct ServiceCard: View {
    let service: Service
    let onDelete: () -> Void
    var onEdit: ((String, Int, Int, String) -> Void)? = nil
    @Environment(\.theme) private var theme
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 44, height: 44)
                Image(systemName: "scissors")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                HStack(spacing: 8) {
                    Text("\(service.priceDefault)₽")
                        .font(DS.label)
                        .foregroundColor(theme.accent)
                    Text("·")
                        .foregroundColor(theme.textMuted)
                    Text("\(service.durationMin) мин")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button { showEditSheet = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(theme.accent.opacity(0.8))
                }
                Button { showDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(theme.statusRed.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r16)
        .overlay(
            RoundedRectangle(cornerRadius: DS.r16)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .confirmationDialog("Удалить услугу?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) { onDelete() }
        }
        .sheet(isPresented: $showEditSheet) {
            EditServiceSheet(service: service, onSave: { name, price, duration, category in
                onEdit?(name, price, duration, category)
            })
            .environment(\.theme, theme)
        }
    }
}

struct AddServiceSheet: View {
    @ObservedObject var viewModel: ServicesViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var price: String = ""
    @State private var duration: Int = 60
    @State private var category: String = "Основные"

    private let categories = ["Основные", "Маникюр", "Педикюр", "Ресницы", "Брови", "Макияж", "Массаж", "Другое"]
    private let durationOptions = [30, 45, 60, 90, 120, 180]

    func durationLabel(_ mins: Int) -> String {
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)ч \(m)м" : "\(h)ч"
        }
        return "\(mins)м"
    }

    var isValid: Bool { !name.isEmpty && !price.isEmpty }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название услуги")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                        BBTextField(placeholder: "Например: Маникюр классический", text: $name)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Категория")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                        Menu {
                            ForEach(categories, id: \.self) { cat in
                                Button(cat) { category = cat }
                            }
                        } label: {
                            HStack {
                                Text(category)
                                    .font(DS.body)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textMuted)
                            }
                            .padding(16)
                            .background(theme.backgroundInput)
                            .cornerRadius(DS.r12)
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Цена")
                                .font(DS.bodySmall)
                                .foregroundColor(theme.textMuted)
                            HStack {
                                BBTextField(placeholder: "0", text: $price, keyboardType: .numberPad)
                                Text("₽")
                                    .font(DS.body)
                                    .foregroundColor(theme.textMuted)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Длительность")
                                .font(DS.bodySmall)
                                .foregroundColor(theme.textMuted)
                            Menu {
                                ForEach(durationOptions, id: \.self) { mins in
                                    Button(durationLabel(mins)) { duration = mins }
                                }
                            } label: {
                                HStack {
                                    Text(durationLabel(duration))
                                        .font(DS.body)
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.textMuted)
                                }
                                .padding(16)
                                .background(theme.backgroundInput)
                                .cornerRadius(DS.r12)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(theme.backgroundDeep)
            .navigationTitle("Новая услуга")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(theme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Добавить") {
                        if let priceInt = Int(price) {
                            Task {
                                await viewModel.addService(name: name, price: priceInt, duration: duration, category: category)
                                dismiss()
                            }
                        }
                    }
                    .foregroundColor(isValid ? theme.accent : theme.textMuted)
                    .disabled(!isValid)
                }
            }
        }
    }
}

@MainActor
final class ServicesViewModel: ObservableObject {
    @Published var services: [Service] = []
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var total: Int = 0

    private let api = APIClient.shared

    var categories: [String] {
        Array(Set(services.map { $0.category })).sorted()
    }

    func loadServices() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.request(.services, as: ServicesResponse.self)
            services = response.services
            total = response.services.count
        } catch {
            services = []
            total = 0
            errorMessage = "Нет подключения к интернету"
        }

        isLoading = false
    }

    func addService(name: String, price: Int, duration: Int = 60, category: String = "Основные") async {
        let request = ServiceCreateRequest(name: name, priceDefault: price, durationMin: duration, category: category)
        do {
            let newService = try await api.request(.createService(request), as: Service.self)
            services.insert(newService, at: 0)
            total += 1
        } catch {
            let tempService = Service(id: Int.random(in: 1000...9999), name: name, priceDefault: price, durationMin: duration, category: category)
            services.insert(tempService, at: 0)
            total += 1
        }
    }

    func deleteService(_ service: Service) async {
        do {
            let _ = try await api.request(.deleteService(id: service.id), as: MessageResponse.self)
            services.removeAll { $0.id == service.id }
            total -= 1
        } catch {
            services.removeAll { $0.id == service.id }
            total -= 1
        }
    }

    func updateService(_ service: Service, name: String, price: Int, duration: Int, category: String) async {
        let req = ServiceCreateRequest(name: name, priceDefault: price, durationMin: duration, category: category)
        do {
            let _ = try await api.request(.updateService(id: service.id, req), as: MessageResponse.self)
            if let idx = services.firstIndex(where: { $0.id == service.id }) {
                services[idx] = Service(id: service.id, name: name, priceDefault: price, durationMin: duration, category: category)
            }
        } catch {}
    }
}

struct EditServiceSheet: View {
    let service: Service
    let onSave: (String, Int, Int, String) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var price: String
    @State private var duration: Int
    @State private var category: String

    private let categories = ["Основные", "Маникюр", "Педикюр", "Ресницы", "Брови", "Макияж", "Массаж", "Другое"]
    private let durationOptions = [15, 30, 45, 60, 90, 120, 150, 180, 210, 240]

    init(service: Service, onSave: @escaping (String, Int, Int, String) -> Void) {
        self.service = service
        self.onSave = onSave
        _name = State(initialValue: service.name)
        _price = State(initialValue: "\(service.priceDefault)")
        _duration = State(initialValue: service.durationMin)
        _category = State(initialValue: service.category)
    }

    func durationLabel(_ mins: Int) -> String {
        if mins >= 60 {
            let h = mins / 60; let m = mins % 60
            return m > 0 ? "\(h)ч \(m)м" : "\(h)ч"
        }
        return "\(mins)м"
    }

    var isValid: Bool { !name.isEmpty && !price.isEmpty }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название").font(DS.bodySmall).foregroundColor(theme.textMuted)
                        BBTextField(placeholder: "Название услуги", text: $name).environment(\.theme, theme)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Категория").font(DS.bodySmall).foregroundColor(theme.textMuted)
                        Menu {
                            ForEach(categories, id: \.self) { cat in Button(cat) { category = cat } }
                        } label: {
                            HStack {
                                Text(category).font(DS.body).foregroundColor(theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 12)).foregroundColor(theme.textMuted)
                            }
                            .padding(16).background(theme.backgroundInput).cornerRadius(DS.r12)
                        }
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Цена").font(DS.bodySmall).foregroundColor(theme.textMuted)
                            HStack {
                                BBTextField(placeholder: "0", text: $price, keyboardType: .numberPad).environment(\.theme, theme)
                                Text("₽").font(DS.body).foregroundColor(theme.textMuted)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Длительность").font(DS.bodySmall).foregroundColor(theme.textMuted)
                            Menu {
                                ForEach(durationOptions, id: \.self) { mins in Button(durationLabel(mins)) { duration = mins } }
                            } label: {
                                HStack {
                                    Text(durationLabel(duration)).font(DS.body).foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.system(size: 12)).foregroundColor(theme.textMuted)
                                }
                                .padding(16).background(theme.backgroundInput).cornerRadius(DS.r12)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(theme.backgroundDeep)
            .navigationTitle("Редактировать услугу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundColor(theme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        if let priceInt = Int(price) {
                            onSave(name, priceInt, duration, category)
                            dismiss()
                        }
                    }
                    .foregroundColor(isValid ? theme.accent : theme.textMuted)
                    .disabled(!isValid)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ServicesView()
            .environment(\.theme, .pink)
    }
}