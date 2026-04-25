import Foundation
import SwiftUI

enum AuthScreen { case login, register, forgotPassword }

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var screen: AuthScreen   = .login
    @Published var loginEmail           = ""
    @Published var loginPassword        = ""
    @Published var regName              = ""
    @Published var regEmail             = ""
    @Published var regPassword          = ""
    @Published var regConfirm           = ""
    @Published var forgotEmail          = ""
    @Published var forgotSent           = false
    @Published var isLoading            = false
    @Published var errorMessage: String?  = nil
    @Published var successMessage: String? = nil

    var onSuccess: ((MasterProfile, String) -> Void)?
    private let api = APIClient.shared

    var loginValid: Bool    { loginEmail.contains("@") && loginPassword.count >= 6 && !isLoading }
    var registerValid: Bool { !regName.isEmpty && regEmail.contains("@") && regPassword.count >= 6 && regPassword == regConfirm && !isLoading }
    var passwordsMismatch: Bool { !regConfirm.isEmpty && regPassword != regConfirm }

    func login() async {
        guard loginValid else { return }
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.request(.login(LoginRequest(email: loginEmail, password: loginPassword)), as: AuthTokenResponse.self)
            onSuccess?(resp.master, resp.token)
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка входа. Проверь данные." }
        isLoading = false
    }

    func register() async {
        guard registerValid else { return }
        isLoading = true; errorMessage = nil
        do {
            let resp = try await api.request(.register(RegisterRequest(email: regEmail, password: regPassword, name: regName)), as: AuthTokenResponse.self)
            onSuccess?(resp.master, resp.token)
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка регистрации. Попробуй позже." }
        isLoading = false
    }

    func forgotPassword() async {
        guard forgotEmail.contains("@"), !isLoading else { return }
        isLoading = true; errorMessage = nil
        do {
            let _ = try await api.request(.forgotPassword(email: forgotEmail), as: MessageResponse.self)
            forgotSent = true
            successMessage = "Ссылка отправлена на \(forgotEmail)"
        } catch let e as NetworkError { errorMessage = e.errorDescription
        } catch { errorMessage = "Ошибка. Проверь email." }
        isLoading = false
    }

    func switchTo(_ s: AuthScreen) {
        withAnimation(DS.springSnappy) { screen = s }
        errorMessage = nil; successMessage = nil
    }
}
