import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = OnboardingViewModel()
    @State private var currentStep = 0
    let onFinish: () -> Void

    private let totalSteps = 11

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Content
                TabView(selection: $currentStep) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        stepView(for: step)
                            .tag(step)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(DS.springSnappy, value: currentStep)

                // Bottom button
                bottomButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? theme.accent : theme.backgroundInput)
                    .frame(height: 4)
                    .animation(DS.springSnappy, value: currentStep)
            }
        }
    }

    // MARK: - Step Views
    @ViewBuilder
    private func stepView(for step: Int) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 100, height: 100)
                    .shadow(color: theme.accentGlow, radius: 30)
                Image(systemName: iconName(for: step))
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(.white)
            }

            // Text
            VStack(spacing: 12) {
                Text(title(for: step))
                    .font(DS.titleMedium)
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle(for: step))
                    .font(DS.body)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Input fields (if any)
            inputView(for: step)

            // Badge (if any)
            badgeView(for: step)

            Spacer()
        }
    }

    // MARK: - Input Views
    @ViewBuilder
    private func inputView(for step: Int) -> some View {
        switch step {
        case 1:
            BBTextField(placeholder: "Твоё имя", text: $vm.masterName)
                .environment(\.theme, theme)
        case 7:
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Начало")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                        Picker("", selection: $vm.workStart) {
                            ForEach(6..<22) { h in
                                Text("\(h):00").tag(h)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .tint(theme.accent)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Конец")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textMuted)
                        Picker("", selection: $vm.workEnd) {
                            ForEach(8..<24) { h in
                                Text("\(h):00").tag(h)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .tint(theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Слот")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                    Picker("", selection: $vm.slotDuration) {
                        Text("30 мин").tag(30)
                        Text("45 мин").tag(45)
                        Text("60 мин").tag(60)
                        Text("90 мин").tag(90)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .tint(theme.accent)
                }
            }
            .padding(16)
            .background(theme.backgroundInput)
            .cornerRadius(DS.r12)
        case 8:
            VStack(spacing: 12) {
                BBTextField(placeholder: "Название услуги", text: $vm.serviceName)
                    .environment(\.theme, theme)
                BBTextField(placeholder: "Цена, ₽", text: $vm.servicePrice)
                    .keyboardType(.numberPad)
                    .environment(\.theme, theme)
            }
        case 9:
            VStack(spacing: 8) {
                HStack {
                    Text("beautybook.app/")
                        .font(DS.body)
                        .foregroundColor(theme.textMuted)
                    TextField("твой-slug", text: $vm.bookingSlug)
                        .font(DS.body)
                        .foregroundColor(theme.textPrimary)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(theme.backgroundInput)
                .cornerRadius(DS.r12)

                if !vm.bookingSlug.isEmpty {
                    Text("beautybook.app/\(vm.bookingSlug)")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Badge Views
    @ViewBuilder
    private func badgeView(for step: Int) -> some View {
        switch step {
        case 2:
            badge(text: "✦ Автонапоминания клиентам")
        case 3:
            badge(text: "✦ Онлайн-запись 24/7")
        case 4:
            badge(text: "✦ Напоминания за 2 часа")
        case 5:
            badge(text: "✦ Нерабочие дни")
        case 6:
            badge(text: "✦ Аналитика и статистика")
        default:
            EmptyView()
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(DS.caption)
            .foregroundColor(theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.accent.opacity(0.15))
            .cornerRadius(20)
    }

    // MARK: - Bottom Button
    private var bottomButton: some View {
        Group {
            if currentStep < totalSteps - 1 {
                BBPrimaryButton(
                    title: "Далее →",
                    isDisabled: !canProceed
                ) {
                    withAnimation(DS.springSnappy) {
                        currentStep += 1
                    }
                }
                .environment(\.theme, theme)
            } else {
                BBPrimaryButton(
                    title: vm.isSaving ? "Сохранение..." : "Начать работу",
                    isLoading: vm.isSaving
                ) {
                    Task {
                        await vm.finish()
                        onFinish()
                    }
                }
                .environment(\.theme, theme)
            }
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 1: return !vm.masterName.isEmpty
        case 8: return !vm.serviceName.isEmpty
        case 9: return !vm.bookingSlug.isEmpty
        default: return true
        }
    }

    // MARK: - Step Data
    private func iconName(for step: Int) -> String {
        switch step {
        case 0: return "sparkles"
        case 1: return "person.fill"
        case 2: return "person.2.slash"
        case 3: return "message.badge.fill"
        case 4: return "bell.badge.fill"
        case 5: return "calendar.badge.checkmark"
        case 6: return "chart.bar.fill"
        case 7: return "clock.fill"
        case 8: return "scissors"
        case 9: return "link"
        case 10: return "checkmark.seal.fill"
        default: return "sparkles"
        }
    }

    private func title(for step: Int) -> String {
        switch step {
        case 0: return "Добро пожаловать в Solva Beauty"
        case 1: return "Как тебя зовут?"
        case 2: return "Клиенты уходят и не возвращаются"
        case 3: return "Хватит принимать записи в мессенджерах"
        case 4: return "Клиент забыл — ты потеряла час"
        case 5: return "Ты сама решаешь когда работаешь"
        case 6: return "Деньги есть, а сколько — непонятно"
        case 7: return "Когда ты работаешь?"
        case 8: return "Добавь первую услугу"
        case 9: return "Ссылка для твоих клиентов"
        case 10: return "Solva Beauty готов к работе!"
        default: return ""
        }
    }

    private func subtitle(for step: Int) -> String {
        switch step {
        case 0: return "Твой личный администратор, который никогда не спит и ничего не забывает"
        case 1: return "Будем обращаться к тебе по имени"
        case 2: return "Не потому что ушли навсегда — просто никто не напомнил. Solva Beauty автоматически пишет клиентам когда они давно не приходили"
        case 3: return "«А когда есть время?» — и так 20 раз в день. Отправь клиенту ссылку — он сам выберет удобное время"
        case 4: return "Solva Beauty отправляет напоминание за 2 часа до записи. Клиенты приходят вовремя"
        case 5: return "Отпуск, выходной, праздник — поставь нерабочие дни и клиенты не смогут записаться на эти даты"
        case 6: return "Вся статистика в одном месте: выручка за месяц, топ услуги, средний чек. Понимай свой бизнес"
        case 7: return "Можно изменить в любой момент в Настройках"
        case 8: return "Клиенты будут выбирать её при онлайн-записи"
        case 9: return "Отправь эту ссылку — клиент сам запишется без звонков"
        case 10: return "Твой профиль настроен. Добавляй клиентов, принимай записи и зарабатывай больше"
        default: return ""
        }
    }
}

// MARK: - OnboardingViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var masterName = ""
    @Published var workStart = 9
    @Published var workEnd = 20
    @Published var slotDuration = 60
    @Published var serviceName = ""
    @Published var servicePrice = ""
    @Published var bookingSlug = ""
    @Published var isSaving = false

    private let api = APIClient.shared

    func finish() async {
        isSaving = true
        // 1. Save name + schedule
        let settings = MasterSettingsRequest(
            name: masterName,
            workStart: workStart,
            workEnd: workEnd,
            slotDuration: slotDuration,
            reminderDays: 1,
            timezone: "Europe/Moscow"
        )
        _ = try? await api.request(.updateSettings(settings), as: MasterProfile.self)

        // 2. Save first service if filled
        if !serviceName.isEmpty {
            let price = Int(servicePrice) ?? 0
            let req = ServiceCreateRequest(
                name: serviceName,
                priceDefault: price,
                durationMin: slotDuration,
                category: "Основные"
            )
            _ = try? await api.request(.createService(req), as: Service.self)
        }

        // 3. Save booking link if filled
        if !bookingSlug.isEmpty {
            _ = try? await api.request(.updateBookingLink(bookingSlug), as: BookingLinkResponse.self)
        }

        isSaving = false
    }
}
