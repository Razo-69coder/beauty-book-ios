import SwiftUI

struct ClientsListView: View {
    @StateObject private var viewModel = ClientsViewModel()
    @State private var searchText: String = ""
    @State private var listOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            searchBar
            
            clientsList
        }
        .background(Color(hex: "#080810"))
        .onAppear {
            Task { await viewModel.loadClients() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                listOpacity = 1.0
            }
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.searchQuery = newValue
            Task { await viewModel.loadClients() }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Клиенты")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\(viewModel.total) клиентов")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#A0A0C0"))
            }
            Spacer()
            
            Button {
                Task { await viewModel.loadClients() }
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
            
            TextField("Поиск по имени или телефону", text: $searchText)
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
    
    private var clientsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FF2D78")))
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.clients.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.clients) { client in
                        NavigationLink(destination: ClientDetailView(client: client)) {
                            ClientCard(client: client)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if viewModel.hasMore {
                        Button("Загрузить ещё") {
                            Task { await viewModel.loadMore() }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#FF2D78"))
                        .padding(.vertical, 16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .opacity(listOpacity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#5A5A7A"))
            
            Text("Нет клиентов")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Клиенты появятся после записей")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#5A5A7A"))
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
}

struct ClientCard: View {
    let client: Client
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FF2D78").opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Text(client.name.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#FF2D78"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(client.phone)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#A0A0C0"))
                    
                    if let lastVisit = client.lastVisit {
                        Text("•")
                            .foregroundColor(Color(hex: "#5A5A7A"))
                        Text(lastVisit)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#5A5A7A"))
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#5A5A7A"))
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
    }
}

struct ClientDetailView: View {
    let client: Client
    @StateObject private var viewModel: ClientDetailViewModel
    @State private var detailOpacity: Double = 0
    
    init(client: Client) {
        self.client = client
        self._viewModel = StateObject(wrappedValue: ClientDetailViewModel(client: client))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                clientHeader
                
                contactSection
                
                historySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(hex: "#080810"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.showActions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(Color(hex: "#FF2D78"))
                }
            }
        }
        .confirmationDialog("Действия", isPresented: $viewModel.showActions) {
            Button("Записать на процедуру") {
                // Переход к созданию записи
            }
            Button("Написать в Telegram") {
                // Открытие Telegram
            }
            Button("Удалить клиента", role: .destructive) {
                Task { await viewModel.deleteClient() }
            }
        }
        .onAppear {
            Task { await viewModel.loadHistory() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                detailOpacity = 1.0
            }
        }
        .opacity(detailOpacity)
    }
    
    private var clientHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF2D78"), Color(hex: "#FF006E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text(client.name.prefix(1).uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(client.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Контакты")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#5A5A7A"))
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#FF2D78"))
                        .frame(width: 24)
                    
                    Text(client.phone)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        // Копировать
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#5A5A7A"))
                    }
                }
                .padding(.vertical, 12)
                
                if let username = client.username {
                    Divider()
                        .background(Color.white.opacity(0.08))
                    
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#FF2D78"))
                            .frame(width: 24)
                        
                        Text("@\(username)")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .background(Color(hex: "#11111E"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#5A5A7A"))
                .textCase(.uppercase)
            
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FF2D78")))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if viewModel.history.isEmpty {
                Text("Нет записей")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#5A5A7A"))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(viewModel.history) { item in
                    HistoryRow(item: item)
                }
            }
        }
    }
}

struct HistoryRow: View {
    let item: AppointmentHistory
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.procedure)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Text(item.appointmentDate)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#5A5A7A"))
            }
            
            Spacer()
            
            Text("\(item.price)₽")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#FF2D78"))
        }
        .padding(16)
        .background(Color(hex: "#11111E"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var total: Int = 0
    @Published var currentPage: Int = 0
    @Published var hasMore: Bool = false
    
    private let api = APIClient.shared
    
    func loadClients() async {
        isLoading = true
        errorMessage = nil
        currentPage = 0
        
        do {
            let response = try await api.getClients(page: 0, search: searchQuery)
            clients = response.clients
            total = response.total
            hasMore = clients.count < response.total
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadMore() async {
        guard hasMore && !isLoading else { return }
        
        let nextPage = currentPage + 1
        do {
            let response = try await api.getClients(page: nextPage, search: searchQuery)
            clients.append(contentsOf: response.clients)
            currentPage = nextPage
            hasMore = clients.count < response.total
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ClientDetailViewModel: ObservableObject {
    let client: Client
    @Published var history: [AppointmentHistory] = []
    @Published var isLoading: Bool = false
    @Published var showActions: Bool = false
    @Published var errorMessage: String? = nil
    
    private let api = APIClient.shared
    
    init(client: Client) {
        self.client = client
    }
    
    func loadHistory() async {
        isLoading = true
        
        do {
            let detail = try await api.request(.clientDetail(id: client.id), type: ClientDetail.self)
            history = detail.history
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteClient() async {
        do {
            let _ = try await api.request(.deleteClient(id: client.id), type: SuccessResponse.self)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SuccessResponse: Decodable {
    let success: Bool
}

#Preview {
    NavigationView {
        ClientsListView()
    }
    .preferredColorScheme(.dark)
}