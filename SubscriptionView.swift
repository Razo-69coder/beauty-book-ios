import SwiftUI
import SafariServices

// MARK: - Models
struct PaymentResponse: Decodable {
    let paymentId: String
    let confirmationUrl: String
}

// MARK: - SafariView
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - View Model
@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var paymentURL: URL? = nil
    @Published var showSafari = false
    @Published var checking = false
    @Published var notYetMessage = false
    @Published var isActive = false

    func createPayment() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp: PaymentResponse = try await APIClient.shared.request(.createPayment, as: PaymentResponse.self)
            paymentURL = URL(string: resp.confirmationUrl)
            if paymentURL != nil {
                showSafari = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func checkStatus() async {
        checking = true
        notYetMessage = false
        do {
            struct StatusResp: Decodable { let isActive: Bool }
            let resp = try await APIClient.shared.request(.subscriptionStatus, as: StatusResp.self)
            if resp.isActive {
                isActive = true
                NotificationCenter.default.post(name: .subscriptionActivated, object: nil)
            } else {
                notYetMessage = true
            }
        } catch { }
        checking = false
    }
}

// MARK: - View
struct SubscriptionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme
    @StateObject private var vm = SubscriptionViewModel()

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 48)

                    VStack(spacing: 12) {
                        Text("💳")
                            .font(.system(size: 60))
                        Text("Подписка Solvo Beauty")
                            .font(DS.titleLarge)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("690 ₽ / месяц")
                            .font(DS.titleMedium)
                            .foregroundColor(theme.accent)
                        Text("Оплата через ЮКассу (карта или СБП).\nПосле оплаты подписка активируется автоматически.")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if vm.isActive {
                        VStack(spacing: 12) {
                            Text("✅ Подписка активна")
                                .font(DS.titleMedium)
                                .foregroundColor(theme.accent)
                        }
                    } else {
                        Button(action: { Task { await vm.createPayment() } }) {
                            HStack {
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Оплатить 690 ₽ / месяц")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theme.gradientPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(vm.isLoading)
                        .padding(.horizontal)

                        Divider()
                            .background(theme.borderSubtle)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            Text("Уже оплатили?")
                                .font(DS.body)
                                .foregroundColor(theme.textSecondary)

                            Button(action: { Task { await vm.checkStatus() } }) {
                                Text(vm.checking ? "Проверяем..." : "Проверить статус")
                                    .font(DS.body)
                                    .foregroundColor(theme.textSecondary)
                            }
                            .disabled(vm.checking)

                            if vm.notYetMessage {
                                Text("Ещё не активирована. Ожидайте.")
                                    .font(DS.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal)
                    }

                    if let err = vm.errorMessage {
                        Text(err)
                            .font(DS.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $vm.showSafari) {
            if let url = vm.paymentURL {
                SafariView(url: url)
            }
        }
    }
}
