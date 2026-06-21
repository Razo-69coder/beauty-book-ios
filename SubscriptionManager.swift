import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    private let productId = "com.beautybook.app.pro_monthly"

    @Published var product: Product? = nil
    @Published var isPurchased = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private init() {}

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productId])
            product = products.first
            await checkStatus()
        } catch {
            print("[IAP] Failed to load product: \(error)")
        }
    }

    func purchase() async {
        guard let product = product else {
            errorMessage = "Продукт недоступен"
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isPurchased = true
                    await notifyBackend(transactionId: String(transaction.id))
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Покупка ожидает подтверждения"
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Ошибка покупки. Попробуйте ещё раз."
        }
        isLoading = false
    }

    func checkStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productId {
                isPurchased = true
                return
            }
        }
    }

    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await checkStatus()
        } catch {
            errorMessage = "Не удалось восстановить покупки"
        }
        isLoading = false
    }

    private func notifyBackend(transactionId: String) async {
        guard let token = KeychainManager.shared.getToken(),
              let url = URL(string: "https://beauty-bot-44ou.onrender.com/api/v1/payment/iap") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["transaction_id": transactionId, "product_id": productId])
        _ = try? await URLSession.shared.data(for: req)
    }
}
