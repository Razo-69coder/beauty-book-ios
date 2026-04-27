import SwiftUI
import UIKit

// MARK: - ViewModel

@MainActor
final class NewAppointmentViewModel: ObservableObject {
    @Published var selectedClient: Client? = nil
    @Published var selectedService: Service? = nil
    @Published var selectedDate: Date = Date()
    @Published var selectedTime: String = ""
    @Published var price: String = ""
    @Published var notes: String = ""
    @Published var availableSlots: [String] = []
    @Published var clients: [Client] = []
    @Published var services: [Service] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String? = nil

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
            availableSlots = stride(from: 9 * 60, to: 20 * 60, by: 60).map { m in
                String(format: "%02d:%02d", m / 60, m % 60)
            }
        }
        if !availableSlots.contains(selectedTime) { selectedTime = availableSlots.first ?? "" }
    }

    func save() async {
        guard let client = selectedClient, let service = selectedService, !selectedTime.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let req = AppointmentCreateRequest(
            clientId: client.id, procedure: service.name,
            appointmentDate: f.string(from: selectedDate),
            time: selectedTime, price: Int(price) ?? service.priceDefault, notes: notes
        )
        do {
            let _ = try await api.request(.createAppointment(req), as: MessageResponse.self)
            HapticManager.success()
            onCreated?()
        } catch let e as NetworkError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = "Ошибка при создании записи"
        }
        isSaving = false
    }
}

// MARK: - View

struct NewAppointmentView: View {
    @StateObject private var vm = NewAppointmentViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()

            if vm.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
            } else {
                formContent
            }
        }
        .task {
            vm.onCreated = { dismiss() }
            await vm.loadData()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 0) {
            dragIndicator
            customHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    sectionView(index: 0, title: "Клиент") {
                        ClientPickerRow(vm: vm, theme: theme)
                    }

                    sectionView(index: 1, title: "Услуга") {
                        ServicePickerRow(vm: vm, theme: theme)
                    }

                    sectionView(index: 2, title: "Дата и время") {
                        VStack(spacing: 16) {
                            DatePicker("", selection: $vm.selectedDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .accentColor(theme.accent)
                                .colorScheme(.dark)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                .onChange(of: vm.selectedDate) { _, _ in
                                    HapticManager.selection()
                                    Task { await vm.loadSlots() }
                                }

                            if !vm.availableSlots.isEmpty {
                                SlotPicker(slots: vm.availableSlots, selected: $vm.selectedTime, theme: theme)
                            }
                        }
                    }

                    sectionView(index: 3, title: "Детали") {
                        VStack(spacing: 12) {
                            BBTextField(placeholder: "Цена (₽)", text: $vm.price, keyboardType: .numberPad)
                            BBTextField(placeholder: "Заметка", text: $vm.notes)
                        }
                    }
                    .environment(\.theme, theme)

                    if let err = vm.errorMessage {
                        BBErrorBanner(message: err).environment(\.theme, theme)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(.keyboard)

            saveButton
        }
    }

    private var dragIndicator: some View {
        Capsule()
            .fill(theme.textMuted.opacity(0.3))
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
    }

    private var customHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Text("Отмена")
                        .font(DS.body)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
                Text("Новая запись")
                    .font(DS.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button(action: { Task { await vm.save() } }) {
                    Text("Сохранить")
                        .font(DS.label)
                        .foregroundColor(theme.accent)
                }
                .disabled(!vm.isValid)
                .opacity(vm.isValid ? 1 : 0.4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()
                .background(theme.borderSubtle)
        }
    }

    private func sectionView<C: View>(index: Int, title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BBSectionHeader(title: title)
            BBGlassCard {
                content()
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08), value: appeared)
        }
        .environment(\.theme, theme)
    }

    private var saveButton: some View {
        BBPrimaryButton(
            title: vm.isSaving ? "Сохраняю..." : "Создать запись",
            isLoading: vm.isSaving,
            isDisabled: !vm.isValid
        ) {
            Task { await vm.save() }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .environment(\.theme, theme)
    }
}

// MARK: - Slot Picker

struct SlotPicker: View {
    let slots: [String]
    @Binding var selected: String
    let theme: AppTheme

    var columns = [GridItem(.adaptive(minimum: 72), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
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
                    .onTapGesture {
                        HapticManager.selection()
                        withAnimation(DS.springSnappy) { selected = slot }
                    }
            }
        }
    }
}

// MARK: - Picker Rows

struct ClientPickerRow: View {
    @ObservedObject var vm: NewAppointmentViewModel
    let theme: AppTheme
    @State private var showPicker = false

    private var initials: String {
        guard let client = vm.selectedClient else { return "" }
        let parts = client.name.split(separator: " ")
        return ((parts.first.map { String($0.prefix(1)) } ?? "") + (parts.dropFirst().first.map { String($0.prefix(1)) } ?? "")).uppercased()
    }

    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                if let client = vm.selectedClient {
                    ZStack {
                        Circle()
                            .fill(theme.gradientPrimary)
                            .frame(width: 36, height: 36)
                        Text(initials)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.name)
                            .font(DS.body)
                            .foregroundColor(theme.textPrimary)
                        Text(client.phone)
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                    }
                } else {
                    Text("Выбрать клиента")
                        .font(DS.body)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textMuted.opacity(0.5))
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
                    Text(service.name)
                        .font(DS.body)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text("\(service.priceDefault)₽")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.accent)
                } else {
                    Text("Выбрать услугу")
                        .font(DS.body)
                        .foregroundColor(theme.textMuted)
                    Spacer()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textMuted.opacity(0.5))
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
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        Button(action: { onSelect(item) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(itemTitle(item))
                                        .font(DS.label)
                                        .foregroundColor(theme.textPrimary)
                                    Text(itemSubtitle(item))
                                        .font(DS.bodySmall)
                                        .foregroundColor(theme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .background(theme.backgroundCard)
                            .cornerRadius(DS.r12)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Отмена") { dismiss() }.foregroundColor(theme.accent)
            }
        }
    }
}

#Preview {
    NewAppointmentView()
        .environment(\.theme, .pink)
}