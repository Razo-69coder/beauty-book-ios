import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var settingsOpacity: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileSection
                
                workScheduleSection
                
                paymentSection
                
                themeSection
                
                dangerSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(hex: "#080810"))
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Сохранить") {
                    Task { await viewModel.saveSettings() }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(viewModel.isDirty ? Color(hex: "#FF2D78") : Color(hex: "#5A5A7A"))
                .disabled(!viewModel.isDirty)
            }
        }
        .onAppear {
            Task { await viewModel.loadSettings() }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                settingsOpacity = 1.0
            }
        }
        .opacity(settingsOpacity)
    }
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Профиль")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#5A5A7A"))
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                SettingsRow(icon: "person.fill", title: "Имя") {
                    TextField("Ваше имя", text: $viewModel.name)
                        .foregroundColor(.white)
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                SettingsRow(icon: "calendar", title: "Часовой пояс") {
                    Text(viewModel.timezone)
                        .foregroundColor(Color(hex: "#5A5A7A"))
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
    
    private var workScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Расписание")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#5A5A7A"))
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Начало работы")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $viewModel.workStart) {
                        ForEach(6..<22, id: \.self) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    .labelsHidden()
                    .tint(Color(hex: "#FF2D78"))
                }
                .padding(.vertical, 12)
                
                Divider().background(Color.white.opacity(0.08))
                
                HStack {
                    Text("Конец работы")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $viewModel.workEnd) {
                        ForEach(8..<23, id: \.self) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    .labelsHidden()
                    .tint(Color(hex: "#FF2D78"))
                }
                .padding(.vertical, 12)
                
                Divider().background(Color.white.opacity(0.08))
                
                HStack {
                    Text("Длительность слОта")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $viewModel.slotDuration) {
                        ForEach([30, 45, 60, 90, 120], id: \.self) { min in
                            Text("\(min) мин").tag(min)
                        }
                    }
                    .labelsHidden()
                    .tint(Color(hex: "#FF2D78"))
                }
                .padding(.vertical, 12)
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
    
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Реквизиты")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#5A5A7A"))
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                SettingsRow(icon: "creditcard.fill", title: "Карта") {
                    TextField("**** **** **** ****", text: $viewModel.paymentCard)
                        .foregroundColor(.white)
                        .keyboardType(.numberPad)
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                SettingsRow(icon: "phone.fill", title: "Телефон") {
                    TextField("+7 (999) 000-00-00", text: $viewModel.paymentPhone)
                        .foregroundColor(.white)
                        .keyboardType(.phonePad)
                }
                
                Divider().background(Color.white.opacity(0.08))
                
                SettingsRow(icon: "building.columns.fill", title: "Банки") {
                    TextField("Сбер, Тинькофф, Альфа", text: $viewModel.paymentBanks)
                        .foregroundColor(.white)
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
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Оформление")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#5A5A7A"))
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Тема")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $viewModel.theme) {
                        Text("Bratz Pink").tag("bratz")
                        Text("Платина").tag("platinum")
                    }
                    .labelsHidden()
                    .tint(Color(hex: "#FF2D78"))
                }
                .padding(.vertical, 12)
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
    
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Опасная зона")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#FF4757"))
                .textCase(.uppercase)
            
            Button {
                viewModel.showLogoutConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#FF4757"))
                    
                    Text("Выйти из аккаунта")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#FF4757"))
                    
                    Spacer()
                }
                .padding(16)
            }
            .background(Color(hex: "#11111E"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#FF4757").opacity(0.3), lineWidth: 1)
            )
        }
        .confirmationDialog("Выйти?", isPresented: $viewModel.showLogoutConfirmation) {
            Button("Выйти", role: .destructive) {
                viewModel.logout()
            }
        }
    }
}

struct SettingsRow<Content: View>: View {
    let icon: String
    let title: String
    let content: Content
    
    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#FF2D78"))
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.white)
            
            Spacer()
            
            content
                .frame(maxWidth: 150)
        }
        .padding(.vertical, 12)
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var timezone: String = "Europe/Moscow"
    @Published var workStart: Int = 9
    @Published var workEnd: Int = 20
    @Published var slotDuration: Int = 60
    @Published var paymentCard: String = ""
    @Published var paymentPhone: String = ""
    @Published var paymentBanks: String = ""
    @Published var theme: String = "bratz"
    @Published var isLoading: Bool = false
    @Published var isDirty: Bool = false
    @Published var showLogoutConfirmation: Bool = false
    @Published var errorMessage: String? = nil
    
    private let api = APIClient.shared
    private var originalSettings: String = ""
    
    func loadSettings() async {
        isLoading = true
        
        do {
            let profile = try await api.getMe()
            name = profile.name ?? ""
            timezone = profile.timezone
            workStart = profile.workStart
            workEnd = profile.workEnd
            slotDuration = profile.slotDuration
            paymentCard = profile.paymentCard ?? ""
            paymentPhone = profile.paymentPhone ?? ""
            paymentBanks = profile.paymentBanks ?? ""
            theme = profile.theme
            
            originalSettings = settingsHash()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func saveSettings() async {
        let request = MasterSettingsRequest(
            name: name,
            workStart: workStart,
            workEnd: workEnd,
            slotDuration: slotDuration,
            reminderDays: 1,
            timezone: timezone
        )
        
        do {
            let _ = try await api.request(.updateSettings(request), type: MasterProfile.self)
            isDirty = false
            originalSettings = settingsHash()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        if !paymentCard.isEmpty || !paymentPhone.isEmpty {
            let paymentRequest = PaymentRequest(
                paymentCard: paymentCard,
                paymentPhone: paymentPhone,
                paymentBanks: paymentBanks
            )
            do {
                let _ = try await api.request(.updatePayment(paymentRequest), type: MasterProfile.self)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func logout() {
        KeychainManager.shared.deleteToken()
    }
    
    private func settingsHash() -> String {
        "\(name)-\(workStart)-\(workEnd)-\(slotDuration)-\(paymentCard)-\(paymentPhone)-\(theme)"
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
    .preferredColorScheme(.dark)
}