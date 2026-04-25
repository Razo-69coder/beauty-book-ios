import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var masterName       = ""
    @Published var email            = ""
    @Published var workStart        = 9
    @Published var workEnd          = 20
    @Published var slotDuration     = 60
    @Published var reminderDays     = 30
    @Published var paymentCard      = ""
    @Published var paymentPhone     = ""
    @Published var paymentBanks     = ""
    @Published var isSaving         = false
    @Published var saveSuccess      = false
    @Published var errorMessage: String? = nil

    private let api = APIClient.shared

    func load() async {
        if let m = try? await api.request(.me, as: MasterProfile.self) {
            masterName    = m.name ?? ""
            email         = m.email ?? ""
            workStart     = m.workStart
            workEnd       = m.workEnd
            slotDuration  = m.slotDuration
            reminderDays  = m.reminderDays
            paymentCard   = m.paymentCard ?? ""
            paymentPhone  = m.paymentPhone ?? ""
            paymentBanks  = m.paymentBanks ?? ""
        } else {
            // Мок
            let m = MockData.master
            masterName = m.name ?? "Мастер"; email = m.email ?? ""
            workStart = m.workStart; workEnd = m.workEnd
            slotDuration = m.slotDuration; reminderDays = m.reminderDays
            paymentCard = m.paymentCard ?? ""; paymentPhone = m.paymentPhone ?? ""
            paymentBanks = m.paymentBanks ?? ""
        }
    }

    func save() async {
        isSaving = true; errorMessage = nil
        let req = MasterSettingsRequest(name: masterName, workStart: workStart, workEnd: workEnd,
                                         slotDuration: slotDuration, reminderDays: reminderDays, timezone: "Europe/Moscow")
        do {
            let _ = try await api.request(.updateSettings(req), as: MessageResponse.self)
            let payReq = PaymentRequest(paymentCard: paymentCard, paymentPhone: paymentPhone, paymentBanks: paymentBanks)
            let _ = try await api.request(.updatePayment(payReq), as: MessageResponse.self)
            saveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.saveSuccess = false }
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка сохранения" }
        isSaving = false
    }
}

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.s20) {
                    header
                    profileSection
                    workHoursSection
                    paymentSection
                    themeSection
                    logoutButton
                }
                .padding(.horizontal, DS.s20)
                .padding(.bottom, 100)
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Настройки").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text(vm.masterName.isEmpty ? "Профиль мастера" : vm.masterName)
                    .font(DS.body).foregroundColor(theme.textSecondary)
            }
            Spacer()
            if vm.saveSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(theme.statusGreen)
                    Text("Сохранено").font(DS.bodySmall).foregroundColor(theme.statusGreen)
                }
                .transition(.opacity)
            }
        }
        .padding(.top, DS.s16)
        .animation(DS.springSnappy, value: vm.saveSuccess)
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: "Профиль").environment(\.theme, theme)
            BBCard {
                VStack(spacing: DS.s12) {
                    BBTextField(placeholder: "Имя мастера", text: $vm.masterName).environment(\.theme, theme)
                    BBTextField(placeholder: "Email", text: $vm.email, keyboardType: .emailAddress).environment(\.theme, theme)
                }
            }.environment(\.theme, theme)
        }
    }

    // MARK: - Work Hours

    private var workHoursSection: some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: "Рабочие часы").environment(\.theme, theme)
            BBCard {
                VStack(spacing: DS.s16) {
                    StepperRow(label: "Начало работы", value: $vm.workStart, range: 5...12,
                               display: "\(vm.workStart):00", theme: theme)
                    Divider().background(theme.borderSubtle)
                    StepperRow(label: "Конец работы", value: $vm.workEnd, range: 14...23,
                               display: "\(vm.workEnd):00", theme: theme)
                    Divider().background(theme.borderSubtle)
                    StepperRow(label: "Слот (мин)", value: $vm.slotDuration, range: 30...120, step: 15,
                               display: "\(vm.slotDuration) мин", theme: theme)
                    Divider().background(theme.borderSubtle)
                    StepperRow(label: "Напомнить (дни)", value: $vm.reminderDays, range: 7...90, step: 7,
                               display: "\(vm.reminderDays) дн", theme: theme)
                }
            }.environment(\.theme, theme)
        }
    }

    // MARK: - Payment

    private var paymentSection: some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: "Реквизиты оплаты").environment(\.theme, theme)
            BBCard {
                VStack(spacing: DS.s12) {
                    BBTextField(placeholder: "Номер карты", text: $vm.paymentCard, keyboardType: .numberPad).environment(\.theme, theme)
                    BBTextField(placeholder: "Телефон для переводов", text: $vm.paymentPhone, keyboardType: .phonePad).environment(\.theme, theme)
                    BBTextField(placeholder: "Банки (Сбер, Тинькофф...)", text: $vm.paymentBanks).environment(\.theme, theme)
                }
            }.environment(\.theme, theme)

            BBPrimaryButton(title: vm.isSaving ? "Сохраняю..." : "Сохранить изменения",
                            isLoading: vm.isSaving) {
                Task { await vm.save() }
            }.environment(\.theme, theme)
        }
    }

    // MARK: - Theme

    private var themeSection: some View {
        VStack(spacing: DS.s8) {
            BBSectionHeader(title: "Тема приложения").environment(\.theme, theme)
            HStack(spacing: DS.s12) {
                ForEach(AppTheme.allCases, id: \.self) { t in
                    ThemeButton(appTheme: t, isSelected: themeManager.current == t) {
                        withAnimation(DS.springSmooth) { themeManager.current = t }
                    }
                }
            }
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button(action: { appState.logout() }) {
            HStack(spacing: DS.s8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Выйти из аккаунта")
            }
            .font(DS.label)
            .foregroundColor(theme.statusRed)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(theme.statusRed.opacity(0.1))
            .cornerRadius(DS.r16)
            .overlay(RoundedRectangle(cornerRadius: DS.r16).stroke(theme.statusRed.opacity(0.2), lineWidth: 1))
        }
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
            Text(label).font(DS.body).foregroundColor(theme.textPrimary)
            Spacer()
            HStack(spacing: DS.s12) {
                Button(action: { if value - step >= range.lowerBound { value -= step } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(value <= range.lowerBound ? theme.textMuted : theme.accent)
                }
                Text(display).font(DS.label).foregroundColor(theme.textPrimary).frame(minWidth: 60, alignment: .center)
                Button(action: { if value + step <= range.upperBound { value += step } }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(value >= range.upperBound ? theme.textMuted : theme.accent)
                }
            }
        }
    }
}

// MARK: - Theme Button

struct ThemeButton: View {
    let appTheme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.s8) {
                ZStack {
                    Circle()
                        .fill(appTheme.gradientPrimary)
                        .frame(width: 48, height: 48)
                        .shadow(color: appTheme.accentGlow, radius: 8, x: 0, y: 4)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(appTheme.displayName)
                    .font(DS.labelSmall)
                    .foregroundColor(isSelected ? appTheme.accent : Color(hex: "#5A5A7A"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.s12)
            .background(isSelected ? appTheme.accent.opacity(0.1) : Color(hex: "#11111E"))
            .cornerRadius(DS.r12)
            .overlay(
                RoundedRectangle(cornerRadius: DS.r12)
                    .stroke(isSelected ? appTheme.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .environment(\.theme, .pink)
}
