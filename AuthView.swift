import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            glowBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    logoSection.padding(.top, 72).padding(.bottom, 40)

                    Group {
                        switch vm.screen {
                        case .login:          LoginForm(vm: vm)
                        case .forgotPassword: ForgotForm(vm: vm)
                        }
                    }
                    .animation(DS.springSnappy, value: vm.screen)
                    .padding(.horizontal, 24)
                }
            }
        }
        .onAppear {
            vm.onSuccess = { master, token in appState.login(master: master, token: token) }
        }
    }

    private var logoSection: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: theme.accentGlow, radius: 24, x: 0, y: 8)
                Group {
                    if let path = Bundle.main.path(forResource: "solva_logo", ofType: "png"),
                       let uiImg = UIImage(contentsOfFile: path) {
                        Image(uiImage: uiImg)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.pink.opacity(0.3))
                            .frame(width: 64, height: 64)
                    }
                }
            }
            VStack(spacing: 6) {
                Text("Solva Beauty")
                    .font(DS.titleMedium)
                    .foregroundColor(theme.textPrimary)
                Text("CRM для бьюти-мастера")
                    .font(DS.body)
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    private var glowBackground: some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(0.1))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -100, y: -220)
            Circle()
                .fill(theme.accentSecondary.opacity(0.07))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 130, y: 120)
        }
    }
}

// MARK: - Login Form

struct LoginForm: View {
    @ObservedObject var vm: AuthViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Вход").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text("Войди в свой аккаунт").font(DS.body).foregroundColor(theme.textSecondary)
            }.padding(.bottom, 4)

            BBTextField(placeholder: "Email", text: $vm.loginEmail, keyboardType: .emailAddress, contentType: .emailAddress)
                .environment(\.theme, theme)
            BBTextField(placeholder: "Пароль", text: $vm.loginPassword, isSecure: true, showPasswordToggle: true)
                .environment(\.theme, theme)

            if let err = vm.errorMessage { BBErrorBanner(message: err).environment(\.theme, theme) }

            BBPrimaryButton(title: "Войти", isLoading: vm.isLoading, isDisabled: !vm.loginValid) {
                Task { await vm.login() }
            }.environment(\.theme, theme)

            Button("Забыл пароль?") { vm.switchTo(.forgotPassword) }
                .font(DS.body).foregroundColor(theme.accent)

        }
    }
}

// MARK: - Forgot Password Form

struct ForgotForm: View {
    @ObservedObject var vm: AuthViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: { vm.switchTo(.login) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("Назад").font(DS.body)
                    }.foregroundColor(theme.textSecondary)
                }
                Spacer()
            }

            ZStack {
                RoundedRectangle(cornerRadius: DS.r16).fill(theme.backgroundInput).frame(width: 64, height: 64)
                Image(systemName: "lock.rotation").font(.system(size: 28)).foregroundColor(theme.accent)
            }

            if vm.resetStep == 0 {
                stepEmail
            } else if vm.resetStep == 1 {
                stepNoTelegram
            } else if vm.resetStep == 2 {
                stepCode
            } else if vm.resetStep == 3 {
                stepSuccess
            }
        }
    }

    private var stepEmail: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Сброс пароля").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text("Введи email и мы отправим код в Telegram").font(DS.body).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)
            }

            BBTextField(placeholder: "Email", text: $vm.forgotEmail, keyboardType: .emailAddress).environment(\.theme, theme)
            if let err = vm.errorMessage { BBErrorBanner(message: err).environment(\.theme, theme) }
            BBPrimaryButton(title: "Отправить", isLoading: vm.isLoading, isDisabled: !vm.forgotEmail.contains("@")) {
                Task { await vm.forgotPassword() }
            }.environment(\.theme, theme)
        }
    }

    private var stepNoTelegram: some View {
        VStack(spacing: 20) {
            Text("\u{26A0}\u{FE0F}").font(.system(size: 48))

            Text("Чтобы сбросить пароль, нужно сначала привязать Telegram в настройках приложения. Войдите в аккаунт и перейдите в Настройки → Telegram, чтобы получать код для восстановления пароля.")
                .font(DS.body).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)

            if let err = vm.errorMessage { BBErrorBanner(message: err).environment(\.theme, theme) }

            BBPrimaryButton(title: "Вернуться к входу") { vm.switchTo(.login) }
                .environment(\.theme, theme)
        }
    }

    private var stepCode: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Сброс пароля").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text("Мы отправили код в ваш Telegram").font(DS.body).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)
            }

            BBTextField(placeholder: "Код из Telegram", text: $vm.resetCode, keyboardType: .numberPad).environment(\.theme, theme)
            BBTextField(placeholder: "Новый пароль", text: $vm.newPassword, isSecure: true).environment(\.theme, theme)
            BBTextField(placeholder: "Повтор пароля", text: $vm.newPasswordConfirm, isSecure: true).environment(\.theme, theme)
            if let err = vm.errorMessage { BBErrorBanner(message: err).environment(\.theme, theme) }
            BBPrimaryButton(title: "Сбросить пароль", isLoading: vm.isLoading, isDisabled: !vm.resetFormValid) {
                Task { await vm.resetPassword() }
            }.environment(\.theme, theme)
        }
    }

    private var stepSuccess: some View {
        VStack(spacing: 20) {
            Text("\u{2705}").font(.system(size: 48))

            Text("Пароль изменён! Теперь можно войти с новым паролем")
                .font(DS.body).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)

            if let msg = vm.successMessage {
                Text(msg).font(DS.body).foregroundColor(theme.statusGreen)
            }

            BBPrimaryButton(title: "Войти") { vm.switchTo(.login) }
                .environment(\.theme, theme)
        }
    }
}

func formatRussianPhone(_ input: String) -> String {
    let digits = input.filter { $0.isNumber }
    if digits.isEmpty { return "" }
    var d = digits
    if d.hasPrefix("8") && d.count > 1 { d = "7" + d.dropFirst() }
    if d.hasPrefix("9") { d = "7" + d }
    if !d.hasPrefix("7") { d = "7" + d }
    let limited = String(d.prefix(11))
    var result = "+"
    for (i, c) in limited.enumerated() {
        if i == 1 || i == 4 || i == 7 || i == 9 { result.append(" ") }
        result.append(c)
    }
    return result
}

#Preview {
    AuthView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .environment(\.theme, .pink)
}
