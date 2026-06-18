import Foundation
import SwiftUI

enum AuthScreen { case login, forgotPassword }

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

    var onSuccess: ((MasterProfile, String) -> Void)?
    private let api = APIClient.shared

    var loginValid: Bool {
        loginEmail.trimmingCharacters(in: .whitespaces).contains("@") &&
        loginPassword.trimmingCharacters(in: .whitespaces).count >= 6 &&
        !isLoading
    }
    var resetFormValid: Bool {
        resetCode.count >= 6 && newPassword.count >= 6 && newPassword == newPasswordConfirm && !isLoading
    }

    func login() async {
        let trimmedEmail = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = loginPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") && trimmedPassword.count >= 6 && !isLoading else { return }
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.request(.login(LoginRequest(email: trimmedEmail, password: trimmedPassword)), as: AuthTokenResponse.self)
            onSuccess?(resp.master, resp.token)
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка входа. Проверь данные." }
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
    }
}
