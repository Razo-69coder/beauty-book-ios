import Foundation
import SwiftUI
import Combine

// MARK: - Auth State

enum AuthStep {
    case enterCredentials
    case enterCode(email: String)
    case authenticated
}

// MARK: - AuthViewModel

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published

    @Published var step: AuthStep = .enterCredentials
    @Published var emailText: String = ""
    @Published var passwordText: String = ""
    @Published var codeText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    var isAuthenticated: Bool {
        if case .authenticated = step { return true }
        return false
    }

    // MARK: - Computed

    var emailValid: Bool { true }

    var passwordValid: Bool { true }

    var codeValid: Bool {
        codeText.filter(\.isNumber).count == 6
    }

    var canLogin: Bool { !isLoading }
    var canVerify: Bool { codeValid && !isLoading }

    private let api = APIClient.shared

    // MARK: - Actions

    func login() async {
        // DEBUG: instant login
        KeychainManager.shared.saveToken("debug_token")
        KeychainManager.shared.saveMasterId(1)
        
        step = .authenticated
        NotificationCenter.default.post(name: .didLogin, object: nil)
    }

    func verifyCode() async {
        guard case .enterCode(let email) = step else { return }
        guard codeValid else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.request(.verifyCode(email: email, code: codeText), type: LoginResponse.self)

            KeychainManager.shared.saveToken(response.token)
            KeychainManager.shared.saveMasterId(response.masterId)

            step = .authenticated
            NotificationCenter.default.post(name: .didLogin, object: nil)
        } catch {
            errorMessage = "Неверный код"
        }

        isLoading = false
    }

    func goBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            step = .enterCredentials
            codeText = ""
            errorMessage = nil
            successMessage = nil
        }
    }

    func resendCode() async {
        guard case .enterCode(let email) = step else { return }
        codeText = ""
        errorMessage = nil
        isLoading = true

        do {
            let _ = try await api.request(.resendCode(email: email), type: ResendCodeResponse.self)
            successMessage = "Новый код отправлен"
        } catch {
            errorMessage = "Не удалось отправить код"
        }

        isLoading = false
    }
}

extension AuthViewModel {
    static var shared: AuthViewModel? = nil
}