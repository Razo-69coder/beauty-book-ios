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
                        case .register:       RegisterForm(vm: vm)
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

            BBTextField(placeholder: "Email", text: $vm.loginEmail, keyboardType: .emailAddress)
                .environment(\.theme, theme)
            BBTextField(placeholder: "Пароль", text: $vm.loginPassword, isSecure: true)
                .environment(\.theme, theme)

            if let err = vm.errorMessage { BBErrorBanner(message: err).environment(\.theme, theme) }

            BBPrimaryButton(title: "Войти", isLoading: vm.isLoading, isDisabled: !vm.loginValid) {
                Task { await vm.login() }
            }.environment(\.theme, theme)

            Button("Забыл пароль?") { vm.switchTo(.forgotPassword) }
                .font(DS.body).foregroundColor(theme.accent)

            Divider().background(theme.borderSubtle).padding(.vertical, 4)

            HStack(spacing: 6) {
                Text("Нет аккаунта?").font(DS.body).foregroundColor(theme.textSecondary)
                Button("Зарегистрироваться") { vm.switchTo(.register) }
                    .font(DS.label).foregroundColor(theme.accent)
            }
        }
    }
}

// MARK: - Register Form

struct RegisterForm: View {
    @ObservedObject var vm: AuthViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { vm.switchTo(.login) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text("Назад").font(DS.body)
                    }.foregroundColor(theme.textSecondary)
                }
                Spacer()
            }

            VStack(spacing: 8) {
                Text("Регистрация").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text("Создай аккаунт мастера").font(DS.body).foregroundColor(theme.textSecondary)
            }.padding(.bottom, 4)

            BBTextField(placeholder: "Имя мастера", text: $vm.regName).environment(\.theme, theme)
            BBTextField(placeholder: "Email", text: $vm.regEmail, keyboardType: .emailAddress).environment(\.theme, theme)
            BBTextField(placeholder: "Пароль (мин. 6 символов)", text: $vm.regPassword, isSecure: true).environment(\.theme, theme)
            BBTextField(
                placeholder: "Повтор пароля",
                text: $vm.regConfirm,
                isSecure: true,
                isValid: !vm.passwordsMismatch
            ).environment(\.theme, theme)

            if vm.passwordsMismatch {
                HStack {
                    Text("Пароли не совпадают").font(DS.bodySmall).foregroundColor(theme.statusRed)
                    Spacer()
                }
            }

            if let err = vm.errorMessage { BBErrorBanner(message: err).environment(\.theme, theme) }

            BBPrimaryButton(title: "Создать аккаунт", isLoading: vm.isLoading, isDisabled: !vm.registerValid) {
                Task { await vm.register() }
            }.environment(\.theme, theme)
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

            VStack(spacing: 8) {
                Text("Сброс пароля").font(DS.titleSmall).foregroundColor(theme.textPrimary)
                Text(vm.forgotSent ? "Письмо отправлено!" : "Введи email и мы пришлём ссылку для сброса")
                    .font(DS.body).foregroundColor(theme.textSecondary).multilineTextAlignment(.center)
            }

            if !vm.forgotSent {
                BBTextField(placeholder: "Email", text: $vm.forgotEmail, keyboardType: .emailAddress).environment(\.theme, theme)
                if let err = vm.errorMessage { BBErrorBanner(message: err).environment(\.theme, theme) }
                BBPrimaryButton(title: "Отправить", isLoading: vm.isLoading, isDisabled: !vm.forgotEmail.contains("@")) {
                    Task { await vm.forgotPassword() }
                }.environment(\.theme, theme)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(theme.statusGreen)
                    if let msg = vm.successMessage {
                        Text(msg).font(DS.body).foregroundColor(theme.statusGreen)
                    }
                }
                .padding()
                .background(theme.statusGreen.opacity(0.1))
                .cornerRadius(DS.r12)

                BBPrimaryButton(title: "Вернуться к входу") { vm.switchTo(.login) }
                    .environment(\.theme, theme)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
        .environment(\.theme, .pink)
}
