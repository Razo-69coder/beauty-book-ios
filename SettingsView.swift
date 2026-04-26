import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var masterName = ""
    @Published var email = ""
    @Published var workStart = 9
    @Published var workEnd = 20
    @Published var slotDuration = 60
    @Published var reminderDays = 30
    @Published var paymentCard = ""
    @Published var paymentPhone = ""
    @Published var paymentBanks = ""
    @Published var isSaving = false
    @Published var saveSuccess = false
    @Published var errorMessage: String? = nil

    @Published var loyaltyThreshold: Int {
        didSet { UserDefaults.standard.set(loyaltyThreshold, forKey: "loyalty_threshold") }
    }
    @Published var loyaltyDiscount: Int {
        didSet { UserDefaults.standard.set(loyaltyDiscount, forKey: "loyalty_discount") }
    }
    @Published var birthdayDiscountEnabled: Bool {
        didSet { UserDefaults.standard.set(birthdayDiscountEnabled, forKey: "birthday_discount_enabled") }
    }
    @Published var birthdayDiscount: Int {
        didSet { UserDefaults.standard.set(birthdayDiscount, forKey: "birthday_discount") }
    }

    private let api = APIClient.shared

    init() {
        loyaltyThreshold = UserDefaults.standard.integer(forKey: "loyalty_threshold") == 0 ? 10 : UserDefaults.standard.integer(forKey: "loyalty_threshold")
        loyaltyDiscount = UserDefaults.standard.integer(forKey: "loyalty_discount") == 0 ? 10 : UserDefaults.standard.integer(forKey: "loyalty_discount")
        birthdayDiscountEnabled = UserDefaults.standard.object(forKey: "birthday_discount_enabled") as? Bool ?? true
        birthdayDiscount = UserDefaults.standard.integer(forKey: "birthday_discount") == 0 ? 10 : UserDefaults.standard.integer(forKey: "birthday_discount")
    }

    var masterInitials: String {
        let parts = masterName.split(separator: " ")
        return ((parts.first.map { String($0.prefix(1)) } ?? "") + (parts.dropFirst().first.map { String($0.prefix(1)) } ?? "")).uppercased()
    }

    func load() async {
        if let m = try? await api.request(.me, as: MasterProfile.self) {
            masterName = m.name ?? ""
            email = m.email ?? ""
            workStart = m.workStart
            workEnd = m.workEnd
            slotDuration = m.slotDuration
            reminderDays = m.reminderDays
            paymentCard = m.paymentCard ?? ""
            paymentPhone = m.paymentPhone ?? ""
            paymentBanks = m.paymentBanks ?? ""
        } else {
            let m = MockData.master
            masterName = m.name ?? "Мастер"
            email = m.email ?? ""
            workStart = m.workStart
            workEnd = m.workEnd
            slotDuration = m.slotDuration
            reminderDays = m.reminderDays
            paymentCard = m.paymentCard ?? ""
            paymentPhone = m.paymentPhone ?? ""
            paymentBanks = m.paymentBanks ?? ""
        }
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        let req = MasterSettingsRequest(name: masterName, workStart: workStart, workEnd: workEnd,
                                 slotDuration: slotDuration, reminderDays: reminderDays, timezone: "Europe/Moscow")
        do {
            let _ = try await api.request(.updateSettings(req), as: MessageResponse.self)
            let payReq = PaymentRequest(paymentCard: paymentCard, paymentPhone: paymentPhone, paymentBanks: paymentBanks)
            let _ = try await api.request(.updatePayment(payReq), as: MessageResponse.self)
            saveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.saveSuccess = false }
        } catch let e as NetworkError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = "Ошибка сохранения"
        }
        isSaving = false
    }
}

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    var body: some View {
        Color.clear
            .overlay {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        profileHeader
                        themeSelector
                        profileSection
                        loyaltySection
                        scheduleSection
                        appSection
                        logoutButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .task { await vm.load() }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 80, height: 80)
                    .shadow(color: theme.accentGlow, radius: 20)
                Text(vm.masterInitials.isEmpty ? "?" : vm.masterInitials)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(vm.masterName.isEmpty ? "Мастер" : vm.masterName)
                .font(DS.titleSmall)
                .foregroundColor(theme.textPrimary)

            Text("+7 (999) 123-45-67")
                .font(DS.body)
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Theme Selector

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Тема приложения")

            HStack(spacing: 12) {
                ForEach(AppTheme.allCases, id: \.rawValue) { t in
                    Button(action: { themeManager.current = t }) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(t == .pink ?
                                    LinearGradient(colors: [Color(hex: "#FF2D78"), Color(hex: "#BF00FF")], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [Color(hex: "#C4B8C8"), Color(hex: "#E8B4C8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: themeManager.current == t ? 2 : 0)
                                )
                                .shadow(color: themeManager.current == t ? theme.accentGlow : .clear, radius: 8)

                            Text(t.displayName)
                                .font(DS.caption)
                                .foregroundColor(themeManager.current == t ? theme.textPrimary : theme.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.current == t ? theme.backgroundInput : Color.clear)
                    .cornerRadius(DS.r12)
                    .animation(DS.springSnappy, value: themeManager.current)
                }
            }
            .padding(8)
            .background(theme.backgroundCard)
            .cornerRadius(DS.r16)
            .overlay(
                RoundedRectangle(cornerRadius: DS.r16)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Профиль")

            BBGlassCard {
                VStack(spacing: 12) {
                    SettingsRow(icon: "person.fill", label: "Имя", value: vm.masterName, theme: theme)
                    Divider().background(theme.borderSubtle)
                    SettingsRow(icon: "envelope.fill", label: "Email", value: vm.email.isEmpty ? "Не указан" : vm.email, theme: theme)
                }
            }
        }
    }

    // MARK: - Loyalty Section

    private var loyaltySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Программа лояльности")

            BBGlassCard {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Скидка за лояльность")
                                .font(DS.body).foregroundColor(theme.textPrimary)
                            Text("Каждый N-й визит — скидка")
                                .font(DS.bodySmall).foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach([7, 10, 20], id: \.self) { n in
                                Text("\(n)")
                                    .font(DS.labelSmall)
                                    .foregroundColor(vm.loyaltyThreshold == n ? .white : theme.textSecondary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(vm.loyaltyThreshold == n ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                    .cornerRadius(DS.r8)
                                    .onTapGesture { vm.loyaltyThreshold = n }
                            }
                        }
                    }
                    .padding(16)

                    Divider().background(theme.borderSubtle).padding(.horizontal, 16)

                    HStack {
                        Text("Размер скидки")
                            .font(DS.body).foregroundColor(theme.textPrimary)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach([5, 10, 15], id: \.self) { pct in
                                Text("\(pct)%")
                                    .font(DS.labelSmall)
                                    .foregroundColor(vm.loyaltyDiscount == pct ? .white : theme.textSecondary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(vm.loyaltyDiscount == pct ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                    .cornerRadius(DS.r8)
                                    .onTapGesture { vm.loyaltyDiscount = pct }
                            }
                        }
                    }
                    .padding(16)

                    Divider().background(theme.borderSubtle).padding(.horizontal, 16)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Скидка в день рождения 🎂")
                                .font(DS.body).foregroundColor(theme.textPrimary)
                            Text("Клиент получит предложение скидки")
                                .font(DS.bodySmall).foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $vm.birthdayDiscountEnabled)
                            .tint(theme.accent)
                            .labelsHidden()
                    }
                    .padding(16)

                    if vm.birthdayDiscountEnabled {
                        Divider().background(theme.borderSubtle).padding(.horizontal, 16)
                        HStack {
                            Text("Скидка в ДР")
                                .font(DS.body).foregroundColor(theme.textPrimary)
                            Spacer()
                            HStack(spacing: 6) {
                                ForEach([5, 10, 15], id: \.self) { pct in
                                    Text("\(pct)%")
                                        .font(DS.labelSmall)
                                        .foregroundColor(vm.birthdayDiscount == pct ? .white : theme.textSecondary)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(vm.birthdayDiscount == pct ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                        .cornerRadius(DS.r8)
                                        .onTapGesture { vm.birthdayDiscount = pct }
                                }
                            }
                        }
                        .padding(16)
                        .animation(DS.springSnappy, value: vm.birthdayDiscountEnabled)
                    }
                }
            }
            .environment(\.theme, theme)
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Расписание")

            BBGlassCard {
                VStack(spacing: 16) {
                    StepperRow(
                        label: "Начало работы",
                        value: $vm.workStart,
                        range: 5...12,
                        display: "\(vm.workStart):00",
                        theme: theme
                    )
                    Divider().background(theme.borderSubtle)
                    StepperRow(
                        label: "Конец работы",
                        value: $vm.workEnd,
                        range: 14...23,
                        display: "\(vm.workEnd):00",
                        theme: theme
                    )
                    Divider().background(theme.borderSubtle)
                    StepperRow(
                        label: "Слот",
                        value: $vm.slotDuration,
                        range: 30...120,
                        step: 15,
                        display: "\(vm.slotDuration) мин",
                        theme: theme
                    )
                }
            }

            BBPrimaryButton(title: vm.isSaving ? "Сохранение..." : "Сохранить изменения", isLoading: vm.isSaving) {
                Task { await vm.save() }
            }
            .environment(\.theme, theme)
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Приложение")

            BBGlassCard {
                VStack(spacing: 0) {
                    SettingsRow(icon: "bell.fill", label: "Уведомления", value: "Включены", theme: theme)
                }
            }
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {
        BBSecondaryButton(title: "Войти из аккаунта", color: theme.statusRed) {
            appState.logout()
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String
    let theme: AppTheme

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 32)
            Text(label)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(value)
                .font(DS.body)
                .foregroundColor(theme.textMuted)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Stepper Row

struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let display: String
    let theme: AppTheme

    var body: some View {
        HStack {
            Text(label)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
            Spacer()
            HStack(spacing: 12) {
                Button(action: { if value - step >= range.lowerBound { value -= step } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(value <= range.lowerBound ? theme.textMuted : theme.accent)
                }
                Text(display)
                    .font(DS.label)
                    .foregroundColor(theme.textPrimary)
                    .frame(minWidth: 60, alignment: .center)
                Button(action: { if value + step <= range.upperBound { value += step } }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(value >= range.upperBound ? theme.textMuted : theme.accent)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .environment(\.theme, .pink)
}