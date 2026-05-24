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

let proPeriods = [
    PeriodOption(label: "1 мес",  price: "690 ₽",    totalRub: "690 ₽",    perMonth: "690 ₽/мес",   discount: nil,     planId: "pro_1m",  months: 1),
    PeriodOption(label: "6 мес",  price: "3 490 ₽",   totalRub: "3 490 ₽",  perMonth: "582 ₽/мес",  discount: "−16%",  planId: "pro_6m",  months: 6),
    PeriodOption(label: "1 год",  price: "5 990 ₽",   totalRub: "5 990 ₽",  perMonth: "499 ₽/мес",  discount: "−28%",  planId: "pro_1y",  months: 12),
    PeriodOption(label: "2 года", price: "9 990 ₽",   totalRub: "9 990 ₽",  perMonth: "416 ₽/мес",  discount: "−40%",  planId: "pro_2y",  months: 24),
]

let bizPeriods = [
    PeriodOption(label: "1 мес",  price: "1 290 ₽",   totalRub: "1 290 ₽",    perMonth: "1 290 ₽/мес",  discount: nil,     planId: "biz_1m",  months: 1),
    PeriodOption(label: "6 мес",  price: "6 490 ₽",   totalRub: "6 490 ₽",    perMonth: "1 082 ₽/мес",  discount: "−16%",  planId: "biz_6m",  months: 6),
    PeriodOption(label: "1 год",  price: "11 200 ₽",  totalRub: "11 200 ₽",   perMonth: "933 ₽/мес",   discount: "−28%",  planId: "biz_1y",  months: 12),
    PeriodOption(label: "2 года", price: "18 900 ₽",  totalRub: "18 900 ₽",   perMonth: "788 ₽/мес",   discount: "−39%",  planId: "biz_2y",  months: 24),
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
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SubscriptionViewModel()
    @State private var proPeriod: Int = 0
    @State private var bizPeriod: Int = 0

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 32)

                    VStack(spacing: 6) {
                        Text("Выбери тариф")
                            .font(DS.titleLarge)
                            .foregroundColor(theme.textPrimary)
                        Text("Пробный период завершён")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                    }

                    freeCard
                    proCard
                    bizCard

                    if let err = vm.errorMessage {
                        Text(err)
                            .font(DS.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    if vm.isActive {
                        VStack(spacing: 12) {
                            Text("✅ Подписка активна")
                                .font(DS.titleMedium)
                                .foregroundColor(theme.accent)
                        }
                    } else {
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
                            }
                        }
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

    // MARK: - Free Card
    private var freeCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Бесплатный план")
                        .font(DS.titleMedium)
                        .foregroundColor(theme.textPrimary)
                    Text("0 ₽")
                        .font(DS.titleLarge)
                        .foregroundColor(theme.textPrimary)
                    Text("навсегда бесплатно")
                        .font(DS.caption)
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 10) {
                ForEach([
                    "Только до 10 клиентов",
                    "Без авто-напоминаний",
                    "Без онлайн-записи по ссылке",
                    "Без статистики",
                ], id: \.self) { item in
                    HStack(spacing: 10) {
                        Text("✕")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red.opacity(0.7))
                        Text(item)
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            Button(action: {
                UserDefaults.standard.set(true, forKey: "choseFreePlan")
                appState.activateSubscription()
            }) {
                Text("Остаться на бесплатном")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.clear)
                    .foregroundColor(theme.textSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.borderSubtle, lineWidth: 1)
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Pro Card
    private var proCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro")
                        .font(DS.titleMedium)
                        .foregroundColor(theme.textPrimary)
                    Text(proPeriods[proPeriod].price)
                        .font(DS.titleLarge)
                        .foregroundColor(theme.textPrimary)
                }
                Spacer()
                Text("ХИТ")
                    .font(DS.labelSmall)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.accent)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(proPeriods.indices, id: \.self) { i in
                    let p = proPeriods[i]
                    let active = i == proPeriod
                    VStack(spacing: 2) {
                        if let d = p.discount {
                            Text(d)
                                .font(DS.caption)
                                .foregroundColor(theme.accent)
                                .fontWeight(.semibold)
                        } else {
                            Color.clear.frame(height: 11)
                        }
                        Button(action: { proPeriod = i }) {
                            VStack(spacing: 2) {
                                Text(p.label)
                                    .font(DS.labelSmall)
                                Text(p.perMonth)
                                    .font(DS.caption)
                                    .opacity(0.8)
                            }
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
            .padding(.horizontal, 20)

            Button(action: { Task { await vm.createPayment(planId: proPeriods[proPeriod].planId) } }) {
                HStack {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Оплатить \(proPeriods[proPeriod].totalRub)")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.gradientPrimary)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(vm.isLoading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.accent.opacity(0.4), lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Business Card
    private var bizCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Бизнес")
                        .font(DS.titleMedium)
                        .foregroundColor(theme.textPrimary)
                    Text("Для серьёзного роста")
                        .font(DS.caption)
                        .foregroundColor(theme.textSecondary)
                    Text(bizPeriods[bizPeriod].price)
                        .font(DS.titleLarge)
                        .foregroundColor(theme.textPrimary)
                        .padding(.top, 4)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 10) {
                ForEach([
                    "Всё из тарифа Pro",
                    "Личная настройка от разработчика (30 мин)",
                    "Приоритетная поддержка (ответ за 1 час)",
                    "Ранний доступ к новым функциям",
                ], id: \.self) { item in
                    HStack(spacing: 10) {
                        Text("◆")
                            .foregroundColor(theme.accent)
                        Text(item)
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(bizPeriods.indices, id: \.self) { i in
                    let p = bizPeriods[i]
                    let active = i == bizPeriod
                    VStack(spacing: 2) {
                        if let d = p.discount {
                            Text(d)
                                .font(DS.caption)
                                .foregroundColor(theme.accent)
                                .fontWeight(.semibold)
                        } else {
                            Color.clear.frame(height: 11)
                        }
                        Button(action: { bizPeriod = i }) {
                            VStack(spacing: 2) {
                                Text(p.label)
                                    .font(DS.labelSmall)
                                Text(p.perMonth)
                                    .font(DS.caption)
                                    .opacity(0.8)
                            }
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
            .padding(.horizontal, 20)

            Button(action: { Task { await vm.createPayment(planId: bizPeriods[bizPeriod].planId) } }) {
                HStack {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Оплатить \(bizPeriods[bizPeriod].totalRub)")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.accent.opacity(0.1))
                .foregroundColor(theme.accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.accent, lineWidth: 1)
                )
                .cornerRadius(14)
            }
            .disabled(vm.isLoading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(theme.backgroundCard)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}
