import SwiftUI

@MainActor
final class EditAppointmentViewModel: ObservableObject {
    @Published var procedure: String = ""
    @Published var selectedServices: [Service] = []
    @Published var selectedDate: Date = Date()
    @Published var selectedTime: String = ""
    @Published var price: String = ""
    @Published var status: AppointmentStatus = .confirmed
    @Published var availableSlots: [String] = []
    @Published var services: [Service] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String? = nil

    let appointmentId: Int
    let initialAppointment: Appointment

    var onUpdated: (() -> Void)?

    var isValid: Bool {
        !procedure.isEmpty && !selectedTime.isEmpty && !price.isEmpty
    }

    var durationOptions: [Int] { [30, 45, 60, 90, 120, 180] }
    @Published var duration: Int = 60

    func durationLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)ч \(m)м" : "\(h)ч"
        }
        return "\(minutes)м"
    }

    private let api = APIClient.shared

    init(appointment: Appointment) {
        self.appointmentId = appointment.id
        self.initialAppointment = appointment
        self.procedure = appointment.procedure
        self.selectedTime = appointment.time
        self.price = "\(appointment.price)"
        self.status = appointment.status
        self.duration = appointment.duration ?? 60

        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        if let date = f.date(from: appointment.appointmentDate) {
            self.selectedDate = date
        }
    }

    func loadServices() async {
        isLoading = true
        if let resp = try? await api.request(.services, as: ServicesResponse.self) {
            services = resp.services
        }
        await loadSlots()
        isLoading = false
    }

    func loadSlots() async {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: selectedDate)
        let isOriginalDate = dateStr == initialAppointment.appointmentDate
        if let resp = try? await api.request(.slots(date: dateStr), as: SlotsResponse.self) {
            var slots = resp.slots
            // Текущее время этой записи всегда доступно на исходной дате
            if isOriginalDate && !slots.contains(initialAppointment.time) {
                slots.append(initialAppointment.time)
                slots.sort()
            }
            availableSlots = slots
        } else {
            availableSlots = stride(from: 9 * 60, to: 20 * 60, by: 60).map { m in
                String(format: "%02d:%02d", m / 60, m % 60)
            }
        }
        if !availableSlots.contains(selectedTime) { selectedTime = availableSlots.first ?? "" }
    }

    func save() async {
        guard !procedure.isEmpty, !selectedTime.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        let totalPrice = selectedServices.isEmpty
            ? (Int(price) ?? initialAppointment.price)
            : selectedServices.reduce(0) { $0 + $1.priceDefault }
        let procedureStr = selectedServices.isEmpty
            ? procedure
            : selectedServices.map(\.name).joined(separator: " + ")
        let firstServiceId = selectedServices.first?.id ?? 0

        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let req = AppointmentUpdateRequest(
            procedure: procedureStr,
            appointmentDate: f.string(from: selectedDate),
            time: selectedTime,
            price: Int(price) ?? totalPrice,
            serviceId: firstServiceId,
            status: status.rawValue
        )

        do {
            let _ = try await api.request(.updateAppointment(id: appointmentId, req), as: MessageResponse.self)
            HapticManager.success()
            onUpdated?()
        } catch let e as NetworkError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = "Ошибка при сохранении"
        }
        isSaving = false
    }
}

struct EditAppointmentView: View {
    @StateObject private var vm: EditAppointmentViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false

    var onUpdated: (() -> Void)? = nil

    init(appointment: Appointment, onUpdated: (() -> Void)? = nil) {
        _vm = StateObject(wrappedValue: EditAppointmentViewModel(appointment: appointment))
        self.onUpdated = onUpdated
    }

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
            vm.onUpdated = { dismiss(); self.onUpdated?() }
            await vm.loadServices()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(theme.textMuted.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)

            HStack {
                Button("Отмена") { dismiss() }
                    .font(DS.body)
                    .foregroundColor(theme.textMuted)
                Spacer()
                Text("Редактировать запись")
                    .font(DS.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button("Сохранить") { Task { await vm.save() } }
                    .font(DS.label)
                    .foregroundColor(theme.accent)
                    .disabled(!vm.isValid || vm.isSaving)
                    .opacity(vm.isValid && !vm.isSaving ? 1 : 0.4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider().background(theme.borderSubtle)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    sectionView(index: 0, title: "Услуги") {
                        ServiceEditRow(vm: vm, theme: theme)
                    }

                    sectionView(index: 1, title: "Дата и время") {
                        VStack(spacing: 16) {
                            DatePicker("", selection: $vm.selectedDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .accentColor(theme.accent)
                                .colorScheme(theme == .platinum ? .light : .dark)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                .background(theme.backgroundInput)
                                .cornerRadius(12)
                                .onChange(of: vm.selectedDate) { _, _ in
                                    HapticManager.selection()
                                    Task { await vm.loadSlots() }
                                }

                            if !vm.availableSlots.isEmpty {
                                SlotPicker(slots: vm.availableSlots, selected: $vm.selectedTime, theme: theme)
                            }
                        }
                    }

                    sectionView(index: 2, title: "Детали") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Название процедуры")
                                    .font(DS.body)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                            }
                            TextField("", text: $vm.procedure)
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                                .padding(12)
                                .background(theme.backgroundInput)
                                .cornerRadius(DS.r8)

                            BBTextField(placeholder: "Цена (₽)", text: $vm.price, keyboardType: .numberPad)

                            HStack {
                                Text("Длительность")
                                    .font(DS.body)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Menu {
                                    ForEach(vm.durationOptions, id: \.self) { mins in
                                        Button(vm.durationLabel(mins)) {
                                            vm.duration = mins
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(vm.durationLabel(vm.duration))
                                            .font(DS.body)
                                            .foregroundColor(theme.accent)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.textMuted)
                                    }
                                }
                            }

                            HStack {
                                Text("Статус")
                                    .font(DS.body)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Menu {
                                    ForEach(AppointmentStatus.allCases, id: \.self) { s in
                                        Button(s.displayName) { vm.status = s }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color(hex: vm.status.hexColor)).frame(width: 8, height: 8)
                                        Text(vm.status.displayName)
                                            .font(DS.body)
                                            .foregroundColor(theme.accent)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(theme.textMuted)
                                    }
                                }
                            }
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

            BBPrimaryButton(
                title: vm.isSaving ? "Сохраняю..." : "Сохранить изменения",
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

    private func sectionView<C: View>(index: Int, title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BBSectionHeader(title: title)
            BBGlassCard { content() }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08), value: appeared)
        }
        .environment(\.theme, theme)
    }
}

struct ServiceEditRow: View {
    @ObservedObject var vm: EditAppointmentViewModel
    let theme: AppTheme
    @State private var showPicker = false
    @State private var draftIds: Set<Int> = []

    private var summary: String {
        if vm.selectedServices.isEmpty { return vm.procedure }
        return vm.selectedServices.map(\.name).joined(separator: ", ")
    }

    var body: some View {
        Button(action: {
            draftIds = Set(vm.selectedServices.map(\.id))
            showPicker = true
        }) {
            HStack {
                Text(summary)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textMuted.opacity(0.5))
            }
        }
        .sheet(isPresented: $showPicker) {
            ServiceMultiPicker(
                services: vm.services,
                selectedIds: $draftIds,
                theme: theme
            ) { selected in
                vm.selectedServices = selected
                vm.price = selected.isEmpty ? vm.price : "\(selected.reduce(0) { $0 + $1.priceDefault })"
                vm.duration = selected.first?.durationMin ?? vm.duration
                if !selected.isEmpty {
                    vm.procedure = selected.map(\.name).joined(separator: " + ")
                }
                showPicker = false
            }
            .environment(\.theme, theme)
        }
    }
}

struct ServiceMultiPicker: View {
    let services: [Service]
    @Binding var selectedIds: Set<Int>
    let theme: AppTheme
    let onDone: ([Service]) -> Void

    var body: some View {
        NavigationView {
            List(services) { service in
                Button {
                    if selectedIds.contains(service.id) {
                        selectedIds.remove(service.id)
                    } else {
                        selectedIds.insert(service.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.name)
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                            Text("\(service.priceDefault)₽ · \(service.durationMin) мин")
                                .font(DS.caption)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        if selectedIds.contains(service.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.accent)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Выберите услуги")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        let selected = services.filter { selectedIds.contains($0.id) }
                        onDone(selected)
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
    }
}
