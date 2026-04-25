import SwiftUI

// MARK: - ViewModel

@MainActor
final class NewAppointmentViewModel: ObservableObject {
    @Published var selectedClient: Client?   = nil
    @Published var selectedService: Service? = nil
    @Published var selectedDate: Date        = Date()
    @Published var selectedTime: String      = ""
    @Published var price: String             = ""
    @Published var notes: String             = ""
    @Published var availableSlots: [String]  = []
    @Published var clients: [Client]         = []
    @Published var services: [Service]       = []
    @Published var isLoading                 = false
    @Published var isSaving                  = false
    @Published var errorMessage: String?     = nil

    var onCreated: (() -> Void)?

    var isValid: Bool {
        selectedClient != nil && selectedService != nil && !selectedTime.isEmpty
    }

    private let api = APIClient.shared

    func loadData() async {
        isLoading = true
        async let clientsResult: () = loadClients()
        async let servicesResult: () = loadServices()
        _ = await (clientsResult, servicesResult)
        await loadSlots()
        isLoading = false
    }

    private func loadClients() async {
        if let resp = try? await api.request(.clients(page: 0, search: ""), as: ClientsResponse.self) {
            clients = resp.clients
        } else {
            clients = MockData.clients
        }
    }

    private func loadServices() async {
        if let resp = try? await api.request(.services, as: ServicesResponse.self) {
            services = resp.services
        } else {
            services = MockData.services
        }
    }

    func loadSlots() async {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: selectedDate)
        if let resp = try? await api.request(.slots(date: dateStr), as: SlotsResponse.self) {
            availableSlots = resp.slots
        } else {
            // Мок-слоты
            availableSlots = stride(from: 9 * 60, to: 20 * 60, by: 60).map { m in
                String(format: "%02d:%02d", m / 60, m % 60)
            }
        }
        if !availableSlots.contains(selectedTime) { selectedTime = availableSlots.first ?? "" }
    }

    func save() async {
        guard let client = selectedClient, let service = selectedService, !selectedTime.isEmpty else { return }
        isSaving = true; errorMessage = nil
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let req = AppointmentCreateRequest(
            clientId: client.id, procedure: service.name,
            appointmentDate: f.string(from: selectedDate),
            time: selectedTime, price: Int(price) ?? service.priceDefault, notes: notes
        )
        do {
            let _ = try await api.request(.createAppointment(req), as: MessageResponse.self)
            onCreated?()
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка при создании записи" }
        isSaving = false
    }
}

// MARK: - View

struct NewAppointmentView: View {
    @StateObject private var vm = NewAppointmentViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var onCreated: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()
                if vm.isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                } else {
                    formContent
                }
            }
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundColor(theme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") { Task { await vm.save() } }
                        .font(DS.label)
                        .foregroundColor(vm.isValid ? theme.accent : theme.textMuted)
                        .disabled(!vm.isValid || vm.isSaving)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            vm.onCreated = { dismiss(); onCreated?() }
            await vm.loadData()
        }
    }

    private var formContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.s20) {
                // Клиент
                sectionBlock(title: "Клиент") {
                    ClientPickerRow(vm: vm, theme: theme)
                }

                // Услуга
                sectionBlock(title: "Услуга") {
                    ServicePickerRow(vm: vm, theme: theme)
                }

                // Дата
                sectionBlock(title: "Дата") {
                    DatePicker("", selection: $vm.selectedDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .accentColor(theme.accent)
                        .colorScheme(.dark)
                        .onChange(of: vm.selectedDate) { _ in Task { await vm.loadSlots() } }
                }

                // Время
                if !vm.availableSlots.isEmpty {
                    sectionBlock(title: "Время") {
                        SlotPicker(slots: vm.availableSlots, selected: $vm.selectedTime, theme: theme)
                    }
                }

                // Цена и заметка
                sectionBlock(title: "Детали") {
                    VStack(spacing: DS.s12) {
                        BBTextField(placeholder: "Цена (₽)", text: $vm.price, keyboardType: .numberPad)
                            .environment(\.theme, theme)
                        BBTextField(placeholder: "Заметка", text: $vm.notes)
                            .environment(\.theme, theme)
                    }
                }

                if let err = vm.errorMessage {
                    BBErrorBanner(message: err).environment(\.theme, theme)
                }

                BBPrimaryButton(title: vm.isSaving ? "Сохраняю..." : "Записать клиента",
                                isLoading: vm.isSaving,
                                isDisabled: !vm.isValid) {
                    Task { await vm.save() }
                }.environment(\.theme, theme)
            }
            .padding(.horizontal, DS.s20)
            .padding(.bottom, 40)
        }
    }

    private func sectionBlock<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: title).environment(\.theme, theme)
            BBCard { content() }.environment(\.theme, theme)
        }
    }
}

// MARK: - Slot Picker

struct SlotPicker: View {
    let slots: [String]
    @Binding var selected: String
    let theme: AppTheme
    let columns = [GridItem(.adaptive(minimum: 72), spacing: DS.s8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.s8) {
            ForEach(slots, id: \.self) { slot in
                Text(slot)
                    .font(DS.label)
                    .foregroundColor(selected == slot ? .white : theme.textSecondary)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DS.r8)
                            .fill(selected == slot ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                    )
                    .cornerRadius(DS.r8)
                    .onTapGesture { withAnimation(DS.springSnappy) { selected = slot } }
            }
        }
    }
}

// MARK: - Picker Rows

struct ClientPickerRow: View {
    @ObservedObject var vm: NewAppointmentViewModel
    let theme: AppTheme
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                if let client = vm.selectedClient {
                    Text(client.name).font(DS.body).foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(client.phone).font(DS.bodySmall).foregroundColor(theme.textSecondary)
                } else {
                    Text("Выбрать клиента").font(DS.body).foregroundColor(theme.textMuted)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(theme.textMuted)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            PickerSheet(title: "Клиент", items: vm.clients, itemTitle: { $0.name }, itemSubtitle: { $0.phone }) { client in
                vm.selectedClient = client
                showPicker = false
            }
            .environment(\.theme, theme)
        }
    }
}

struct ServicePickerRow: View {
    @ObservedObject var vm: NewAppointmentViewModel
    let theme: AppTheme
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                if let service = vm.selectedService {
                    Text(service.name).font(DS.body).foregroundColor(theme.textPrimary)
                    Spacer()
                    Text("\(service.priceDefault)₽").font(DS.bodySmall).foregroundColor(theme.accent)
                } else {
                    Text("Выбрать услугу").font(DS.body).foregroundColor(theme.textMuted)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(theme.textMuted)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            PickerSheet(title: "Услуга", items: vm.services, itemTitle: { $0.name }, itemSubtitle: { "\($0.priceDefault)₽ · \($0.durationMin) мин" }) { service in
                vm.selectedService = service
                vm.price = "\(service.priceDefault)"
                showPicker = false
            }
            .environment(\.theme, theme)
        }
    }
}

// MARK: - Generic Picker Sheet

struct PickerSheet<T: Identifiable>: View {
    let title: String
    let items: [T]
    let itemTitle: (T) -> String
    let itemSubtitle: (T) -> String
    let onSelect: (T) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()
                List {
                    ForEach(items) { item in
                        Button(action: { onSelect(item) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(itemTitle(item)).font(DS.label).foregroundColor(theme.textPrimary)
                                    Text(itemSubtitle(item)).font(DS.bodySmall).foregroundColor(theme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(theme.backgroundCard)
                        .listRowSeparatorTint(theme.borderSubtle)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(theme.backgroundDeep)
            }
            .navigationTitle(title)
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
    NewAppointmentView().environment(\.theme, .pink)
}
