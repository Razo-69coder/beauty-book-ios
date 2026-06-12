import SwiftUI

struct SubscriptionView: View {
    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 60)

                    Text("🔒")
                        .font(.system(size: 72))

                    VStack(spacing: 8) {
                        Text("Пробный период завершён")
                            .font(DS.titleLarge)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Для продолжения работы оформите подписку")
                            .font(DS.body)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

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

                    Link(destination: URL(string: "https://t.me/razo0220")!) {
                        Text("Написать в поддержку")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theme.gradientPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)

                    Text("Telegram @razo0220")
                        .font(DS.caption)
                        .foregroundColor(theme.textSecondary.opacity(0.5))

                    Spacer(minLength: 40)
                }
            }
        }
    }
}
