import SwiftUI

struct ReminderTemplatesView: View {
    @StateObject private var vm = ReminderTemplatesViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    templateCard(type: "24h", label: "За 24 часа до записи", placeholder: "🔔 Напоминание о записи\n\nЗавтра, {date} в {time}\n📋 {procedure}\n\nЖдём вас!")
                    templateCard(type: "2h", label: "За 2 часа до записи", placeholder: "⏰ Через 2 часа запись!\n\n📅 {date} в {time}\n📋 {procedure}\n\nНе забудьте!")
                    templateCard(type: "birthday", label: "День рождения клиента", placeholder: "🎂 С днём рождения, {name}!\n\nСкидка ждёт вас 💅")
                    templateCard(type: "return", label: "Возврат клиента", placeholder: "💅 {name}, давно не виделись!\n\nЗапишитесь на удобное время 🗓")
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

    private func templateCard(type: String, label: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(DS.bodySmall)
                .foregroundColor(theme.textMuted)
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

            if vm.templates[type, default: ""].isEmpty {
                Text("Будет использован шаблон по умолчанию")
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
            }

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
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(DS.r16)
        .overlay(RoundedRectangle(cornerRadius: DS.r16).stroke(theme.borderSubtle, lineWidth: 1))
    }
}

@MainActor
final class ReminderTemplatesViewModel: ObservableObject {
    @Published var templates: [String: String] = [:]
    @Published var isLoading = false

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        if let resp = try? await api.request(.getReminderTemplates, as: ReminderTemplatesResponse.self) {
            for t in resp.templates {
                templates[t.type] = t.template
            }
        }
        isLoading = false
    }

    func save(type: String) async {
        let template = templates[type, default: ""]
        _ = try? await api.request(.updateReminderTemplate(type: type, template: template), as: MessageResponse.self)
    }
}
