import SwiftUI

// MARK: - Форматирование даты для похожих карточек

private enum SCFormat {
    /// «2026-09-24» → «24 сен»
    static func dayMonth(_ raw: String?) -> String? {
        guard let raw = raw else { return nil }
        let trimmed: String = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 10 else { return nil }
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.locale = Locale(identifier: "en_US_POSIX")
        guard let date: Date = iso.date(from: String(trimmed.prefix(10))) else { return nil }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "d MMM"
        return out.string(from: date)
    }
}

// MARK: - Лист «Похожие карточки»

/// Показывает группы карточек, которые могут быть одной клиенткой,
/// и позволяет объединить их или отметить как разных людей
struct SCSimilarSheet: View {
    @ObservedObject var vm: ClientsViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// Группа → id карточки, которую оставляем
    @State private var keepIds: [Int: Int] = [:]
    /// Группа → номер, который оставляем после объединения
    @State private var phones: [Int: String] = [:]
    /// Группа, с которой сейчас идёт запрос
    @State private var busyGroupId: Int? = nil
    @State private var errorMessage: String? = nil
    /// Группа, для которой показано подтверждение объединения
    @State private var pendingMerge: SCGroup? = nil

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                Divider().background(theme.borderSubtle)

                if vm.similarGroups.isEmpty {
                    emptyState
                } else {
                    groupsContent
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .confirmationDialog(
            "Объединить карточки?",
            isPresented: Binding(
                get: { pendingMerge != nil },
                set: { if !$0 { pendingMerge = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Объединить", role: .destructive) {
                guard let group: SCGroup = pendingMerge else { return }
                pendingMerge = nil
                Task { await merge(group) }
            }
            Button("Отмена", role: .cancel) {
                pendingMerge = nil
            }
        } message: {
            if let group: SCGroup = pendingMerge {
                Text("Визиты перенесутся в «\(keepName(group))». Отменить нельзя.")
            }
        }
    }

    // MARK: - Шапка

    private var sheetHeader: some View {
        HStack {
            Text("Похожие карточки")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(theme.backgroundInput, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(CLPressStyle(scale: 0.9))
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Список групп

    private var groupsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Объедините дубли — визиты сложатся в одну карточку, и скидка за постоянство посчитается правильно.")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage = errorMessage {
                    BBErrorBanner(message: errorMessage)
                        .environment(\.theme, theme)
                }

                ForEach(vm.similarGroups) { group in
                    groupCard(group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Карточка группы

    private func groupCard(_ group: SCGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.reason)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.accent)

            VStack(spacing: 8) {
                ForEach(group.clients) { client in
                    clientRow(client, group: group)
                }
            }

            if phoneChoices(group).count > 1 {
                phoneBlock(group)
            }

            BBPrimaryButton(
                title: "Объединить",
                isLoading: busyGroupId == group.id,
                isDisabled: busyGroupId != nil
            ) {
                pendingMerge = group
            }
            .environment(\.theme, theme)

            BBSecondaryButton(title: "Это разные люди") {
                Task { await dismissGroup(group) }
            }
            .environment(\.theme, theme)
        }
        .padding(14)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    /// Строка карточки: выбираем, какую оставить
    private func clientRow(_ client: SCClient, group: SCGroup) -> some View {
        let isKeep: Bool = keepId(group) == client.id
        return Button {
            HapticManager.selection()
            keepIds[group.id] = client.id
            // Номер по умолчанию — из выбранной карточки
            if let phone: String = client.phone { phones[group.id] = phone }
        } label: {
            HStack(spacing: 10) {
                SCRadioMark(isSelected: isKeep, theme: theme)

                CLAvatar(
                    name: client.name,
                    size: 40,
                    dotSize: 11,
                    hasTelegram: client.hasTelegram == true,
                    theme: theme
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(client.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        if client.hasTelegram == true {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#2AABEE"))
                        }
                    }

                    HStack(spacing: 6) {
                        if let phone: String = client.phone, !phone.isEmpty {
                            Text(phone)
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        if client.placeholderPhone == true {
                            CLTag(text: "ненастоящий номер", color: theme.textMuted)
                        }
                        Spacer(minLength: 0)
                    }

                    Text(visitsLabel(client))
                        .font(.system(size: 12))
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 64)
            .background(
                isKeep ? theme.accent.opacity(0.10) : theme.backgroundInput,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isKeep ? theme.accent : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(CLPressStyle(scale: 0.99))
    }

    private func visitsLabel(_ client: SCClient) -> String {
        let count: Int = client.visits ?? 0
        let visits: String = "визитов: \(count)"
        guard let day: String = SCFormat.dayMonth(client.lastVisit) else { return visits }
        return visits + " · была " + day
    }

    // MARK: - Выбор номера

    private func phoneBlock(_ group: SCGroup) -> some View {
        let choices: [String] = phoneChoices(group)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Какой номер оставить?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(spacing: 6) {
                ForEach(choices, id: \.self) { phone in
                    phoneRow(phone, group: group)
                }
            }
        }
    }

    private func phoneRow(_ phone: String, group: SCGroup) -> some View {
        let isSelected: Bool = currentPhone(group) == phone
        return Button {
            HapticManager.selection()
            phones[group.id] = phone
        } label: {
            HStack(spacing: 10) {
                SCRadioMark(isSelected: isSelected, theme: theme)
                Text(phone)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .frame(minHeight: 48)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(CLPressStyle(scale: 0.99))
    }

    /// Настоящие номера группы, разные — из них и выбираем
    private func phoneChoices(_ group: SCGroup) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for client in group.clients where client.placeholderPhone != true {
            guard let phone: String = client.phone, !phone.isEmpty else { continue }
            if seen.insert(phone).inserted { result.append(phone) }
        }
        return result
    }

    // MARK: - Пустое состояние

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(theme.statusGreen)
            Text("Дублей нет ✨")
                .font(DS.titleSmall)
                .foregroundColor(theme.textPrimary)
            Text("Все клиентки разные — объединять нечего.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)

            BBPrimaryButton(title: "Готово") { dismiss() }
                .environment(\.theme, theme)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Действия

    /// Какую карточку оставляем: выбранную, иначе подсказку сервера
    private func keepId(_ group: SCGroup) -> Int {
        if let chosen: Int = keepIds[group.id] { return chosen }
        if group.clients.contains(where: { $0.id == group.suggestedKeepId }) {
            return group.suggestedKeepId
        }
        return group.clients.first?.id ?? group.suggestedKeepId
    }

    private func keepName(_ group: SCGroup) -> String {
        let id: Int = keepId(group)
        return group.clients.first { $0.id == id }?.name ?? ""
    }

    /// Номер, который уйдёт на сервер: выбранный, иначе номер выбранной карточки
    private func currentPhone(_ group: SCGroup) -> String {
        if let chosen: String = phones[group.id] { return chosen }
        let id: Int = keepId(group)
        if let phone: String = group.clients.first(where: { $0.id == id })?.phone {
            return phone
        }
        return group.clients.compactMap { $0.phone }.first ?? ""
    }

    private func removeGroup(_ group: SCGroup) {
        vm.similarGroups.removeAll { $0.id == group.id }
        keepIds[group.id] = nil
        phones[group.id] = nil
    }

    private func merge(_ group: SCGroup) async {
        let keep: Int = keepId(group)
        let others: [Int] = group.clients.filter { $0.id != keep }.map { $0.id }
        guard !others.isEmpty else { return }

        let api = APIClient.shared
        let payload = SCMergeRequest(otherIds: others, phone: currentPhone(group))
        busyGroupId = group.id
        errorMessage = nil
        do {
            _ = try await api.mergeClients(keepId: keep, payload)
            HapticManager.success()
            removeGroup(group)
        } catch {
            HapticManager.error()
            errorMessage = bcErrorText(error)
        }
        busyGroupId = nil
    }

    private func dismissGroup(_ group: SCGroup) async {
        let api = APIClient.shared
        busyGroupId = group.id
        errorMessage = nil
        do {
            _ = try await api.dismissSimilar(SCDismissRequest(ids: group.clients.map { $0.id }))
            HapticManager.light()
            removeGroup(group)
        } catch {
            HapticManager.error()
            errorMessage = bcErrorText(error)
        }
        busyGroupId = nil
    }
}

// MARK: - Радио-кружок 44×44

private struct SCRadioMark: View {
    let isSelected: Bool
    let theme: AppTheme

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? theme.accent : theme.borderSubtle, lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}