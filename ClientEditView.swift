import SwiftUI

@MainActor
final class ClientEditViewModel: ObservableObject {
    @Published var name: String
    @Published var phone: String
    @Published var notes: String
    @Published var birthdayDate: Date
    @Published var hasBirthday: Bool
    @Published var source: String
    @Published var allergies: String
    @Published var isSaving = false
    @Published var errorMessage: String?

    let clientId: Int

    init(client: Client) {
        self.clientId = client.id
        self.name = client.name
        self.phone = client.phone
        self.notes = client.notes ?? ""
        self.source = client.source ?? ""
        self.allergies = client.allergies ?? ""
        self.hasBirthday = client.birthday != nil
        if let bday = client.birthday {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            if let date = formatter.date(from: bday) {
                var comps = Calendar.current.dateComponents([.month, .day], from: date)
                comps.year = Calendar.current.component(.year, from: Date())
                self.birthdayDate = Calendar.current.date(from: comps) ?? Date()
            } else {
                self.birthdayDate = Date()
            }
        } else {
            self.birthdayDate = Date()
        }
    }

    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        let birthdayStr: String
        if hasBirthday {
            let f = DateFormatter()
            f.dateFormat = "MM-dd"
            birthdayStr = f.string(from: birthdayDate)
        } else {
            birthdayStr = ""
        }
        let req = ClientUpdateRequest(
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            birthday: birthdayStr,
            source: source.trimmingCharacters(in: .whitespaces),
            allergies: allergies.trimmingCharacters(in: .whitespaces)
        )
        do {
            _ = try await APIClient.shared.request(.updateClient(id: clientId, req), as: EmptyResponse.self)
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}

struct ClientEditView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ClientEditViewModel
    let onSave: (Client) -> Void

    init(client: Client, onSave: @escaping (Client) -> Void) {
        self._vm = StateObject(wrappedValue: ClientEditViewModel(client: client))
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button("Отмена") { dismiss() }
                            .foregroundColor(theme.textMuted)
                        Spacer()
                        Text("Редактировать")
                            .font(DS.titleSmall)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Button {
                            Task {
                                if await vm.save() {
                                    dismiss()
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("ClientUpdated"), object: nil)
                                }
                            }
                        } label: {
                            if vm.isSaving {
                                ProgressView().tint(theme.accent)
                            } else {
                                Text("Сохранить")
                                    .foregroundColor(theme.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(vm.isSaving || vm.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if let err = vm.errorMessage {
                        Text(err)
                            .font(DS.caption)
                            .foregroundColor(theme.statusRed)
                            .padding(.horizontal, 20)
                    }

                    BBGlassCard {
                        VStack(spacing: 0) {
                            editField(title: "Имя", text: $vm.name, placeholder: "Имя клиента", icon: "person.fill")
                            Divider().background(theme.borderSubtle)
                            editField(title: "Телефон", text: $vm.phone, placeholder: "+7 (999) 000-00-00", icon: "phone.fill", keyboardType: .phonePad)
                            Divider().background(theme.borderSubtle)
                            editField(title: "Заметки", text: $vm.notes, placeholder: "Заметки", icon: "note.text")
                            Divider().background(theme.borderSubtle)
                            editField(title: "Откуда пришла", text: $vm.source, placeholder: "Instagram, ВКонтакте...", icon: "location.circle.fill")
                            Divider().background(theme.borderSubtle)
                            editField(title: "Аллергии", text: $vm.allergies, placeholder: "Аллергии и противопоказания", icon: "exclamationmark.triangle.fill")
                        }
                    }
                    .padding(.horizontal, 20)

                    BBGlassCard {
                        VStack(spacing: 12) {
                            Toggle(isOn: $vm.hasBirthday) {
                                Label("День рождения", systemImage: "gift")
                                    .foregroundColor(theme.textPrimary)
                                    .font(DS.body)
                            }
                            .tint(theme.accent)

                            if vm.hasBirthday {
                                DatePicker(
                                    "",
                                    selection: $vm.birthdayDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.graphical)
                                .accentColor(theme.accent)
                                .colorScheme(.dark)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func editField(title: String, text: Binding<String>, placeholder: String,
                           icon: String, keyboardType: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
                TextField(placeholder, text: text)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                    .keyboardType(keyboardType)
            }
            Spacer()
        }
        .padding(16)
    }
}
