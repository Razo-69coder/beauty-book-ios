import SwiftUI
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var masterName = ""
    @Published var email = ""
    @Published var phone = ""
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

    @Published var bookingLinkSlug = ""
    @Published var bookingLinkInput = ""
    @Published var bookingLinkSaving = false
    @Published var bookingLinkSuccess = false
    @Published var bookingLinkError: String? = nil

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

    @Published var loyaltyDiscountType: String {
        didSet { UserDefaults.standard.set(loyaltyDiscountType, forKey: "loyalty_discount_type") }
    }
    @Published var loyaltyDiscountRub: Int {
        didSet { UserDefaults.standard.set(loyaltyDiscountRub, forKey: "loyalty_discount_rub") }
    }

    @Published var remindersEnabled: Bool {
        didSet { UserDefaults.standard.set(remindersEnabled, forKey: "reminders_enabled") }
    }
    @Published var paymentReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(paymentReminderEnabled, forKey: "payment_reminder_enabled") }
    }
    @Published var returnReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(returnReminderEnabled, forKey: "return_reminder_enabled") }
    }
    @Published var isTelegramConnected = false
    @Published var timezoneOffset = 3

    @Published var returnReminderDays: Int {
        didSet { UserDefaults.standard.set(returnReminderDays, forKey: "return_reminder_days") }
    }

    func slotDurationLabel(_ mins: Int) -> String {
        if mins < 60 {
            return "\(mins) мин"
        } else if mins == 60 {
            return "1 час"
        } else if mins == 90 {
            return "1.5 часа"
        } else {
            return "2 часа"
        }
    }

    private let api = APIClient.shared

    init() {
        loyaltyThreshold = UserDefaults.standard.integer(forKey: "loyalty_threshold") == 0 ? 10 : UserDefaults.standard.integer(forKey: "loyalty_threshold")
        loyaltyDiscount = UserDefaults.standard.integer(forKey: "loyalty_discount") == 0 ? 10 : UserDefaults.standard.integer(forKey: "loyalty_discount")
        birthdayDiscountEnabled = UserDefaults.standard.object(forKey: "birthday_discount_enabled") as? Bool ?? true
        birthdayDiscount = UserDefaults.standard.integer(forKey: "birthday_discount") == 0 ? 10 : UserDefaults.standard.integer(forKey: "birthday_discount")

        loyaltyDiscountType = UserDefaults.standard.string(forKey: "loyalty_discount_type") ?? "percent"
        loyaltyDiscountRub = UserDefaults.standard.integer(forKey: "loyalty_discount_rub") == 0 ? 300 : UserDefaults.standard.integer(forKey: "loyalty_discount_rub")

        remindersEnabled = UserDefaults.standard.object(forKey: "reminders_enabled") as? Bool ?? true
        paymentReminderEnabled = UserDefaults.standard.object(forKey: "payment_reminder_enabled") as? Bool ?? true
        returnReminderEnabled = UserDefaults.standard.object(forKey: "return_reminder_enabled") as? Bool ?? true
        returnReminderDays = UserDefaults.standard.integer(forKey: "return_reminder_days") == 0 ? 21 : UserDefaults.standard.integer(forKey: "return_reminder_days")
    }

    var masterInitials: String {
        let parts = masterName.split(separator: " ")
        var result = ""
        if let first = parts.first {
            result = String(first.prefix(1))
        }
        if parts.count > 1, let second = parts.dropFirst().first {
            result += String(second.prefix(1))
        }
        return result.isEmpty ? "?" : result.uppercased()
    }

    var bookingLink: String {
        let slug = bookingLinkSlug.isEmpty ? "" : bookingLinkSlug
        return slug.isEmpty ? "" : "https://beauty-bot-44ou.onrender.com/book/\(slug)"
    }

    var manageLink: String {
        let slug = bookingLinkSlug.isEmpty ? "" : bookingLinkSlug
        return slug.isEmpty ? "" : "https://solvobeauty.vercel.app/my/\(slug)"
    }

    func load() async {
        if let m = try? await api.request(.me, as: MasterProfile.self) {
            masterName = m.name ?? ""
            email = m.email ?? ""
            phone = m.phone ?? ""
            workStart = m.workStart
            workEnd = m.workEnd
            slotDuration = m.slotDuration
            reminderDays = m.reminderDays
            paymentCard = m.paymentCard ?? ""
            paymentPhone = m.paymentPhone ?? ""
            paymentBanks = m.paymentBanks ?? ""
            isTelegramConnected = (m.telegramId ?? 0) > 0
            if let t = m.loyaltyThreshold, t > 0 { loyaltyThreshold = t }
            if let d = m.loyaltyDiscountPercent, d > 0 { loyaltyDiscount = d }
            if let e = m.birthdayDiscountEnabled { birthdayDiscountEnabled = e }
            if let d = m.birthdayDiscountPercent, d > 0 { birthdayDiscount = d }
            if let t = m.loyaltyDiscountType { loyaltyDiscountType = t }
            if let r = m.loyaltyDiscountRub, r > 0 { loyaltyDiscountRub = r }
            timezoneOffset = m.timezoneOffset ?? 3
        } else {
            masterName = ""
            email = ""
            phone = ""
            workStart = 10
            workEnd = 20
            slotDuration = 60
            reminderDays = 40
            paymentCard = ""
            paymentPhone = ""
            paymentBanks = ""
        }
        if let r = try? await api.request(.getBookingLink, as: BookingLinkResponse.self) {
            bookingLinkSlug = r.bookingLink
            bookingLinkInput = r.bookingLink
        }
    }

    func saveBookingLink() async {
        let slug = bookingLinkInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !slug.isEmpty else { return }
        bookingLinkSaving = true
        bookingLinkError = nil
        do {
            let r = try await api.request(.updateBookingLink(slug), as: BookingLinkResponse.self)
            bookingLinkSlug = r.bookingLink
            bookingLinkInput = r.bookingLink
            bookingLinkSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.bookingLinkSuccess = false }
        } catch NetworkError.serverError(_, let msg) {
            bookingLinkError = msg
        } catch {
            bookingLinkError = "Ошибка сохранения"
        }
        bookingLinkSaving = false
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

    func saveLoyaltySettings() async {
        let req = LoyaltySettingsRequest(
            loyaltyEnabled: true,
            loyaltyThreshold: loyaltyThreshold,
            loyaltyDiscountPercent: loyaltyDiscount,
            birthdayEnabled: birthdayDiscountEnabled,
            birthdayDiscountPercent: birthdayDiscount,
            loyaltyDiscountType: loyaltyDiscountType,
            loyaltyDiscountRub: loyaltyDiscountRub
        )
        do {
            let _ = try await api.request(.updateLoyaltySettings(req), as: MessageResponse.self)
            await MainActor.run { self.saveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.saveSuccess = false }
        } catch {
            await MainActor.run { self.errorMessage = "Ошибка сохранения лояльности" }
        }
    }

    func saveProfile() async {
        isSaving = true
        errorMessage = nil
        do {
            let req = ProfileUpdateRequest(name: masterName, email: email, phone: phone)
            let _ = try await api.request(.updateProfile(req), as: MessageResponse.self)
            saveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.saveSuccess = false }
        } catch let e as NetworkError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = "Ошибка сохранения"
        }
        isSaving = false
    }

    func connectTelegram() async {
        do {
            let (token, botUsername) = try await APIClient.shared.telegramLinkToken()
            let domain = botUsername.isEmpty ? "Beauty6699_bot" : botUsername
            let deepLink = "https://t.me/\(domain)?start=master_\(token)"
            await MainActor.run {
                if let url = URL(string: deepLink) {
                    UIApplication.shared.open(url)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Не удалось создать ссылку"
            }
        }
    }

}

struct ProfileFieldRow: View {
    let icon: String
    let label: String
    @Binding var text: String
    let theme: AppTheme
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textMuted)
                TextField(label, text: $text)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
        }
        .padding(.vertical, 8)
    }
}

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
        @State private var showLogoutAlert = false
        @State private var showDeleteAccountAlert = false
        @State private var showBlockedDays = false
        @State private var showOnboarding = false
        @State private var showReminderTemplates = false
        @State private var copiedManageLink = false
        @State private var pushTestSent = false
        @State private var pushTestLoading = false
        func saveTimezone() async {
            guard let token = KeychainManager.shared.getToken(),
                  let url = URL(string: "https://beauty-bot-44ou.onrender.com/api/v1/masters/me/timezone") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(["timezone_offset": vm.timezoneOffset])
            do {
                let (_, _) = try await URLSession.shared.data(for: req)
            } catch {}
        }

        func deleteAccount() async {
            guard let token = KeychainManager.shared.getToken(),
                  let url = URL(string: "https://beauty-bot-44ou.onrender.com/api/v1/masters/me") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    await MainActor.run { appState.logout() }
                }
            } catch {}
        }

        var body: some View {
        Color.clear
            .overlay {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                    profileHeader
                    themeSelector
                    profileSection
                    timezoneSection
                    bookingLinkSection
                        loyaltySection
                        notificationsSection
                        scheduleSection
                    paymentDetailsSection
                    appSection
                    reminderTemplatesSection
                    aboutSection
                    logoutButton
                    deleteAccountButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .task { await vm.load() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await vm.load() }
            }
            .alert("Выйти из аккаунта?", isPresented: $showLogoutAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Выйти", role: .destructive) {
                    appState.logout()
                }
            } message: {
                Text("Вы уверены?")
            }
            .alert("Удалить аккаунт", isPresented: $showDeleteAccountAlert) {
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("Это действие необратимо. Все ваши данные, клиенты и записи будут удалены навсегда.")
            }
            .sheet(isPresented: $showBlockedDays) {
                BlockedDaysView()
                    .environmentObject(ThemeManager.shared)
                    .environment(\.theme, theme)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(onFinish: { showOnboarding = false }, isPreview: true)
                    .environmentObject(ThemeManager.shared)
                    .environment(\.theme, theme)
            }
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


            if !vm.phone.isEmpty {
                Text(vm.phone)
                    .font(DS.body)
                    .foregroundColor(theme.textMuted)
            }

            Button(action: {
                HapticManager.medium()
                let av = UIActivityViewController(activityItems: [vm.bookingLink], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(av, animated: true)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 16))
                    Text("Поделиться ссылкой записи")
                        .font(DS.label)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(theme.gradientPrimary)
                .cornerRadius(DS.r12)
                .shadow(color: theme.accentGlow, radius: 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
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
                    ProfileFieldRow(icon: "person.fill", label: "Имя", text: $vm.masterName, theme: theme)
                    Divider().background(theme.borderSubtle)
                    ProfileFieldRow(icon: "envelope.fill", label: "Email", text: $vm.email, theme: theme, keyboardType: .emailAddress)
                    Divider().background(theme.borderSubtle)
                    ProfileFieldRow(icon: "phone.fill", label: "Телефон", text: $vm.phone, theme: theme, keyboardType: .phonePad)
                }
            }

            if let err = vm.errorMessage {
                Text(err).font(DS.bodySmall).foregroundColor(theme.statusRed)
            }

            BBPrimaryButton(title: vm.isSaving ? "Сохранение..." : "Сохранить профиль", isLoading: vm.isSaving) {
                Task { await vm.saveProfile() }
            }
            .environment(\.theme, theme)

            Group {
                if vm.isTelegramConnected {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.statusGreen)
                        Text("Telegram подключён")
                            .foregroundColor(theme.statusGreen)
                            .font(DS.label)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.statusGreen.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Button(action: { Task { await vm.connectTelegram() } }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                            Text("Подключить Telegram")
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.17, green: 0.51, blue: 0.93))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Timezone Section

    private var timezoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Часовой пояс")

            BBGlassCard {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(theme.accent)
                            .frame(width: 24)
                        Picker("Часовой пояс", selection: $vm.timezoneOffset) {
                            Text("Калининград (UTC+2)").tag(2)
                            Text("Москва (UTC+3)").tag(3)
                            Text("Самара (UTC+4)").tag(4)
                            Text("Екатеринбург (UTC+5)").tag(5)
                            Text("Омск (UTC+6)").tag(6)
                            Text("Красноярск (UTC+7)").tag(7)
                            Text("Иркутск (UTC+8)").tag(8)
                            Text("Якутск (UTC+9)").tag(9)
                            Text("Владивосток (UTC+10)").tag(10)
                            Text("Магадан (UTC+11)").tag(11)
                            Text("Камчатка (UTC+12)").tag(12)
                        }
                        .pickerStyle(.menu)
                        .tint(theme.accent)
                        .onChange(of: vm.timezoneOffset) { _ in
                            Task { await saveTimezone() }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Booking Link Section

    private var bookingLinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Онлайн-запись")

            BBGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ссылка для клиентов")
                        .font(DS.label)
                        .foregroundColor(theme.textPrimary)
                    Text("Клиент откроет страницу и запишется сам. Поделись в Stories, Telegram или ВКонтакте.")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text("beautybook.app/")
                            .font(DS.body)
                            .foregroundColor(theme.textMuted)
                        TextField("твой-slug", text: $vm.bookingLinkInput)
                            .font(DS.body)
                            .foregroundColor(theme.textPrimary)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(theme.backgroundInput)
                    .cornerRadius(DS.r12)
                    .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.borderSubtle, lineWidth: 1))

                    if let err = vm.bookingLinkError {
                        Text(err)
                            .font(DS.bodySmall)
                            .foregroundColor(theme.statusRed)
                    }

                    HStack(spacing: 12) {
                        Button(action: { Task { await vm.saveBookingLink() } }) {
                            HStack(spacing: 6) {
                                if vm.bookingLinkSaving {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                                } else if vm.bookingLinkSuccess {
                                    Image(systemName: "checkmark")
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                }
                                Text(vm.bookingLinkSuccess ? "Сохранено!" : "Сохранить")
                            }
                            .font(DS.label)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(vm.bookingLinkSuccess ? theme.statusGreen : theme.accent)
                            .cornerRadius(DS.r12)
                        }
                        .disabled(vm.bookingLinkSaving || vm.bookingLinkInput.isEmpty)

                        if !vm.bookingLink.isEmpty {
                            Button(action: {
                                HapticManager.medium()
                                let av = UIActivityViewController(activityItems: [vm.bookingLink], applicationActivities: nil)
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let root = scene.windows.first?.rootViewController {
                                    root.present(av, animated: true)
                                }
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18))
                                    .foregroundColor(theme.accent)
                                    .frame(width: 40, height: 40)
                                    .background(theme.backgroundInput)
                                    .cornerRadius(DS.r12)
                            }
                        }
                    }
                }
            }

            if !vm.manageLink.isEmpty {
                BBGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ссылка для отмены и переноса")
                            .font(DS.label)
                            .foregroundColor(theme.textPrimary)
                        Text("Клиент вводит номер телефона и управляет своей записью. Закрепи в Telegram-группе с клиентами.")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(vm.manageLink)
                            .font(DS.bodySmall)
                            .foregroundColor(theme.accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.backgroundInput)
                            .cornerRadius(DS.r12)

                        Button(action: {
                            HapticManager.medium()
                            UIPasteboard.general.string = vm.manageLink
                            copiedManageLink = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedManageLink = false }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: copiedManageLink ? "checkmark" : "doc.on.doc")
                                Text(copiedManageLink ? "Скопировано!" : "Скопировать ссылку")
                            }
                            .font(DS.label)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(copiedManageLink ? theme.statusGreen : theme.accent)
                            .cornerRadius(DS.r12)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            HapticManager.medium()
                            let av = UIActivityViewController(activityItems: [vm.manageLink], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(av, animated: true)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Поделиться")
                            }
                            .font(DS.label)
                            .foregroundColor(theme.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(theme.backgroundInput)
                            .cornerRadius(DS.r12)
                        }
                    }
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
                        Text("Тип скидки")
                            .font(DS.body).foregroundColor(theme.textPrimary)
                        Spacer()
                        HStack(spacing: 6) {
                            Text("%")
                                .font(DS.labelSmall)
                                .foregroundColor(vm.loyaltyDiscountType == "percent" ? .white : theme.textSecondary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(vm.loyaltyDiscountType == "percent" ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                .cornerRadius(DS.r8)
                                .onTapGesture { vm.loyaltyDiscountType = "percent" }
                            Text("₽")
                                .font(DS.labelSmall)
                                .foregroundColor(vm.loyaltyDiscountType == "rub" ? .white : theme.textSecondary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(vm.loyaltyDiscountType == "rub" ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                .cornerRadius(DS.r8)
                                .onTapGesture { vm.loyaltyDiscountType = "rub" }
                        }
                    }
                    .padding(16)

                    Divider().background(theme.borderSubtle).padding(.horizontal, 16)

                    HStack {
                        Text("Размер скидки")
                            .font(DS.body).foregroundColor(theme.textPrimary)
                        Spacer()
                        HStack(spacing: 6) {
                            if vm.loyaltyDiscountType == "percent" {
                                ForEach([5, 10, 15], id: \.self) { pct in
                                    Text("\(pct)%")
                                        .font(DS.labelSmall)
                                        .foregroundColor(vm.loyaltyDiscount == pct ? .white : theme.textSecondary)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(vm.loyaltyDiscount == pct ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                        .cornerRadius(DS.r8)
                                        .onTapGesture { vm.loyaltyDiscount = pct }
                                }
                            } else {
                                ForEach([100, 200, 300, 500], id: \.self) { rub in
                                    Text("\(rub)₽")
                                        .font(DS.labelSmall)
                                        .foregroundColor(vm.loyaltyDiscountRub == rub ? .white : theme.textSecondary)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(vm.loyaltyDiscountRub == rub ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                        .cornerRadius(DS.r8)
                                        .onTapGesture { vm.loyaltyDiscountRub = rub }
                                }
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

            BBPrimaryButton(title: "Сохранить настройки лояльности", isLoading: false) {
                Task { await vm.saveLoyaltySettings() }
            }
            .environment(\.theme, theme)
            .padding(.top, 8)
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Уведомления клиентам")

            BBGlassCard {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Напоминания о записи")
                                .font(DS.body).foregroundColor(theme.textPrimary)
                            Text("За 24 часа и за 2 часа до визита")
                                .font(DS.bodySmall).foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $vm.remindersEnabled)
                            .tint(theme.accent)
                            .labelsHidden()
                    }
                    .padding(16)

                    Divider().background(theme.borderSubtle).padding(.horizontal, 16)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Напоминание об оплате")
                                .font(DS.body).foregroundColor(theme.textPrimary)
                            Text("Отправляется после завершения процедуры")
                                .font(DS.bodySmall).foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $vm.paymentReminderEnabled)
                            .tint(theme.accent)
                            .labelsHidden()
                    }
                    .padding(16)

                    Divider().background(theme.borderSubtle).padding(.horizontal, 16)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Напоминание о возврате")
                                .font(DS.body).foregroundColor(theme.textPrimary)
                            Text("Если клиент долго не приходил")
                                .font(DS.bodySmall).foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $vm.returnReminderEnabled)
                            .tint(theme.accent)
                            .labelsHidden()
                    }
                    .padding(16)

                    if vm.returnReminderEnabled {
                        Divider().background(theme.borderSubtle).padding(.horizontal, 16)
                        HStack {
                            Text("Через сколько дней")
                                .font(DS.body).foregroundColor(theme.textPrimary)
                            Spacer()
                            HStack(spacing: 6) {
                                ForEach([14, 21, 30], id: \.self) { days in
                                    Text("\(days)д")
                                        .font(DS.labelSmall)
                                        .foregroundColor(vm.returnReminderDays == days ? .white : theme.textSecondary)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(vm.returnReminderDays == days ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                                        .cornerRadius(DS.r8)
                                        .onTapGesture { vm.returnReminderDays = days }
                                }
                            }
                        }
                        .padding(16)
                        .animation(DS.springSnappy, value: vm.returnReminderEnabled)
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
                }
            }

            BBSectionHeader(title: "Интервал записи")

            BBGlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Мин. шаг онлайн-записи")
                            .font(DS.body).foregroundColor(theme.textPrimary)
                        Text("Время на одну процедуру")
                            .font(DS.bodySmall).foregroundColor(theme.textMuted)
                    }
                    Spacer()
                    Menu {
                        ForEach([30, 45, 60, 90, 120], id: \.self) { mins in
                            Button(vm.slotDurationLabel(mins)) {
                                vm.slotDuration = mins
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(vm.slotDurationLabel(vm.slotDuration))
                                .font(DS.body)
                                .foregroundColor(theme.accent)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }

                Divider().background(theme.borderSubtle)

                NavigationLink(destination: CustomScheduleView().environment(\.theme, theme)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Моё расписание")
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                            Text("Задать конкретные слоты на каждый день")
                                .font(DS.bodySmall)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(16)
                }

                Divider().background(theme.borderSubtle)

                Button(action: { showBlockedDays = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Нерабочие дни")
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                            Text("Даты, когда клиенты не могут записаться")
                                .font(DS.bodySmall)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(16)
                }
            }
            .environment(\.theme, theme)

            BBPrimaryButton(title: vm.isSaving ? "Сохранение..." : "Сохранить изменения", isLoading: vm.isSaving) {
                Task { await vm.save() }
            }
            .environment(\.theme, theme)
        }
    }

    // MARK: - Payment Details Section

    private var paymentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Реквизиты для оплаты")

            BBGlassCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(theme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Номер карты")
                                .font(DS.caption)
                                .foregroundColor(theme.textMuted)
                            TextField("0000 0000 0000 0000", text: $vm.paymentCard)
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                                .keyboardType(.numberPad)
                        }
                    }
                    .padding(16)

                    Divider().background(theme.borderSubtle)

                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(theme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Телефон для перевода")
                                .font(DS.caption)
                                .foregroundColor(theme.textMuted)
                            TextField("+7 (999) 000-00-00", text: $vm.paymentPhone)
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                                .keyboardType(.phonePad)
                        }
                    }
                    .padding(16)

                    Divider().background(theme.borderSubtle)

                    HStack(spacing: 12) {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(theme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Банки (Сбер, Тинькофф...)")
                                .font(DS.caption)
                                .foregroundColor(theme.textMuted)
                            TextField("Сбербанк, Тинькофф", text: $vm.paymentBanks)
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                    .padding(16)
                }
            }

            Text("Реквизиты будут отображаться в напоминаниях об оплате клиентам")
                .font(DS.caption)
                .foregroundColor(theme.textMuted)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Приложение")

            BBGlassCard {
                VStack(spacing: 0) {
                    SettingsRow(icon: "bell.fill", label: "Уведомления", value: "Включены", theme: theme)
                    Divider().background(theme.borderSubtle).padding(.leading, 44)
                    Button(action: {
                        guard !pushTestLoading else { return }
                        Task {
                            pushTestLoading = true
                            guard let token = KeychainManager.shared.getToken() else { pushTestLoading = false; return }
                            guard let url = URL(string: "https://beauty-bot-44ou.onrender.com/api/v1/debug/push-test") else { pushTestLoading = false; return }
                            var req = URLRequest(url: url)
                            req.httpMethod = "POST"
                            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            let (data, _) = (try? await URLSession.shared.data(for: req)) ?? (nil, nil)
                            if let data, let str = String(data: data, encoding: .utf8) {
                                print("[PushTest] \(str)")
                            }
                            pushTestLoading = false
                            pushTestSent = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { pushTestSent = false }
                        }
                    }) {
                        HStack {
                            Image(systemName: pushTestSent ? "checkmark.circle.fill" : "paperplane.fill")
                                .font(.system(size: 16))
                                .foregroundColor(pushTestSent ? theme.statusGreen : theme.accent)
                                .frame(width: 32)
                            Text(pushTestSent ? "Отправлено!" : "Тест пуш-уведомления")
                                .font(DS.body)
                                .foregroundColor(pushTestSent ? theme.statusGreen : theme.textPrimary)
                            Spacer()
                            if pushTestLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent)).scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Reminder Templates

    private var reminderTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Шаблоны сообщений")
            
            BBGlassCard {
                Button(action: { showReminderTemplates = true }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                            .frame(width: 32)
                        Text("Шаблоны напоминаний")
                            .font(DS.body)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textMuted)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .sheet(isPresented: $showReminderTemplates) {
            ReminderTemplatesView()
                .environment(\.theme, theme)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "О приложении")

            BBGlassCard {
                VStack(spacing: 0) {
                    Button(action: { showOnboarding = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16))
                                .foregroundColor(theme.accent)
                                .frame(width: 32)
                            Text("Как пользоваться приложением")
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textMuted)
                        }
                        .padding(.vertical, 12)
                    }

                    Divider().background(theme.borderSubtle)

                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(theme.accent)
                            .frame(width: 32)
                        Text("Версия 1.0")
                            .font(DS.body)
                            .foregroundColor(theme.textMuted)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {
        BBSecondaryButton(title: "Выйти из аккаунта", color: theme.statusRed) {
            showLogoutAlert = true
        }
    }

    private var deleteAccountButton: some View {
        BBSecondaryButton(title: "Удалить аккаунт", color: theme.statusRed) {
            showDeleteAccountAlert = true
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