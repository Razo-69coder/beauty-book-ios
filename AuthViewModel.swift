import Foundation
import SwiftUI

enum AuthScreen { case login, register, forgotPassword }

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var screen: AuthScreen       = .login
    @Published var loginEmail               = ""
    @Published var loginPassword            = ""
    @Published var forgotEmail              = ""
    @Published var isLoading                = false
    @Published var errorMessage: String?    = nil
    @Published var successMessage: String?  = nil
    @Published var telegramConnected        = false
    @Published var resetCode                = ""
    @Published var newPassword              = ""
    @Published var newPasswordConfirm       = ""
    @Published var resetStep                = 0
    @Published var regName                  = ""
    @Published var regEmail                 = ""
    @Published var regPhone                 = ""
    @Published var regPassword              = ""
    @Published var regAgree                 = false

    var onSuccess: ((MasterProfile, String) -> Void)?
    private let api = APIClient.shared

    /// В поле входа можно email или телефон — сервер понимает оба
    var loginIdentifierValid: Bool {
        let trimmed = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") { return true }
        return loginIdentifierDigits.count >= 10
    }

    /// Только цифры из поля входа, без форматирования
    private var loginIdentifierDigits: String {
        loginEmail.filter { $0.isNumber }
    }

    /// Телефон приводим к +7XXXXXXXXXX: 8→7, 10 цифр → «7» в начале
    private var loginPhoneNormalized: String {
        var digits: String = String(loginIdentifierDigits.prefix(11))
        if digits.hasPrefix("8"), digits.count > 1 { digits = "7" + digits.dropFirst() }
        if digits.hasPrefix("9") { digits = "7" + digits }
        if digits.count == 10 { digits = "7" + digits }
        if !digits.hasPrefix("7") { digits = "7" + digits }
        return "+" + String(digits.prefix(11))
    }

    var loginValid: Bool {
        loginIdentifierValid &&
        loginPassword.trimmingCharacters(in: .whitespaces).count >= 6 &&
        !isLoading
    }
    var resetFormValid: Bool {
        resetCode.count >= 6 && newPassword.count >= 6 && newPassword == newPasswordConfirm && !isLoading
    }

    /// Только цифры телефона без форматирования — для проверки и отправки на сервер
    private var regPhoneDigits: String {
        String(regPhone.filter { $0.isNumber }.prefix(11))
    }

    /// Номер в формате +7 и 11 цифр — так его ждёт сервер
    var regPhoneNormalized: String {
        var digits = regPhoneDigits
        if digits.hasPrefix("8"), digits.count > 1 { digits = "7" + digits.dropFirst() }
        if digits.hasPrefix("9") { digits = "7" + digits }
        if !digits.hasPrefix("7") { digits = "7" + digits }
        return "+" + String(digits.prefix(11))
    }

    var registerValid: Bool {
        regName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 &&
        regEmail.trimmingCharacters(in: .whitespacesAndNewlines).contains("@") &&
        regEmail.contains(".") &&
        regPhoneDigits.count == 11 &&
        regPassword.count >= 6 &&
        regAgree &&
        !isLoading
    }

    func login() async {
        let identifier = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = loginPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard loginIdentifierValid && trimmedPassword.count >= 6 && !isLoading else { return }
        // Без «@» считаем, что введен телефон, и приводим к виду +7XXXXXXXXXX
        let login: String = identifier.contains("@") ? identifier.lowercased() : loginPhoneNormalized
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.request(.login(LoginRequest(email: login, password: trimmedPassword)), as: AuthTokenResponse.self)
            onSuccess?(resp.master, resp.token)
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Неверный email, телефон или пароль" }
        isLoading = false
    }

    /// Регистрация мастера: сервер вернёт тот же токен, что и при входе
    func register() async {
        guard registerValid else { return }
        let name = regName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = regEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = regPassword
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.request(
                .register(RegisterRequest(email: email.lowercased(), password: password, name: name, phone: regPhoneNormalized)),
                as: AuthTokenResponse.self
            )
            onSuccess?(resp.master, resp.token)
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка регистрации. Проверь данные." }
        isLoading = false
    }

    func forgotPassword() async {
        guard forgotEmail.contains("@"), !isLoading else { return }
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.request(.forgotPassword(email: forgotEmail), as: ForgotPasswordResponse.self)
            telegramConnected = resp.telegramConnected
            if resp.telegramConnected {
                resetStep = 2
            } else {
                resetStep = 1
            }
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка. Проверь email." }
        isLoading = false
    }

    func resetPassword() async {
        guard resetFormValid else { return }
        isLoading = true; errorMessage = nil
        do {
            let _ = try await api.request(.resetPassword(email: forgotEmail, code: resetCode, newPassword: newPassword), as: MessageResponse.self)
            resetStep = 3
            successMessage = "Пароль изменён!"
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка сброса пароля." }
        isLoading = false
    }

    func switchTo(_ s: AuthScreen) {
        withAnimation(DS.springSnappy) { screen = s }
        errorMessage = nil; successMessage = nil
        resetStep = 0; telegramConnected = false
        resetCode = ""; newPassword = ""; newPasswordConfirm = ""
        // Уходя с регистрации — чистим пароль, чтобы он не остался в памяти
        if s != .register { regPassword = ""; regAgree = false }
    }
}
