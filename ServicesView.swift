import SwiftUI

struct ServicesView: View {
    @StateObject private var viewModel = ServicesViewModel()
    @State private var searchText: String = ""
    @State private var listOpacity: Double = 0
    @State private var showAddSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            searchBar
            
            servicesList
            
            addButton
        }
        .background(Color(hex: "#080810"))
        .sheet(isPresented: $showAddSheet) {
            AddServiceSheet(viewModel: viewModel)
        }
        .onAppear {
            Task { await viewModel.loadServices() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                listOpacity = 1.0
            }
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.searchQuery = newValue
            Task { await viewModel.loadServices() }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Услуги")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\(viewModel.total) услуг")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#A0A0C0"))
            }
            Spacer()
            
            Button {
                Task { await viewModel.loadServices() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#FF2D78"))
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#5A5A7A"))
            
            TextField("Поиск услуг", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#1A1A2E"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    private var servicesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FF2D78")))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.services.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.services) { service in
                        ServiceCard(service: service) {
                            Task { await viewModel.deleteService(service) }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .opacity(listOpacity)
    }
    
    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Добавить услугу")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FF2D78"), Color(hex: "#FF006E")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color(hex: "#FF2D78").opacity(0.4), radius: 20, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 120)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "scissors")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#5A5A7A"))
            
            Text("Нет услуг")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Добавьте свои услуги")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#5A5A7A"))
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}

struct ServiceCard: View {
    let service: Service
    let onDelete: () -> Void
    @State private var isPressed: Bool = false
    @State private var showDeleteConfirm: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FF2D78").opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "scissors")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#FF2D78"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("от \(service.priceDefault)₽")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#A0A0C0"))
            }
            
            Spacer()
            
            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#FF4757").opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#11111E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .confirmationDialog("Удалить услугу?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct AddServiceSheet: View {
    @ObservedObject var viewModel: ServicesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var price: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Название услуги")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#A0A0C0"))
                    
                    TextField("Например: Маникюр", text: $name)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color(hex: "#1A1A2E"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Цена по умолчанию")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#A0A0C0"))
                    
                    HStack {
                        TextField("0", text: $price)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .keyboardType(.numberPad)
                        
                        Text("₽")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#A0A0C0"))
                    }
                    .padding(16)
                    .background(Color(hex: "#1A1A2E"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                
                Spacer()
                
                Button {
                    Task {
                        if let priceInt = Int(price) {
                            await viewModel.addService(name: name, price: priceInt)
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Добавить")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#FF2D78"), Color(hex: "#FF006E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
                .disabled(name.isEmpty || price.isEmpty)
                .opacity(name.isEmpty || price.isEmpty ? 0.5 : 1)
            }
            .padding(20)
            .background(Color(hex: "#080810"))
            .navigationTitle("Новая услуг��")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF2D78"))
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
    
    private let mockServices: [Service] = [
        Service(id: 1, name: "Маникюр", priceDefault: 1500),
        Service(id: 2, name: "Покрытие гель-лак", priceDefault: 1200),
        Service(id: 3, name: "Снятие покрытия", priceDefault: 500),
        Service(id: 4, name: "Ремонт ногтя", priceDefault: 300),
        Service(id: 5, name: "Дизайн ногтей", priceDefault: 800),
    ]
    
    private let api = APIClient.shared
    
    func loadServices() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await api.request(.services, type: ServicesResponse.self)
            services = response.services
            total = response.services.count
        } catch {
            services = mockServices
            total = services.count
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addService(name: String, price: Int) async {
        let request = ServiceCreateRequest(name: name, priceDefault: price)
        do {
            let newService = try await api.request(.createService(request), type: Service.self)
            services.insert(newService, at: 0)
            total += 1
        } catch {
            let tempService = Service(id: Int.random(in: 1000...9999), name: name, priceDefault: price)
            services.insert(tempService, at: 0)
            total += 1
        }
    }
    
    func deleteService(_ service: Service) async {
        do {
            let _ = try await api.request(.deleteService(id: service.id), type: SuccessResponse.self)
            services.removeAll { $0.id == service.id }
            total -= 1
        } catch {
            services.removeAll { $0.id == service.id }
            total -= 1
        }
    }
}

#Preview {
    NavigationView {
        ServicesView()
    }
    .preferredColorScheme(.dark)
}