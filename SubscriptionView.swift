import SwiftUI

// MARK: - Empty Response
struct EmptyResponse: Decodable {}

// MARK: - View Model
@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var isSending = false
    @Published var sent = false
    @Published var errorMessage: String? = nil

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
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Header
                    VStack(spacing: 12) {
                        Text("💳")
                            .font(.system(size: 60))
                        Text("Активируйте подписку")
                            .font(DS.titleLarge)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Для продолжения работы оплатите подписку.\nПосле оплаты нажмите кнопку ниже.")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Requisites
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Реквизиты для оплаты")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                        VStack(spacing: 0) {
                            rekvRow(label: "СБП номер", value: "+7 (999) 000-00-00") // [ЗАМЕНИТЬ на реальный номер]
                            rekvRow(label: "Банк", value: "Сбербанк / Тинькофф")
                            rekvRow(label: "Получатель", value: "Арсений К.")
                            rekvRow(label: "Сумма", value: "990 ₽ / месяц")
                        }
                        .background(theme.backgroundCard)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)

                    // Buttons
                    VStack(spacing: 12) {
                        if vm.sent {
                            Text("✅ Уведомление отправлено!\nМы активируем доступ в течение нескольких часов.")
                                .font(DS.body)
                                .foregroundColor(theme.accent)
                                .multilineTextAlignment(.center)
                                .padding()
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
                                .background(theme.gradientPrimary)
                                .foregroundColor(.white)
                                .cornerRadius(14)
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

    @ViewBuilder
    private func rekvRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DS.body)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        Divider().background(theme.borderSubtle)
    }
}
