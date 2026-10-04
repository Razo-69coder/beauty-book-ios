import SwiftUI

// MARK: - Данные экрана

/// Сервер не примет длинные правила и адрес — режем на устройстве
enum WSLimits {
    static let rules: Int = 500
    static let address: Int = 150
}

/// Настройки карты в Wallet: загрузка, правки и сохранение
@MainActor
final class WSWalletSettingsModel: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var loadError: String? = nil
    @Published private(set) var settings: WSSettings? = nil

    @Published var color: String = ""
    @Published var showPrice: Bool = true
    @Published var showStamps: Bool = true
    @Published var rules: String = ""
    @Published var address: String = ""

    @Published var toast: SEToastInfo? = nil

    /// Что сервер отдал при последней загрузке или сохранении
    private var saved: WSSettingsUpdate? = nil

    // MARK: Вычисляемое

    var colors: [WSColor] { settings?.colors ?? [] }

    var currentColor: WSColor? {
        return colors.first { $0.key == color } ?? colors.first
    }

    /// Текущее состояние полей в том виде, в котором его уйдёт PUT
    var current: WSSettingsUpdate {
        return WSSettingsUpdate(
            color: color,
            showPrice: showPrice,
            showStamps: showStamps,
            rules: rules,
            address: address
        )
    }

    var isDirty: Bool {
        guard let baseline: WSSettingsUpdate = saved else { return false }
        return baseline != current
    }

    var canSave: Bool { isDirty && !isSaving && !isLoading }

    /// Программа «Скидки постоянным» выключена — штампов на карте не будет
    var loyaltyEnabled: Bool { settings?.loyaltyEnabled == true }

    var threshold: Int { max(1, settings?.loyaltyThreshold ?? 10) }

    var gift: String {
        let raw: String = (settings?.loyaltyGift ?? "").trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? "−10%" : raw
    }

    var masterName: String {
        let raw: String = (settings?.masterName ?? "").trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? "Мастер" : raw
    }

    var cardsIssued: Int? { settings?.cardsIssued }

    var walletAvailable: Bool { settings?.walletAvailable != false }

    /// Пример закрашенных кружков: 7 из 10, а если порог меньше — все, кроме последнего
    var exampleFilled: Int {
        return threshold > 7 ? 7 : max(0, threshold - 1)
    }

    // MARK: Действия

    func load() async {
        isLoading = true
        loadError = nil
        do {
            let fresh: WSSettings = try await APIClient.shared.walletSettings()
            settings = fresh
            apply(fresh)
        } catch {
            loadError = bcErrorText(error)
        }
        isLoading = false
    }

    func pickColor(_ item: WSColor) {
        guard color != item.key else { return }
        HapticManager.selection()
        color = item.key
    }

    func setAddress(_ value: String) {
        address = String(value.prefix(WSLimits.address))
    }

    func setRules(_ value: String) {
        rules = String(value.prefix(WSLimits.rules))
    }

    func save() async {
        guard canSave else { return }
        isSaving = true
        let payload: WSSettingsUpdate = current
        do {
            try await APIClient.shared.updateWalletSettings(payload)
            saved = payload
            HapticManager.success()
            showToast("Сохранено. Карты у клиенток обновятся сами", isError: false)
            // Обновить счётчики и «доступность», не трогая правки
            if let fresh: WSSettings = try? await APIClient.shared.walletSettings() {
                settings = fresh
            }
        } catch {
            HapticManager.error()
            showToast(bcErrorText(error), isError: true)
        }
        isSaving = false
    }

    private func apply(_ fresh: WSSettings) {
        color = fresh.color
        showPrice = fresh.showPrice
        showStamps = fresh.showStamps
        rules = fresh.rules
        address = fresh.address
        saved = WSSettingsUpdate(
            color: fresh.color,
            showPrice: fresh.showPrice,
            showStamps: fresh.showStamps,
            rules: fresh.rules,
            address: fresh.address
        )
    }

    private func showToast(_ text: String, isError: Bool) {
        toast = SEToastInfo(text: text, isError: isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if self.toast?.text == text { self.toast = nil }
        }
    }
}

// MARK: - Экран «Карта в Wallet»

struct WSWalletSettingsView: View {
    @StateObject private var vm = WSWalletSettingsModel()
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 — карта с записью, 1 — карта без записи
    @State private var previewMode: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.backgroundDeep.ignoresSafeArea()

            if vm.settings == nil {
                loadingOrError
            } else {
                VStack(spacing: 0) {
                    previewCard
                    ScrollView(showsIndicators: false) { settingsContent }
                }
            }

            toastLayer
        }
        .animation(reduceMotion ? nil : DS.springSnappy, value: vm.toast?.id)
        .navigationTitle("Карта в Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }

    // MARK: Загрузка и ошибка

    @ViewBuilder
    private var loadingOrError: some View {
        VStack(spacing: 14) {
            if vm.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                Text("Загружаем настройки карты…")
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textMuted)
            } else if let message: String = vm.loadError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(theme.statusYellow)
                Text(message)
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 280)
                wsButton(title: "Повторить") {
                    Task { await vm.load() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: Миниатюра карты (закреплена сверху)

    @ViewBuilder
    private var previewCard: some View {
        if let palette: WSColor = vm.currentColor {
            VStack(spacing: 12) {
                WSPassToggle(mode: previewMode) { newMode in
                    guard newMode != previewMode else { return }
                    HapticManager.selection()
                    previewMode = newMode
                }

                WSPassPreview(
                    palette: palette,
                    masterName: vm.masterName,
                    hasBooking: previewMode == 0,
                    showPrice: vm.showPrice,
                    showStamps: vm.showStamps && vm.loyaltyEnabled,
                    address: vm.address,
                    threshold: vm.threshold,
                    filled: vm.exampleFilled,
                    gift: vm.gift
                )
                .frame(width: 240, height: 370)

                Text("Так карта выглядит у клиентки · меняется сразу")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .animation(
                reduceMotion ? nil : DS.springSnappy,
                value: palette.key
            )
            .animation(
                reduceMotion ? nil : DS.springSnappy,
                value: vm.showPrice
            )
            .animation(
                reduceMotion ? nil : DS.springSnappy,
                value: vm.showStamps
            )
        }
    }

    // MARK: Настройки

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !vm.walletAvailable {
                soonBanner
            }

            colorBlock
            togglesBlock
            addressBlock
            rulesBlock
            aboutBlock

            SELabel(title: "ЧТО ПОМЕНЯТЬ НЕЛЬЗЯ")
            Text("Расположение полей, шрифт и размер карты задаёт Apple.")
                .font(DS.bodySmall)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            BBPrimaryButton(
                title: "Сохранить",
                isLoading: vm.isSaving,
                isDisabled: !vm.canSave
            ) {
                Task { await vm.save() }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 40)
    }

    private var colorBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("ЦВЕТ КАРТЫ")
                    .font(DS.labelSmall.weight(.bold))
                    .tracking(0.8)
                    .foregroundColor(theme.textSecondary)
                if let name: String = vm.currentColor?.name {
                    Text("· \(name)")
                        .font(DS.labelSmall.weight(.bold))
                        .foregroundColor(theme.textMuted)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 52), spacing: 10)],
                spacing: 10
            ) {
                ForEach(vm.colors) { item in
                    WSColorDot(item: item, isSelected: item.key == vm.color) {
                        vm.pickColor(item)
                    }
                }
            }
        }
    }

    private var togglesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SELabel(title: "ЧТО ПОКАЗЫВАТЬ")
            SEGroup {
                SEToggleRow(
                    title: "Показывать цену",
                    subtitle: "Стоимость услуги внизу карты",
                    isOn: Binding(
                        get: { vm.showPrice },
                        set: { newValue in vm.showPrice = newValue }
                    )
                )
                SEDivider()
                if vm.loyaltyEnabled {
                    SEToggleRow(
                        title: "Штампы за визиты",
                        subtitle: "Кружки визитов и подарок",
                        isOn: Binding(
                            get: { vm.showStamps },
                            set: { newValue in vm.showStamps = newValue }
                        )
                    )
                } else {
                    Text("Включите «Скидки постоянным», чтобы на карте появились штампы")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("АДРЕС КАБИНЕТА")
                    .font(DS.labelSmall.weight(.bold))
                    .tracking(0.8)
                    .foregroundColor(theme.textSecondary)
                Spacer(minLength: 0)
                Text("\(vm.address.count)/\(WSLimits.address)")
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
            }
            WSInputBox(placeholder: "ул. Чапаева, 12, каб. 4", text: addressBinding)
        }
    }

    private var rulesBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("ПРАВИЛА НА ОБОРОТЕ КАРТЫ")
                    .font(DS.labelSmall.weight(.bold))
                    .tracking(0.8)
                    .foregroundColor(theme.textSecondary)
                Spacer(minLength: 0)
                Text("\(vm.rules.count)/\(WSLimits.rules)")
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
            }
            WSTextArea(
                placeholder: "Например: отменить или перенести можно не позже чем за 12 часов",
                text: rulesBinding
            )
        }
    }

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Клиентки получают карту после записи по ссылке — кнопка «Добавить в Apple Wallet». Постоянной клиентке можно отправить карту из её карточки.")
                .font(DS.bodySmall)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let cards: Int = vm.cardsIssued {
                Text("Выдано карт: \(cards)")
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textMuted)
            }
        }
    }

    private var soonBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.statusYellow)
            Text("Карты Wallet скоро заработают")
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.statusYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Тост

    @ViewBuilder
    private var toastLayer: some View {
        if let info: SEToastInfo = vm.toast {
            SEToast(info: info)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Привязки полей

    private var addressBinding: Binding<String> {
        return Binding(
            get: { vm.address },
            set: { vm.setAddress($0) }
        )
    }

    private var rulesBinding: Binding<String> {
        return Binding(
            get: { vm.rules },
            set: { vm.setRules($0) }
        )
    }

    /// Вторичная кнопка 44pt в стиле настроек
    private func wsButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            Text(title)
                .font(DS.body)
                .foregroundColor(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(CLPressStyle())
    }
}

// MARK: - Миниатюра карты

/// Нарисованная SwiftUI копия того, что клиентка видит в Wallet
struct WSPassPreview: View {
    let palette: WSColor
    let masterName: String
    let hasBooking: Bool
    let showPrice: Bool
    let showStamps: Bool
    let address: String
    let threshold: Int
    let filled: Int
    let gift: String

    private let cardWidth: CGFloat = 240
    private let cardHeight: CGFloat = 370

    private var bgColor: Color { Color(hex: palette.bg) }
    private var fgColor: Color { Color(hex: palette.fg) }
    private var labelColor: Color { Color(hex: palette.label) }

    var body: some View {
        ZStack {
            pattern
            content
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(fgColor.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color(hex: palette.d1).opacity(0.35), radius: 14, y: 8)
    }

    /// Узор: полоса и два круга
    private var pattern: some View {
        ZStack {
            Rectangle().fill(bgColor)
            Rectangle()
                .fill(Color(hex: palette.strip))
                .frame(height: 92)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Circle()
                .fill(Color(hex: palette.d1).opacity(0.9))
                .frame(width: 188, height: 188)
                .offset(x: 86, y: -98)
            Circle()
                .fill(Color(hex: palette.d2).opacity(0.85))
                .frame(width: 118, height: 118)
                .offset(x: -76, y: 36)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            masterRow
            Spacer(minLength: 10)
            if hasBooking {
                bookingBlock
            } else {
                freeBlock
            }
            Spacer(minLength: 10)
            if showStamps {
                stampsBlock
            }
        }
        .padding(16)
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
    }

    /// Логотип — круг цвета label и имя мастера рядом
    private var masterRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(labelColor)
                .frame(width: 22, height: 22)
                .overlay(
                    Text(masterInitial)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(bgColor)
                )
            Text(masterName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(fgColor)
                .lineLimit(1)
        }
    }

    private var masterInitial: String {
        guard let first: Character = masterName.first else { return "·" }
        return String(first).uppercased()
    }

    /// Вариант с записью: дата, крупно время, затем услуга, адрес, цена и статус
    private var bookingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            caption("ДАТА 9 ОКТ")
            Text("14:00")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(fgColor)
            VStack(alignment: .leading, spacing: 5) {
                fieldRow(label: "УСЛУГА", value: "Маникюр с покрытием")
                if !address.trimmingCharacters(in: .whitespaces).isEmpty {
                    fieldRow(label: "АДРЕС", value: address)
                }
                if showPrice {
                    fieldRow(label: "ЦЕНА", value: rubText(1800))
                }
                fieldRow(label: "СТАТУС", value: "Подтверждена")
            }
        }
    }

    /// Вариант без записи: призыв записаться и последний визит
    private var freeBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            caption("СЛЕДУЮЩИЙ ВИЗИТ —")
            Text("Записаться снова")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundColor(fgColor)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            VStack(alignment: .leading, spacing: 5) {
                fieldRow(label: "ПОСЛЕДНИЙ ВИЗИТ", value: "12 сен")
                fieldRow(label: "УСЛУГА", value: "Маникюр с покрытием")
            }
            Text("Нажмите ⓘ → «Записаться»")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(labelColor)
                .padding(.top, 2)
        }
    }

    /// Кружки визитов из программы «Скидки постоянным»
    private var stampsBlock: some View {
        // Больше 12 кружков на карте не помещается — ограничиваем показ
        let visible: Int = min(max(1, threshold), 12)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("ВИЗИТЫ \(filled) / \(threshold)")
                Text("·")
                Text("ПОДАРОК \(gift)")
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(labelColor)

            HStack(spacing: 4) {
                ForEach(0..<visible, id: \.self) { index in
                    Circle()
                        .fill(index < filled ? labelColor : Color.clear)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(labelColor, lineWidth: 1))
                }
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundColor(labelColor)
    }

    private func fieldRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(labelColor)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(fgColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

// MARK: - Переключатель «С записью» / «Без записи»

private struct WSPassToggle: View {
    let mode: Int
    let onPick: (Int) -> Void

    @Namespace private var ns
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            item(0, title: "С записью")
            item(1, title: "Без записи")
        }
        .padding(3)
        .background(theme.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(reduceMotion ? nil : DS.springSnappy, value: mode)
    }

    private func item(_ index: Int, title: String) -> some View {
        let isSelected: Bool = mode == index
        return Button {
            guard !isSelected else { return }
            onPick(index)
        } label: {
            Text(title)
                .font(DS.body)
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
                            .matchedGeometryEffect(id: "ws.preview.toggle", in: ns)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Кружок цвета карты

private struct WSColorDot: View {
    let item: WSColor
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle().fill(Color(hex: item.bg))
                Circle()
                    .fill(Color(hex: item.label))
                    .frame(width: 14, height: 14)
            }
            .frame(width: 44, height: 44)
            .overlay {
                Circle()
                    .stroke(isSelected ? theme.accent : theme.borderSubtle, lineWidth: isSelected ? 3 : 1)
                    .frame(width: 44, height: 44)
            }
            .contentShape(Circle())
        }
        .buttonStyle(CLPressStyle(scale: 0.92))
        .accessibilityLabel(item.name)
    }
}

// MARK: - Поле ввода

private struct WSInputBox: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 16))
                    .foregroundColor(theme.textMuted)
                    .padding(.horizontal, 14)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text)
                .font(.system(size: 16))
                .foregroundColor(theme.textPrimary)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
        }
        .frame(height: 48)
        .background(theme.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Поле правил

private struct WSTextArea: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundColor(theme.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.system(size: 15))
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(minHeight: 90)
        .background(theme.backgroundInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}