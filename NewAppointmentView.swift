import SwiftUI

struct NewAppointmentView: View {
    @StateObject private var viewModel = NewAppointmentViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var viewOpacity: Double = 0
    @State private var showClientPicker = false
    @State private var showServicePicker = false
    @State private var showTimePicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    clientSection
                    
                    serviceSection
                    
                    dateSection
                    
                    timeSection
                    
                    priceSection
                    
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(Color(hex: "#080810"))
            .navigationTitle("Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#5A5A7A"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        Task { await viewModel.createAppointment() }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(viewModel.canSave ? Color(hex: "#FF2D78") : Color(hex: "#5A5A7A"))
                    .disabled(!viewModel.canSave)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewOpacity = 1.0
                }
            }
            .opacity(viewOpacity)
        }
    }
    
    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Клиент")
            
            Button {
                showClientPicker = true
            } label: {
                HStack {
                    if let client = viewModel.selectedClient {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#FF2D78").opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(client.name.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "#FF2D78"))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                Text(client.phone)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#5A5A7A"))
                            }
                        }
                    } else {
                        Text("Выбрать клиента")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#5A5A7A"))
                    }
                    
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#5A5A7A"))
                }
                .padding(16)
            }
        }
    }
    
    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Услуга")
            
            Button {
                showServicePicker = true
            } label: {
                HStack {
                    if let service = viewModel.selectedService {
                        Text(service)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    } else {
                        Text("Выбрать услугу")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#5A5A7A"))
                    }
                    
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#5A5A7A"))
                }
                .padding(16)
            }
        }
    }
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Дата")
            
            DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Color(hex: "#FF2D78"))
                .colorScheme(.dark)
        }
    }
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Время")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableTimes, id: \.self) { time in
                        TimeChip(
                            time: time,
                            isSelected: viewModel.selectedTime == time
                        ) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                viewModel.selectedTime = time
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Цена")
            
            HStack(spacing: 12) {
                TextField("0", text: $viewModel.priceText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("₽")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "#FF2D78"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Заметки")
            
            TextEditor(text: $viewModel.notes)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color(hex: "#1A1A2E"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

struct SectionLabel: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(hex: "#5A5A7A"))
            .textCase(.uppercase)
    }
}

struct TimeChip: View {
    let time: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(time)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "#A0A0C0"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color(hex: "#FF2D78") : Color(hex: "#1A1A2E"))
                )
        }
    }
}

struct ClientPickerView: View {
    @ObservedObject var viewModel: NewAppointmentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.clientsForPicker) { client in
                    Button {
                        viewModel.selectedClient = client
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(client.name)
                                    .foregroundColor(.white)
                                Text(client.phone)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#5A5A7A"))
                            }
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(hex: "#080810"))
            .navigationTitle("Выбрать клиента")
            .searchable(text: $searchText, prompt: "Поиск")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchClients(query: newValue)
            }
        }
    }
}

struct ServicePickerView: View {
    @ObservedObject var viewModel: NewAppointmentViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(viewModel.servicesForPicker, id: \.self) { service in
                Button {
                    viewModel.selectedService = service.name
                    viewModel.priceText = "\(service.priceDefault)"
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(service.name)
                                .foregroundColor(.white)
                            Text("\(service.priceDefault)₽")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#5A5A7A"))
                        }
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color(hex: "#080810"))
        .navigationTitle("Выбрать услугу")
    }
}

@MainActor
final class NewAppointmentViewModel: ObservableObject {
    @Published var selectedClient: Client? = nil
    @Published var selectedService: String? = nil
    @Published var date: Date = Date()
    @Published var selectedTime: String? = nil
    @Published var priceText: String = ""
    @Published var notes: String = ""
    @Published var clientsForPicker: [Client] = []
    @Published var servicesForPicker: [Service] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let api = APIClient.shared
    
    private let availableTimes: [String] = [
        "09:00", "09:30", "10:00", "10:30", "11:00", "11:30",
        "12:00", "12:30", "13:00", "13:30", "14:00", "14:30",
        "15:00", "15:30", "16:00", "16:30", "17:00", "17:30",
        "18:00", "18:30", "19:00", "19:30", "20:00"
    ]
    
    var canSave: Bool {
        selectedClient != nil && selectedService != nil && selectedTime != nil && !priceText.isEmpty
    }
    
    init() {
        Task { await loadClients() }
        Task { await loadServices() }
    }
    
    func searchClients(query: String) {
        Task { await loadClients(search: query) }
    }
    
    func loadClients(search: String = "") async {
        do {
            let response = try await api.getClients(page: 0, search: search)
            clientsForPicker = response.clients
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadServices() async {
        do {
            let response = try await api.request(.services, type: ServicesResponse.self)
            servicesForPicker = response.services
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createAppointment() async {
        guard let client = selectedClient,
              let service = selectedService,
              let time = selectedTime,
              let price = Int(priceText.filter(\.isNumber)) else { return }
        
        isLoading = true
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let request = AppointmentCreateRequest(
            clientId: client.id,
            procedure: service,
            appointmentDate: dateString,
            time: time,
            price: price,
            notes: notes
        )
        
        do {
            let _ = try await api.request(.createAppointment(request), type: SuccessResponse.self)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    NewAppointmentView()
        .preferredColorScheme(.dark)
}