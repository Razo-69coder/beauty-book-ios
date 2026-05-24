import SwiftUI
import SafariServices

// MARK: - Models
struct PaymentResponse: Decodable {
    let paymentId: String
    let confirmationUrl: String
}

struct PeriodOption {
    let label: String
    let price: String
    let totalRub: String
    let perMonth: String
    let discount: String?
    let planId: String
    let months: Int
}

let periods = [
    PeriodOption(label: "Месяц",   price: "690 ₽",   totalRub: "690 ₽",    perMonth: "690 ₽/мес",   discount: nil,   planId: "pro_1m",  months: 1),
    PeriodOption(label: "6 мес",   price: "3 490 ₽", totalRub: "3 490 ₽",  perMonth: "582 ₽/мес",  discount: "−16%", planId: "pro_6m",  months: 6),
    PeriodOption(label: "Год",     price: "5 990 ₽", totalRub: "5 990 ₽",  perMonth: "499 ₽/мес",  discount: "−28%", planId: "pro_1y",  months: 12),
    PeriodOption(label: "2 года",  price: "9 990 ₽", totalRub: "9 990 ₽",  perMonth: "416 ₽/мес",  discount: "−40%", planId: "pro_2y",  months: 24),
]

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

    func createPayment(planId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let resp: PaymentResponse = try await APIClient.shared.request(.createPayment(plan: planId), as: PaymentResponse.self)
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
    @State private var selectedPeriod: Int = 0

    private var savings: Int {
        guard selectedPeriod > 0 else { return 0 }
        let p = periods[selectedPeriod]
        let monthly = 690
        return monthly * p.months - Int(p.price.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression))!
    }

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Promo banner
                    promoBanner

                    VStack(spacing: 8) {
                        Text("💳")
                            .font(.system(size: 48))
                        Text("Подписка Solvo Beauty")
                            .font(DS.titleLarge)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                    }

                    // Period picker
                    periodPicker

                    // Price block
                    priceBlock

                    if vm.isActive {
                        VStack(spacing: 12) {
                            Text("✅ Подписка активна")
                                .font(DS.titleMedium)
                                .foregroundColor(theme.accent)
                        }
                    } else {
                        Button(action: { Task { await vm.createPayment(planId: periods[selectedPeriod].planId) } }) {
                            HStack {
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Оплатить \(periods[selectedPeriod].totalRub)")
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

    // MARK: - Promo Banner
    private var promoBanner: some View {
        VStack(spacing: 4) {
            Text("🎁 Первый месяц — бесплатно")
                .font(DS.titleSmall)
                .foregroundColor(theme.accent)
            Text("Акция при запуске — Pro без оплаты на 30 дней")
                .font(DS.caption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [theme.accent.opacity(0.15), theme.accentSecondary.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.accent.opacity(0.5), lineWidth: 0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Period Picker
    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(periods.indices, id: \.self) { i in
                let p = periods[i]
                let active = i == selectedPeriod
                VStack(spacing: 2) {
                    if let d = p.discount {
                        Text(d)
                            .font(DS.caption)
                            .foregroundColor(theme.accent)
                            .fontWeight(.semibold)
                    } else {
                        Color.clear.frame(height: 11)
                    }
                    Button(action: { selectedPeriod = i }) {
                        Text(p.label)
                            .font(DS.labelSmall)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(active ? theme.accent.opacity(0.2) : theme.backgroundCard)
                            .foregroundColor(active ? theme.accent : theme.textSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(active ? theme.accent : theme.borderSubtle, lineWidth: 1)
                            )
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Price Block
    private var priceBlock: some View {
        VStack(spacing: 4) {
            Text(periods[selectedPeriod].price)
                .font(DS.titleLarge)
                .foregroundColor(theme.textPrimary)
            Text(periods[selectedPeriod].perMonth)
                .font(DS.caption)
                .foregroundColor(theme.textSecondary)
            if selectedPeriod > 0 {
                Text("Экономия \(savings) ₽")
                    .font(DS.labelSmall)
                    .foregroundColor(theme.statusGreen)
            }
        }
    }
}
