import SwiftUI

struct ProWelcomeView: View {
    var onFinish: () -> Void
    @Environment(\.theme) var theme
    let trialEndDate: Date

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: trialEndDate)
    }

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 60)

                    Text("🎁")
                        .font(.system(size: 72))

                    VStack(spacing: 8) {
                        Text("Pro активирован")
                            .font(DS.titleLarge)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("на 30 дней бесплатно")
                            .font(DS.titleMedium)
                            .foregroundColor(theme.accent)
                    }

                    Text("Действует до \(formattedDate)")
                        .font(DS.caption)
                        .foregroundColor(theme.textSecondary)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach([
                            ("📅", "Расписание без ограничений"),
                            ("👥", "База клиентов"),
                            ("🔔", "Авто-напоминания клиентам"),
                            ("🔗", "Онлайн-запись по ссылке"),
                            ("📊", "Статистика и аналитика"),
                        ], id: \.1) { icon, text in
                            HStack(spacing: 12) {
                                Text(icon).font(.system(size: 20))
                                Text(text)
                                    .font(DS.body)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 40)

                    Text("За 2 дня до окончания придёт напоминание,\nесли захотите продолжить")
                        .font(DS.caption)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(theme.accent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.accent.opacity(0.25), lineWidth: 0.5)
                        )
                        .cornerRadius(10)
                        .padding(.horizontal, 24)

                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "hasSeenProWelcome")
                        onFinish()
                    }) {
                        Text("Начать работу")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theme.gradientPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
    }
}
