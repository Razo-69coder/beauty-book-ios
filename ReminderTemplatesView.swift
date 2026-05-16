import SwiftUI

struct ReminderTemplatesView: View {
    @StateObject private var vm = ReminderTemplatesViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private let types: [(key: String, label: String, placeholder: String)] = [
        ("24h", "За 24 часа до записи", "🔔 Напоминание о записи\n\nЗавтра, {date} в {time}\n📋 {procedure}\n\nЖдём вас!"),
        ("2h", "За 2 часа до записи", "⏰ Через 2 часа запись!\n\n📅 {date} в {time}\n📋 {procedure}\n\nНе забудьте!"),
        ("birthday", "День рождения клиента", "🎂 С днём рождения, {name}!\n\nСкидка ждёт вас 💅"),
        ("return", "Возврат клиента", "💅 {name}, давно не виделись!\n\nЗапишитесь на удобное время 🗓"),
        ("correction", "Напоминание о коррекции", "💅 Привет, {name}!\n\nПора на коррекцию!"),
        ("review", "Запрос отзыва", "💅 {name}, как прошёл визит?\n\nОцените процедуру «{procedure}»:"),
        ("payment_24h", "Оплата за 24 часа", "⚠️ Напоминание об оплате\n\nЗавтра запись.\n\nНужна предоплата {deposit_pct}%."),
        ("payment_2h", "Оплата через 2 часа", "💳 Напоминание об оплате\n\nВы записаны на {date}.\n\nВнесите предоплату {deposit_pct}%."),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(types, id: \.key) { item in
                        templateCard(type: item.key, label: item.label, placeholder: item.placeholder)
                    }
                }
                .padding(20)
            }
            .background(theme.backgroundDeep)
            .navigationTitle("Шаблоны напоминаний")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
        }
        .task { await vm.load() }
    }

    static let defaultTemplates: [String: String] = [
        "24h": "🔔 Напоминание о записи\n\nЗавтра, 15.05.2026 в 14:30\n📋 Маникюр\n\nЖдём вас!",
        "2h": "⏰ Через 2 часа ваша запись!\n\n📅 15.05.2026 в 14:30\n📋 Маникюр\n\nНе забудьте!",
        "birthday": "🎂 С днём рождения, Анна!\n\nМастер Елена поздравляет вас! 🎉\n\n🎁 Скидка 10% на следующий визит!",
        "return": "🏆 Анна, вы у нас уже 5 раз!\n\nВы заработали скидку 10% на следующий визит 🎉",
        "correction": "💅 Привет, Анна!\n\nПрошло 3 недели после визита — самое время на коррекцию!\n\nЗапишитесь к мастеру Елена заранее 🗓",
        "review": "💅 Анна, как прошёл визит?\n\nОцените процедуру «Маникюр»:",
        "payment_24h": "⚠️ Напоминание об оплате\n\nЗавтра, 15.05.2026 в 14:30 у вас запись.\n\nНеобходима предоплата 30%.",
        "payment_2h": "💳 Напоминание об оплате\n\nВы записаны на 15.05.2026 в 14:30.\n\nВнесите предоплату 30% для подтверждения записи ✅",
    ]

    private static let variableHints: [String: String] = [
        "24h": "{name}, {date}, {time}, {procedure}",
        "2h": "{name}, {date}, {time}, {procedure}",
        "birthday": "{name}, {master_name}, {discount_percent}",
        "return": "{name}, {visit_count}, {discount_percent}",
        "correction": "{name}, {master_name}",
        "review": "{name}, {procedure}",
        "payment_24h": "{name}, {date}, {time}, {deposit_pct}",
        "payment_2h": "{name}, {date}, {time}, {deposit_pct}",
    ]

    private func templateCard(type: String, label: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { vm.enabled[type, default: true] },
                set: { vm.enabled[type] = $0 }
            )) {
                Text(label)
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textMuted)
            }
            .tint(theme.accent)

            if vm.enabled[type, default: true] {
                TextEditor(text: Binding(
                    get: { vm.templates[type, default: ""] },
                    set: { vm.templates[type] = $0 }
                ))
                    .font(DS.body)
                    .colorScheme(theme == .platinum ? .light : .dark)
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(theme.backgroundInput)
                    .cornerRadius(DS.r12)
                    .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.borderSubtle, lineWidth: 1))

                Text("Переменные: \(Self.variableHints[type] ?? "")")
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted.opacity(0.6))

                Button {
                    Task { await vm.save(type: type) }
                } label: {
                    Text("Сохранить")
                        .font(DS.label)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.gradientPrimary)
                        .cornerRadius(DS.r12)
                }
            }
        }
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r16)
        .overlay(RoundedRectangle(cornerRadius: DS.r16).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

@MainActor
final class ReminderTemplatesViewModel: ObservableObject {
    @Published var templates: [String: String] = [:]
    @Published var enabled: [String: Bool] = [:]
    @Published var isLoading = false

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        let defaults = ReminderTemplatesView.defaultTemplates
        if let resp = try? await api.request(.getReminderTemplates, as: ReminderTemplatesResponse.self) {
            for t in resp.templates {
                templates[t.type] = t.template.isEmpty ? defaults[t.type] ?? "" : t.template
                enabled[t.type] = t.enabled
            }
        } else {
            for (key, value) in defaults {
                templates[key] = value
                enabled[key] = true
            }
        }
        isLoading = false
    }

    func save(type: String) async {
        let template = templates[type, default: ""]
        let isEnabled = enabled[type, default: true]
        _ = try? await api.request(
            .updateReminderTemplate(type: type, template: template, enabled: isEnabled),
            as: MessageResponse.self
        )
    }
}
