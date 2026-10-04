import SwiftUI
import UniformTypeIdentifiers

struct ImportClientsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    // Режим экрана: 0 — из файла, 1 — вставить текстом
    @State private var mode: Int = 0
    @State private var isLoading = false
    @State private var result: (imported: Int, skipped: Int)? = nil
    @State private var errorMessage: String? = nil

    // Режим «Вставить текстом» — без изменений
    @State private var csvText = ""

    // Режим «Из файла»
    @State private var isFileImporterPresented = false
    @State private var fileName: String? = nil
    @State private var rows: [CIFileRow] = []
    @State private var invalidCount: Int = 0
    @State private var isParsing = false
    @State private var deselected: Set<String> = []

    /// Строка без телефона не импортируется — её нельзя выбрать
    private func isSelectable(_ row: CIFileRow) -> Bool {
        return !row.phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var selectableRows: [CIFileRow] {
        rows.filter { isSelectable($0) }
    }

    private var isPrepared: Bool { !rows.isEmpty }

    private var selectedRows: [CIFileRow] {
        selectableRows.filter { !deselected.contains($0.id) }
    }

    /// Уже есть в базе — считаем по всем разобранным строкам
    private var alreadyExistsCount: Int {
        rows.filter { $0.exists == true }.count
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()

                VStack(spacing: 16) {
                    CISegment(mode: mode) { newMode in
                        guard newMode != mode else { return }
                        HapticManager.selection()
                        errorMessage = nil
                        result = nil
                        mode = newMode
                    }

                    if mode == 0 {
                        fileMode
                    } else {
                        textMode
                    }
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
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: ciAllowedTypes,
                allowsMultipleSelection: false
            ) { outcome in
                switch outcome {
                case .success(let urls):
                    guard let url: URL = urls.first else { return }
                    handlePickedFile(url)
                case .failure(let error):
                    guard (error as NSError).code != NSUserCancelledError else { return }
                    HapticManager.error()
                    errorMessage = bcErrorText(error)
                }
            }
        }
    }

    // MARK: - Режим «Из файла»

    private var fileMode: some View {
        VStack(spacing: 14) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    fileHint

                    if isParsing {
                        parsingCard
                    } else if isPrepared {
                        preview
                    } else if let fileName {
                        pickedCard(fileName)
                    } else {
                        emptyCard
                    }

                    if let errorMessage {
                        BBErrorBanner(message: errorMessage)
                            .environment(\.theme, theme)
                    }

                    if let result {
                        resultCard(result)
                    }
                }
            }

            Spacer(minLength: 0)

            if isPrepared {
                BBPrimaryButton(
                    title: "Импортировать \(selectedRows.count)",
                    isLoading: isLoading,
                    isDisabled: selectedRows.isEmpty || isLoading
                ) {
                    importFromFile()
                }
                .environment(\.theme, theme)
            } else if !isParsing {
                BBPrimaryButton(
                    title: "Выбрать файл",
                    isDisabled: isLoading
                ) {
                    errorMessage = nil
                    isFileImporterPresented = true
                }
                .environment(\.theme, theme)
            }
        }
    }

    private var fileHint: some View {
        Text("Выгрузите базу из YCLIENTS, DIKIDI или таблицы в Excel (.xlsx) или CSV. Нужны столбцы «Имя» и «Телефон»; «Дата рождения» и «Комментарий» — по желанию.")
            .font(.system(size: 14))
            .foregroundColor(theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: DS.r12))
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.accent.opacity(0.14))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "tablecells")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(theme.accent)
                }
            Text("Файл не выбран")
                .font(DS.headline)
                .foregroundColor(theme.textPrimary)
            Text("Мы прочитаем файл и покажем, сколько клиенток найдено. Ничего не сохранится, пока вы не нажмёте «Импортировать».")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 14)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private var parsingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
            Text("Читаем файл…")
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
            if let fileName {
                Text(fileName)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private func pickedCard(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    Text("Нажмите, чтобы выбрать другой файл")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textMuted)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textMuted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())

            Button {
                errorMessage = nil
                isFileImporterPresented = true
            } label: {
                Text("Выбрать другой файл")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(CLPressStyle(scale: 0.98))
        }
        .padding(14)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Найдено: \(rows.count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text(subtitleText)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    HapticManager.selection()
                    deselected.removeAll()
                } label: {
                    Text("Выбрать все")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(CLPressStyle(scale: 0.98))
                .disabled(deselected.isEmpty)

                Button {
                    HapticManager.selection()
                    deselected = Set(selectableRows.map { $0.id })
                } label: {
                    Text("Снять все")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(CLPressStyle(scale: 0.98))
                .disabled(deselected.count >= selectableRows.count)
            }

            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    CIRow(
                        row: row,
                        theme: theme,
                        isSelected: !deselected.contains(row.id),
                        isEnabled: isSelectable(row),
                        onToggle: { toggle(row) }
                    )
                    if index < rows.count - 1 {
                        Divider()
                            .background(theme.borderSubtle)
                    }
                }
            }
            .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var subtitleText: String {
        let parts: [String] = [
            "Уже есть в базе: \(alreadyExistsCount)",
            "Без имени или телефона: \(invalidCount)"
        ]
        return parts.joined(separator: " · ")
    }

    // MARK: - Режим «Вставить текстом»

    private var textMode: some View {
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

            if let errorMessage {
                BBErrorBanner(message: errorMessage)
                    .environment(\.theme, theme)
            }

            Spacer()

            BBPrimaryButton(
                title: isLoading ? "Импортирую..." : "Импортировать",
                isLoading: isLoading,
                isDisabled: csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                importText()
            }
            .environment(\.theme, theme)
        }
    }

    private func resultCard(_ result: (imported: Int, skipped: Int)) -> some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.statusGreen.opacity(0.1))
        .cornerRadius(DS.r12)
    }

    // MARK: - Файл

    /// Excel и CSV: системные типы плюс явные расширения
    private var ciAllowedTypes: [UTType] {
        var types: [UTType] = [.spreadsheet, .commaSeparatedText, .plainText]
        if let xlsx: UTType = UTType(filenameExtension: "xlsx") {
            types.append(xlsx)
        }
        if let csv: UTType = UTType(filenameExtension: "csv") {
            types.append(csv)
        }
        return types
    }

    private func handlePickedFile(_ url: URL) {
        HapticManager.selection()
        let name: String = url.lastPathComponent
        let scoped: Bool = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let bytes: Data
        do {
            bytes = try Data(contentsOf: url)
        } catch {
            HapticManager.error()
            errorMessage = bcErrorText(error)
            return
        }

        guard !APIClient.CIFileIsTooLarge(byteCount: bytes.count) else {
            HapticManager.error()
            errorMessage = "Файл больше 5 МБ"
            return
        }

        fileName = name
        rows = []
        deselected = []
        result = nil
        errorMessage = nil
        isParsing = true

        Task { @MainActor in
            do {
                let parsed: CIFileParseResponse = try await APIClient.shared.CIUploadClientsFile(
                    data: bytes,
                    filename: name
                )
                // Одна и та же клиентка не должна попасть в список дважды
                var seen: Set<String> = []
                let unique: [CIFileRow] = parsed.clients.filter { row in
                    guard !row.id.isEmpty else { return false }
                    return seen.insert(row.id).inserted
                }
                rows = unique
                invalidCount = parsed.invalid ?? 0
                // По умолчанию отмечаем тех, кого ещё нет в базе
                deselected = Set(unique.filter { $0.exists == true }.map { $0.id })
                isParsing = false
                if unique.isEmpty {
                    HapticManager.warning()
                    errorMessage = (parsed.invalid ?? 0) > 0
                        ? "В файле нет подходящих строк"
                        : "Файл пустой"
                }
            } catch {
                isParsing = false
                HapticManager.error()
                errorMessage = bcErrorText(error)
            }
        }
    }

    private func toggle(_ row: CIFileRow) {
        guard isSelectable(row) else { return }
        HapticManager.selection()
        if deselected.contains(row.id) {
            deselected.remove(row.id)
        } else {
            deselected.insert(row.id)
        }
    }

    // MARK: - Импорт

    private func importFromFile() {
        let chosen: [CIFileRow] = selectedRows
        guard !chosen.isEmpty, !isLoading else { return }

        isLoading = true
        result = nil
        errorMessage = nil

        let items: [ClientImportItem] = chosen.map { row in
            ClientImportItem(
                name: row.name,
                phone: row.phone,
                notes: row.notes ?? "",
                birthday: row.birthday ?? ""
            )
        }

        Task { @MainActor in
            do {
                let resp: ClientImportResponse = try await APIClient.shared.importClients(items)
                result = (resp.imported, resp.skipped)
                rows = []
                fileName = nil
                deselected = []
                HapticManager.success()
            } catch {
                HapticManager.error()
                errorMessage = bcErrorText(error)
            }
            isLoading = false
        }
    }

    private func importText() {
        let text: String = csvText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isLoading = true
        result = nil
        errorMessage = nil

        let lines: [String] = text.components(separatedBy: .newlines)
        var items: [ClientImportItem] = []

        for line in lines {
            let trimmed: String = line.trimmingCharacters(in: .whitespaces)
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

            let name: String = parts[0].trimmingCharacters(in: .whitespaces)
            let phone: String = parts[1].trimmingCharacters(in: .whitespaces)
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
                    HapticManager.success()
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

// MARK: - Переключатель режима

/// Две капсулы с переезжающей подложкой, как в настройках
struct CISegment: View {
    let mode: Int
    let onPick: (Int) -> Void

    @Namespace private var ns
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            segmentItem(0, title: "Из файла")
            segmentItem(1, title: "Вставить текстом")
        }
        .padding(3)
        .background(theme.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(reduceMotion ? nil : DS.springSnappy, value: mode)
    }

    private func segmentItem(_ index: Int, title: String) -> some View {
        let isSelected: Bool = mode == index
        return Button {
            onPick(index)
        } label: {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(theme.backgroundCard)
                            .shadow(color: theme.accentGlow.opacity(0.25), radius: 6, y: 2)
                            .matchedGeometryEffect(id: "ci.segment", in: ns)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Строка предпросмотра

/// Одна клиентка из файла: галочка выбора, имя, телефон, метка «уже есть»
struct CIRow: View {
    let row: CIFileRow
    let theme: AppTheme
    let isSelected: Bool
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onToggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(isSelected ? theme.accent : Color.clear)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.backgroundDeep)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(CLPressStyle(scale: 0.9))
            .disabled(!isEnabled)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name.isEmpty ? "Без имени" : row.name)
                    .font(.system(size: 15))
                    .foregroundColor(isEnabled ? theme.textPrimary : theme.textMuted)
                    .lineLimit(1)
                Text(row.phone.isEmpty ? "Без телефона" : row.phone)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
                if let notes: String = row.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if row.exists == true {
                Text("уже есть")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.statusYellow)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(theme.statusYellow.opacity(0.14), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

#Preview {
    ImportClientsView()
        .environment(\.theme, .pink)
}