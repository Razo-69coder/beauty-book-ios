import SwiftUI

// MARK: - View Model
@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var isSending = false
    @Published var sent = false
    @Published var errorMessage: String? = nil
    @Published var checking = false
    @Published var notYetMessage = false

    func notifyPaid() async {
        isSending = true
        errorMessage = nil
        do {
            let _: EmptyResponse = try await APIClient.shared.request(.subscriptionNotify)
            sent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func checkStatus() async {
        checking = true
        notYetMessage = false
        do {
            struct StatusResp: Decodable { let isActive: Bool }
            let resp = try await APIClient.shared.request(.subscriptionStatus, as: StatusResp.self)
            if resp.isActive {
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
                        Text("Выберите тариф")
                            .font(DS.titleLarge)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Оплата через безопасный сайт.\nПосле оплаты нажмите «Я оплатил».")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        if let url = URL(string: "https://solvobeauty.vercel.app/pay.html") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Открыть страницу оплаты")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.gradientPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)

                    Divider()
                        .background(theme.borderSubtle)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        Text("После оплаты")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)

                        if vm.sent {
                            Text("✅ Уведомление отправлено!\nАктивируем доступ в течение нескольких часов.")
                                .font(DS.body)
                                .foregroundColor(theme.accent)
                                .multilineTextAlignment(.center)
                                .padding()

                            Button(action: { Task { await vm.checkStatus() } }) {
                                Text(vm.checking ? "Проверяем..." : "Проверить статус")
                                    .font(DS.body)
                                    .foregroundColor(theme.textSecondary)
                            }
                            .disabled(vm.checking)

                            if vm.notYetMessage {
                                Text("Ещё не активированы. Ожидайте.")
                                    .font(DS.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            Button(action: { Task { await vm.notifyPaid() } }) {
                                HStack {
                                    if vm.isSending {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Я оплатил — уведомить администратора")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.backgroundCard)
                                .foregroundColor(theme.textPrimary)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(theme.accent, lineWidth: 1)
                                )
                            }
                            .disabled(vm.isSending)
                        }

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(DS.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
        }
    }
}
