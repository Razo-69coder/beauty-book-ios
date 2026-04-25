import Foundation
import SwiftUI
import Combine

// MARK: - Auth State

enum AuthStep {
    case enterTelegramId
    case enterCode(telegramId: Int)
    case authenticated
}

// MARK: - AuthViewModel

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published

    @Published var step: AuthStep = .enterTelegramId
    @Published var telegramIdText: String = ""
    @Published var codeText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    // MARK: - Computed

    var telegramIdValid: Bool {
        let cleaned = telegramIdText.filter(\.isNumber)
        return cleaned.count >= 5 && cleaned.count <= 12
    }

    var codeValid: Bool {
        codeText.filter(\.isNumber).count == 6
    }

    var canRequestCode: Bool { telegramIdValid && !isLoading }
    var canVerify: Bool { codeValid && !isLoading }

    private let api = APIClient.shared

    // MARK: - Actions

    func requestCode() async {
        guard let telegramId = Int(telegramIdText.filter(\.isNumber)) else { return }

        isLoading = true
        errorMessage = nil

        do {
            let _ = try await api.request(.requestCode(telegramId: telegramId), type: RequestCodeResponse.self)
            successMessage = "Код отправлен в Telegram"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                step = .enterCode(telegramId: telegramId)
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Произошла ошибка. Попробуй ещё раз."
        }

        isLoading = false
    }

    func verifyCode() async {
        guard case .enterCode(let telegramId) = step else { return }
        let code = codeText.filter(\.isNumber)
        guard code.count == 6 else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await api.request(
                .verifyCode(telegramId: telegramId, code: code),
                type: AuthTokenResponse.self
            )
            KeychainManager.shared.saveToken(response.token)
            KeychainManager.shared.saveMasterId(response.master.id)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                step = .authenticated
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            // Сброс поля кода при ошибке
            codeText = ""
        } catch {
            errorMessage = "Неверный код. Проверь и попробуй ещё раз."
            codeText = ""
        }

        isLoading = false
    }

    func goBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            step = .enterTelegramId
            codeText = ""
            errorMessage = nil
            successMessage = nil
        }
    }

    func resendCode() async {
        guard case .enterCode(let telegramId) = step else { return }
        codeText = ""
        errorMessage = nil
        isLoading = true

        do {
            let _ = try await api.request(.requestCode(telegramId: telegramId), type: RequestCodeResponse.self)
            successMessage = "Новый код отправлен"
        } catch {
            errorMessage = "Не удалось отправить код. Проверь интернет."
        }

        isLoading = false
    }
}
