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
SectionLabel(text: "Клиент")
            SectionLabel(text: "Услуга")
            SectionLabel(text: "Дата")
            SectionLabel(text: "Время")
            SectionLabel(text: "Цена")
            SectionLabel(text: "Заметки")
            
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
            .onChange(of: searchText) { newValue in
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
            ForEach(viewModel.servicesForPicker) { service in
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