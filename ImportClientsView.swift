import SwiftUI

struct ImportClientsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var csvText = ""
    @State private var isLoading = false
    @State private var result: (imported: Int, skipped: Int)? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Инструкция")
                            .font(DS.headline)
                            .foregroundColor(theme.textPrimary)
                        Text("Вставьте данные клиентов. Каждый клиент — с новой строки.\nФормат: Имя, Телефон (через запятую или точку с запятой)\n\nПример:\nАнна Иванова, +79001234567\nМария Петрова; +79009876543")
                            .font(DS.bodySmall)
                            .foregroundColor(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(theme.backgroundCard)
                    .cornerRadius(DS.r12)

                    TextEditor(text: $csvText)
                        .font(DS.body)
                        .foregroundColor(theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(theme.backgroundInput)
                        .cornerRadius(DS.r12)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.r12)
                                .stroke(theme.borderSubtle, lineWidth: 1)
                        )
                        .frame(minHeight: 200)
                        .overlay(alignment: .topLeading) {
                            if csvText.isEmpty {
                                Text("Вставьте данные клиентов...")
                                    .font(DS.body)
                                    .foregroundColor(theme.textMuted)
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                        }

                    if let result = result {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.statusGreen)
                            Text("Импортировано: \(result.imported) клиентов")
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                            if result.skipped > 0 {
                                Text("(\(result.skipped) пропущено)")
                                    .font(DS.bodySmall)
                                    .foregroundColor(theme.textMuted)
                            }
                        }
                        .padding(12)
                        .background(theme.statusGreen.opacity(0.1))
                        .cornerRadius(DS.r12)
                    }

                    if let errorMessage = errorMessage {
                        BBErrorBanner(message: errorMessage)
                            .environment(\.theme, theme)
                    }

                    Spacer()

                    BBPrimaryButton(
                        title: isLoading ? "Импортирую..." : "Импортировать",
                        isLoading: isLoading,
                        isDisabled: csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        importClients()
                    }
                    .environment(\.theme, theme)
                }
                .padding(20)
            }
            .navigationTitle("Импорт клиентов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
        }
    }

    private func importClients() {
        let text = csvText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        result = nil
        errorMessage = nil

        let lines = text.components(separatedBy: .newlines)
        var items: [ClientImportItem] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts: [String]
            if trimmed.contains(",") {
                parts = trimmed.components(separatedBy: ",")
            } else if trimmed.contains(";") {
                parts = trimmed.components(separatedBy: ";")
            } else {
                continue
            }

            guard parts.count >= 2 else { continue }

            let name = parts[0].trimmingCharacters(in: .whitespaces)
            let phone = parts[1].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !phone.isEmpty else { continue }

            items.append(ClientImportItem(name: name, phone: phone, notes: ""))
        }

        guard !items.isEmpty else {
            errorMessage = "Не удалось распознать данные. Проверьте формат."
            isLoading = false
            return
        }

        Task {
            do {
                let resp = try await APIClient.shared.importClients(items)
                await MainActor.run {
                    result = (resp.imported, resp.skipped)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Ошибка импорта: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ImportClientsView()
        .environment(\.theme, .pink)
}