import SwiftUI

struct ProWelcomeView: View {
    var onFinish: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 60)

                    Text("💅")
                        .font(.system(size: 72))

                    VStack(spacing: 8) {
                        Text("Добро пожаловать!")
                            .font(DS.titleLarge)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Solvo Beauty готов к работе")
                            .font(DS.titleMedium)
                            .foregroundColor(theme.accent)
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
