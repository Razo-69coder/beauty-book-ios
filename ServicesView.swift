import SwiftUI

// MARK: - Категории услуг

/// Порядок категорий на экране и иконки. Неизвестные категории с сервера уходят в конец по алфавиту.
enum SVCategory {
    /// Все категории в порядке вывода на экране
    static let order: [String] = [
        "Маникюр", "Педикюр", "Дизайн", "Ресницы", "Брови", "Макияж", "Массаж", "Основные", "Другое"
    ]

    /// Категории для выбора в шторке — те же, но без «Основные»
    static let pickable: [String] = Self.order.filter { $0 != "Основные" }

    /// Значение «все категории» для чипа и фильтра
    static let all: String = "Все"

    private static let icons: [String: String] = [
        "Маникюр": "hand.raised.fill",
        "Педикюр": "shoeprints.fill",
        "Дизайн": "sparkles",
        "Ресницы": "eye.fill",
        "Брови": "eyebrow",
        "Макияж": "paintbrush.pointed.fill",
        "Массаж": "hands.sparkles.fill"
    ]

    /// Иконка категории; для неизвестных — сетка
    static func icon(for raw: String) -> String {
        icons[raw] ?? "square.grid.2x2.fill"
    }

    static func isKnown(_ raw: String) -> Bool {
        order.contains(raw)
    }

    /// Сортирует категории: известные — по заданному порядку, остальные — в конец по алфавиту
    static func sorted(_ raws: [String]) -> [String] {
        let unique: [String] = Array(Set(raws))
        let known: [String] = Self.order.filter { unique.contains($0) }
        let rest: [String] = unique.filter { !isKnown($0) }.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        return known + rest
    }
}

// MARK: - Длительности

enum SVDuration {
    static let options: [Int] = [15, 30, 45, 60, 90, 120, 150, 180]

    /// «45 мин», «2 ч», «1 ч 30 мин»
    static func label(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) мин" }
        let hours: Int = minutes / 60
        let rest: Int = minutes % 60
        if rest == 0 { return "\(hours) ч" }
        return "\(hours) ч \(rest) мин"
    }

    /// Если текущая длительность не в списке — добавляем её по возрастанию
    static func options(including current: Int) -> [Int] {
        guard !Self.options.contains(current) else { return Self.options }
        return (Self.options + [current]).sorted()
    }
}

// MARK: - Группа услуг одной категории

struct SVServiceGroup: Identifiable {
    let category: String
    let services: [Service]

    var id: String { category }
}

// MARK: - Строка услуги

struct SVRow: View {
    let service: Service
    let theme: AppTheme
    /// nil — счётчики за месяц ещё грузятся
    let monthCount: Int?
    let isHit: Bool
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconTile
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    subtitle
                }
                Spacer(minLength: 8)
                Text(rubText(service.priceDefault))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(minHeight: 68)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isHighlighted ? theme.accent.opacity(0.12) : theme.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(CLPressStyle(scale: 0.98, releaseAnimation: DS.springSmooth))
        .accessibilityLabel("\(service.name), \(rubText(service.priceDefault))")
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.accent.opacity(0.14))
                .frame(width: 44, height: 44)
            Image(systemName: SVCategory.icon(for: service.category))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(theme.accent)
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        HStack(spacing: 6) {
            Text(SVDuration.label(service.durationMin))
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            if let count = monthCount {
                Text("·")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                Text(monthText(count))
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                if isHit && count > 0 {
                    hitTag
                }
            }
        }
    }

    private func monthText(_ count: Int) -> String {
        let word: String = ruPlural(count, "запись", "записи", "записей")
        return count > 0 ? "\(count) \(word) за месяц" : "ещё не записывались"
    }

    private var hitTag: some View {
        Text("Хит")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.accent.opacity(0.15), in: Capsule())
    }
}

// MARK: - Заголовок категории в списке

struct SVCategoryHeader: View {
    let title: String
    let count: Int
    let theme: AppTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textMuted)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer(minLength: 4)
            Text("\(count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textMuted)
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Капсула выбора (длительность, категория)

struct SVPill: View {
    let title: String
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(theme.backgroundInput))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : theme.borderSubtle, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(CLPressStyle(scale: 0.94))
    }
}

// MARK: - Появление секции шторки по очереди

private struct SVSection<Content: View>: View {
    let index: Int
    private let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    init(index: Int, @ViewBuilder content: @escaping () -> Content) {
        self.index = index
        self.content = content
    }

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: verticalOffset)
            .animation(animation, value: appeared)
            .onAppear {
                guard !appeared else { return }
                guard !reduceMotion else {
                    appeared = true
                    return
                }
                let delay: Double = Double(index) * 0.06
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    appeared = true
                }
            }
    }

    private var verticalOffset: CGFloat {
        if appeared || reduceMotion { return 0 }
        return 14
    }

    private var animation: Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        return DS.springSmooth.delay(Double(index) * 0.06)
    }
}

// MARK: - Тряска поля

private struct SVShake: GeometryEffect {
    var amount: CGFloat = 9
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

// MARK: - Экран «Услуги»

struct ServicesView: View {
    @StateObject private var vm = ServicesViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didRevealList = false
    @State private var scrollResetToken: Int = 0

    private let topAnchorId: String = "svTopAnchor"

    var body: some View {
        Color.clear
            .overlay { scrollContent }
            .overlay(alignment: .bottomTrailing) { fabButton }
            .task { await vm.loadIfNeeded() }
            .task(id: vm.hasLoadedOnce) { await revealListOnce() }
            .sheet(isPresented: $vm.showSheet) {
                SVServiceSheet(
                    service: vm.editingService,
                    monthCount: vm.editingMonthCount,
                    isMonthCountLoaded: vm.isMonthCountsLoaded,
                    suggestedCategory: vm.suggestedCategory,
                    prefilledName: vm.sheetPrefill,
                    onSave: { name, price, duration, category in
                        await vm.saveSheet(
                            name: name,
                            price: price,
                            duration: duration,
                            category: category
                        )
                    },
                    onDelete: {
                        await vm.deleteEditingService()
                    }
                )
                .environment(\.theme, theme)
            }
    }

    // MARK: - Скролл

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchorId)
                    headerSection
                    searchBar
                    categoriesRow
                    listContent
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await vm.loadServices() }
            .onChange(of: vm.scrollTargetId) { _, newId in
                handleScrollTarget(newId, proxy: proxy)
            }
            .onChange(of: scrollResetToken) { _, _ in
                withAnimation(reduceMotion ? nil : DS.springSnappy) {
                    proxy.scrollTo(topAnchorId, anchor: .top)
                }
            }
        }
    }

    private func handleScrollTarget(_ newId: Int?, proxy: ScrollViewProxy) {
        guard let newId = newId else { return }
        withAnimation(reduceMotion ? nil : DS.springSmooth) {
            proxy.scrollTo(SVRowAnchor.id(for: newId), anchor: .center)
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            vm.highlightId = nil
        }
        vm.scrollTargetId = nil
    }

    private func revealListOnce() async {
        guard vm.hasLoadedOnce, !didRevealList, !vm.services.isEmpty else { return }
        try? await Task.sleep(nanoseconds: 700_000_000)
        didRevealList = true
    }

    // MARK: - Шапка

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(countText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent)
                Text("Услуги")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
            }
            Spacer(minLength: 8)
            HeaderBellButton()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var countText: String {
        let total: Int = vm.services.count
        return "\(total) \(ruPlural(total, "услуга", "услуги", "услуг"))"
    }

    // MARK: - Поиск

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(theme.textMuted)
            TextField("Поиск услуги", text: $vm.searchText)
                .font(DS.body)
                .foregroundColor(theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(theme.textMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(height: 52)
        .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Категории

    private var categoriesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                svTapTarget44(CLFilterChip(
                    title: SVCategory.all,
                    count: nil,
                    isSelected: vm.selectedCategory == SVCategory.all,
                    theme: theme
                ) {
                    selectCategory(SVCategory.all)
                })
                ForEach(vm.availableCategories, id: \.self) { category in
                    svTapTarget44(CLFilterChip(
                        title: category,
                        count: vm.count(for: category),
                        isSelected: vm.selectedCategory == category,
                        theme: theme
                    ) {
                        selectCategory(category)
                    })
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    /// CLFilterChip высотой 36 pt — доводим зону нажатия до 44 pt, не меняя вид
    private func svTapTarget44(_ chip: some View) -> some View {
        chip
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private func selectCategory(_ category: String) {
        guard vm.selectedCategory != category else { return }
        HapticManager.selection()
        withAnimation(reduceMotion ? nil : DS.springSnappy) {
            vm.selectedCategory = category
        }
        scrollResetToken += 1
    }

    // MARK: - Список

    @ViewBuilder
    private var listContent: some View {
        if vm.isLoading && vm.services.isEmpty {
            loadingState
        } else if vm.services.isEmpty {
            emptyState
        } else if vm.filteredServices.isEmpty {
            notFoundState
        } else {
            servicesList
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
            Text("Загружаю услуги...")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var servicesList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(vm.groups.enumerated()), id: \.element.id) { groupIndex, group in
                SVCategoryHeader(title: group.category, count: group.services.count, theme: theme)
                ForEach(Array(group.services.enumerated()), id: \.element.id) { rowIndex, service in
                    rowView(service, index: groupIndex + rowIndex)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 140)
        .animation(reduceMotion ? .none : DS.springSnappy, value: vm.selectedCategory)
    }

    private func rowView(_ service: Service, index: Int) -> some View {
        CLStaggeredRow(index: index, stagger: !didRevealList) {
            SVRow(
                service: service,
                theme: theme,
                monthCount: vm.isMonthCountsLoaded ? (vm.monthCounts[service.id] ?? 0) : nil,
                isHit: vm.hitServiceId == service.id,
                isHighlighted: vm.highlightId == service.id
            ) {
                HapticManager.selection()
                vm.openEditor(for: service)
            }
            .id(SVRowAnchor.id(for: service.id))
            .padding(.bottom, 8)
        }
    }

    // MARK: - Пустые состояния

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: vm.errorMessage == nil ? "sparkles" : "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(vm.errorMessage == nil ? theme.textMuted : theme.statusRed)
            Text(vm.errorMessage == nil ? "Пока нет услуг" : "Не удалось загрузить")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(emptyStateText)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if vm.errorMessage == nil {
                addServiceButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 140)
    }

    private var emptyStateText: String {
        if vm.errorMessage != nil {
            return "Проверьте интернет-соединение и потяните список вниз, чтобы обновить."
        }
        return "Добавь услуги с ценой и длительностью, и клиенты увидят их в онлайн-записи."
    }

    private var notFoundState: some View {
        VStack(spacing: 10) {
            Text("Не нашли")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(notFoundText)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            addServiceButton
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 140)
    }

    private var notFoundText: String {
        if !vm.trimmedQuery.isEmpty {
            return "Услуги «\(vm.trimmedQuery)» пока нет."
        }
        return "В этой категории пока пусто."
    }

    private var addServiceButton: some View {
        BBPrimaryButton(title: "Добавить услугу") {
            vm.openCreator(prefill: vm.trimmedQuery)
        }
        .environment(\.theme, theme)
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            HapticManager.medium()
            vm.openCreator(prefill: "")
        } label: {
            ZStack {
                Circle()
                    .fill(theme.gradientPrimary)
                    .frame(width: 60, height: 60)
                    .shadow(color: theme.accentGlow, radius: 12, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .contentShape(Circle())
        }
        .buttonStyle(CLPressStyle(scale: 0.92, releaseAnimation: DS.springBouncy))
        .padding(.bottom, 100)
        .padding(.trailing, 20)
        .accessibilityLabel("Новая услуга")
    }
}

// MARK: - Якорь строки для прокрутки

private enum SVRowAnchor {
    static func id(for serviceId: Int) -> String { "svRow_\(serviceId)" }
}

// MARK: - Шторка услуги

struct SVServiceSheet: View {
    let service: Service?
    let monthCount: Int
    let isMonthCountLoaded: Bool
    let onSave: (String, Int, Int, String) async -> Bool
    let onDelete: () async -> Bool

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var name: String
    @State private var price: Int
    @State private var priceText: String = ""
    @State private var isEditingPrice = false
    @State private var duration: Int
    @State private var category: String
    @State private var nameIsValid: Bool = true
    @State private var nameShake: CGFloat = 0
    @State private var isSaving: Bool = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var deleteArmed: Bool = false
    @State private var deleteBounce: CGFloat = 0

    @FocusState private var priceFocused: Bool

    private let step: Int = 100
    private let minPrice: Int = 0
    private let maxPrice: Int = 999_900

    init(
        service: Service?,
        monthCount: Int,
        isMonthCountLoaded: Bool,
        suggestedCategory: String,
        prefilledName: String,
        onSave: @escaping (String, Int, Int, String) async -> Bool,
        onDelete: @escaping () async -> Bool
    ) {
        self.service = service
        self.monthCount = monthCount
        self.isMonthCountLoaded = isMonthCountLoaded
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: service?.name ?? prefilledName)
        _price = State(initialValue: service?.priceDefault ?? 1500)
        _duration = State(initialValue: service?.durationMin ?? 60)
        _category = State(initialValue: service?.category ?? suggestedCategory)
    }

    private var isEditing: Bool { service != nil }

    var body: some View {
        ZStack {
            theme.backgroundDeep
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    sheetHeader
                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        SVSection(index: index) { section }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { commitPriceEdit() }
                    .foregroundColor(theme.accent)
            }
        }
    }

    /// Секции шторки в порядке появления
    private var sections: [AnyView] {
        var items: [AnyView] = []
        if isEditing, isMonthCountLoaded, monthCount > 0 {
            items.append(AnyView(revenueNote))
        }
        items.append(AnyView(nameField))
        items.append(AnyView(priceSection))
        items.append(AnyView(durationSection))
        items.append(AnyView(categorySection))
        items.append(AnyView(actionButtons))
        return items
    }

    // MARK: - Шапка

    private var sheetHeader: some View {
        HStack {
            Text(isEditing ? "Услуга" : "Новая услуга")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer(minLength: 8)
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
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Плашка выручки

    private var revenueNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.statusGreen)
            Text(revenueText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.statusGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var revenueText: String {
        let word: String = ruPlural(monthCount, "запись", "записи", "записей")
        let revenue: Int = monthCount * (service?.priceDefault ?? 0)
        return "\(monthCount) \(word) за месяц, это \(rubText(revenue)) выручки"
    }

    // MARK: - Название

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Название")
            BBTextField(
                placeholder: "Например, Маникюр с покрытием",
                text: $name,
                isValid: nameIsValid
            )
            .environment(\.theme, theme)
            .modifier(SVShake(animatableData: nameShake))
            .onChange(of: name) { _, _ in
                if !nameIsValid, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    nameIsValid = true
                    nameShake = 0
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.textMuted)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    // MARK: - Цена

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Цена")
            stepper
        }
    }

    private var stepper: some View {
        HStack(spacing: 12) {
            stepperButton(symbol: "minus", accessibility: "Дешевле на 100 рублей") {
                changePrice(by: -step)
            }
            priceValue
            stepperButton(symbol: "plus", accessibility: "Дороже на 100 рублей") {
                changePrice(by: step)
            }
        }
        .padding(8)
        .background(theme.backgroundCard, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    private func stepperButton(symbol: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(theme.accent)
                .frame(width: 64, height: 56)
                .background(theme.backgroundInput, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(CLPressStyle(scale: 0.9))
        .accessibilityLabel(accessibility)
    }

    @ViewBuilder
    private var priceValue: some View {
        VStack(spacing: 2) {
            if isEditingPrice {
                TextField("", text: $priceText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                    .focused($priceFocused)
                    .onChange(of: priceText) { _, newValue in
                        let cleaned: String = SVPrice.sanitize(newValue)
                        if cleaned != newValue { priceText = cleaned }
                    }
                    .onChange(of: priceFocused) { _, focused in
                        if !focused { commitPriceEdit() }
                    }
                    .frame(height: 34)
            } else {
                Button {
                    beginPriceEdit()
                } label: {
                    Text(rubText(price))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("шаг 100 ₽")
                .font(.system(size: 12))
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func changePrice(by delta: Int) {
        guard !isEditingPrice else { return }
        HapticManager.selection()
        let next: Int = min(max(price + delta, minPrice), maxPrice)
        guard next != price else { return }
        withAnimation(DS.springSnappy) {
            price = next
        }
    }

    private func beginPriceEdit() {
        isEditingPrice = true
        priceText = String(price)
        priceFocused = true
    }

    private func commitPriceEdit() {
        guard isEditingPrice else { return }
        if let parsed: Int = Int(priceText) {
            price = min(max(parsed, minPrice), maxPrice)
        }
        priceFocused = false
        isEditingPrice = false
    }

    // MARK: - Длительность

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Длительность")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92, maximum: 200), spacing: 8)],
                spacing: 8
            ) {
                ForEach(SVDuration.options(including: duration), id: \.self) { minutes in
                    SVPill(
                        title: SVDuration.label(minutes),
                        isSelected: minutes == duration,
                        theme: theme
                    ) {
                        selectDuration(minutes)
                    }
                }
            }
        }
    }

    private func selectDuration(_ minutes: Int) {
        guard duration != minutes else { return }
        HapticManager.selection()
        withAnimation(DS.springSnappy) {
            duration = minutes
        }
    }

    // MARK: - Категория

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Категория")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 108, maximum: 200), spacing: 8)],
                spacing: 8
            ) {
                ForEach(categoryOptions, id: \.self) { item in
                    SVPill(title: item, isSelected: item == category, theme: theme) {
                        selectCategory(item)
                    }
                }
            }
        }
    }

    /// Если у услуги «Основные» или незнакомая категория — она идёт первой, чтобы не потеряться
    private var categoryOptions: [String] {
        guard !SVCategory.pickable.contains(category) else { return SVCategory.pickable }
        return [category] + SVCategory.pickable
    }

    private func selectCategory(_ item: String) {
        guard category != item else { return }
        HapticManager.selection()
        withAnimation(DS.springSnappy) {
            category = item
        }
    }

    // MARK: - Кнопки

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if let errorMessage = errorMessage {
                BBErrorBanner(message: errorMessage)
            }
            BBPrimaryButton(
                title: isEditing ? "Сохранить" : "Добавить услугу",
                isLoading: isSaving || isDeleting
            ) {
                save()
            }
            .environment(\.theme, theme)
            if isEditing {
                deleteButton
            }
        }
        .padding(.top, 4)
    }

    private var deleteButton: some View {
        Button {
            deleteTapped()
        } label: {
            Text(deleteArmed ? "Точно удалить? Прошлые записи останутся" : "Удалить услугу")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.statusRed)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(theme.statusRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .offset(y: -deleteBounce)
    }

    private func deleteTapped() {
        guard !isDeleting else { return }
        guard !deleteArmed else {
            Task { await performDelete() }
            return
        }
        HapticManager.warning()
        withAnimation(DS.springBouncy) { deleteBounce = 5 }
        withAnimation(DS.springBouncy.delay(0.08)) { deleteBounce = 0 }
        withAnimation(DS.springSnappy) { deleteArmed = true }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard deleteArmed else { return }
            withAnimation(DS.springSmooth) { deleteArmed = false }
        }
    }

    // MARK: - Сохранение

    private func save() {
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameIsValid = false
            HapticManager.error()
            nameShake = 0
            // Тряска отключаем при Reduce Motion, красную рамку оставляем
            if !reduceMotion {
                withAnimation(.linear(duration: 0.4)) { nameShake = 1 }
            }
            return
        }
        guard !isSaving, !isDeleting else { return }

        isSaving = true
        errorMessage = nil
        Task {
            let ok: Bool = await onSave(trimmed, price, duration, category)
            isSaving = false
            guard ok else {
                errorMessage = "Не удалось сохранить. Проверьте связь и попробуйте ещё раз."
                HapticManager.error()
                return
            }
            HapticManager.success()
            dismiss()
        }
    }

    private func performDelete() async {
        isDeleting = true
        deleteArmed = false
        errorMessage = nil
        let ok: Bool = await onDelete()
        isDeleting = false
        guard ok else {
            errorMessage = "Не удалось удалить услугу. Попробуйте ещё раз."
            HapticManager.error()
            return
        }
        HapticManager.success()
        dismiss()
    }
}

// MARK: - Санитайзер цены

private enum SVPrice {
    private static let digits: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

    /// Только цифры, не больше 6 знаков
    static func sanitize(_ raw: String) -> String {
        let cleaned: String = raw.filter { digits.contains($0) }
        return String(cleaned.prefix(6))
    }
}

// MARK: - View Model

/// Разбор строки «Услуга А + Услуга Б» в счётчики по id услуг
private func svCountByService(_ appointments: [Appointment], byName: [String: Int]) -> [Int: Int] {
    var result: [Int: Int] = [:]
    for appointment in appointments {
        if appointment.status == .cancelled || appointment.status == .noShow { continue }
        let parts: [String] = appointment.procedure
            .components(separatedBy: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for part in parts {
            if let serviceId: Int = byName[part.lowercased()] {
                result[serviceId, default: 0] += 1
            }
        }
    }
    return result
}

/// Дата в формате «yyyy-MM-dd» — тот же, что ждёт сервер
private func svDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

@MainActor
final class ServicesViewModel: ObservableObject {
    @Published var services: [Service] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var total: Int = 0
    @Published var monthCounts: [Int: Int] = [:]
    @Published var isMonthCountsLoaded: Bool = false
    @Published var selectedCategory: String = SVCategory.all
    @Published var searchText: String = ""
    @Published var highlightId: Int? = nil
    @Published var scrollTargetId: Int? = nil
    @Published var hasLoadedOnce: Bool = false
    @Published var showSheet: Bool = false
    @Published var editingService: Service? = nil
    @Published var sheetPrefill: String = ""

    private let api = APIClient.shared
    private let calendar = Calendar.current

    // MARK: - Производные значения

    var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredServices: [Service] {
        let query: String = trimmedQuery
        return services.filter { service in
            let categoryOK: Bool = selectedCategory == SVCategory.all
                || service.category == selectedCategory
            let queryOK: Bool = query.isEmpty
                || service.name.range(of: query, options: [.caseInsensitive]) != nil
            return categoryOK && queryOK
        }
    }

    /// Категории, в которых есть хотя бы одна услуга
    var availableCategories: [String] {
        SVCategory.sorted(services.map { $0.category })
    }

    /// Категории, которые попадут в список после фильтрации
    var groups: [SVServiceGroup] {
        let matched: [String: [Service]] = Dictionary(
            grouping: filteredServices,
            by: { $0.category }
        )
        let order: [String] = availableCategories.filter { matched[$0] != nil }
        return order.map { SVServiceGroup(category: $0, services: matched[$0] ?? []) }
    }

    func count(for category: String) -> Int {
        services.filter { $0.category == category }.count
    }

    /// Услуга с наибольшим числом записей за месяц
    var hitServiceId: Int? {
        var bestId: Int? = nil
        var bestCount: Int = 0
        for service in services {
            let current: Int = monthCounts[service.id] ?? 0
            if current > bestCount {
                bestCount = current
                bestId = service.id
            }
        }
        return bestId
    }

    var editingMonthCount: Int {
        guard let service = editingService else { return 0 }
        return monthCounts[service.id] ?? 0
    }

    /// Категория, выбранная на экране — как значение по умолчанию в шторке
    var suggestedCategory: String {
        if selectedCategory != SVCategory.all, SVCategory.pickable.contains(selectedCategory) {
            return selectedCategory
        }
        return "Маникюр"
    }

    // MARK: - Загрузка

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await loadServices()
    }

    func loadServices() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: ServicesResponse = try await api.request(.services, as: ServicesResponse.self)
            services = response.services
            total = services.count
        } catch {
            // Список не трогаем: при ошибке показываем то, что уже загружено
            errorMessage = "Нет подключения к интернету"
        }

        isLoading = false
        hasLoadedOnce = true

        if services.isEmpty {
            monthCounts = [:]
            isMonthCountsLoaded = true
        } else {
            await loadMonthCounts()
        }
    }

    /// Записи за последние 30 дней: 30 запросов расписания параллельно, экран не блокируется
    private func loadMonthCounts() async {
        isMonthCountsLoaded = false

        var byName: [String: Int] = [:]
        for service in services {
            byName[service.name.lowercased()] = service.id
        }

        var days: [String] = []
        for offset in 0..<30 {
            if let date: Date = calendar.date(byAdding: .day, value: -offset, to: Date()) {
                days.append(svDateString(date))
            }
        }

        let loaded: [Int: Int] = await withTaskGroup(
            of: [Int: Int].self,
            returning: [Int: Int].self
        ) { group in
            for key in days {
                group.addTask { [api] in
                    guard let response: ScheduleResponse = try? await api.request(
                        .schedule(date: key),
                        as: ScheduleResponse.self
                    ) else { return [:] }
                    return svCountByService(response.appointments, byName: byName)
                }
            }

            var result: [Int: Int] = [:]
            for await dayCounts in group {
                guard !Task.isCancelled else { return result }
                for (serviceId, value) in dayCounts {
                    result[serviceId, default: 0] += value
                }
            }
            return result
        }

        monthCounts = loaded
        isMonthCountsLoaded = true
    }

    // MARK: - Сохранение

    func openCreator(prefill: String) {
        editingService = nil
        sheetPrefill = prefill
        showSheet = true
    }

    func openEditor(for service: Service) {
        editingService = service
        sheetPrefill = ""
        showSheet = true
    }

    /// Сохранение из шторки: редактирование или создание — в зависимости от открытой услуги
    func saveSheet(name: String, price: Int, duration: Int, category: String) async -> Bool {
        await save(
            editing: editingService,
            name: name,
            price: price,
            duration: duration,
            category: category
        )
    }

    func save(editing service: Service?, name: String, price: Int, duration: Int, category: String) async -> Bool {
        let ok: Bool
        if let service = service {
            ok = await updateService(service, name: name, price: price, duration: duration, category: category)
        } else {
            ok = await addService(name: name, price: price, duration: duration, category: category)
        }
        guard ok else { return false }
        resetFiltersAndFocus(name: name)
        return true
    }

    /// После сохранения — показываем все категории, очищаем поиск и подсвечиваем услугу
    private func resetFiltersAndFocus(name: String) {
        selectedCategory = SVCategory.all
        searchText = ""
        if let found: Service = services.first(where: { $0.name == name }) {
            highlightId = found.id
            scrollTargetId = found.id
        }
    }

    func addService(name: String, price: Int, duration: Int, category: String) async -> Bool {
        let request = ServiceCreateRequest(
            name: name,
            priceDefault: price,
            durationMin: duration,
            category: category
        )
        do {
            let _ = try await api.request(.createService(request), as: Service.self)
            await loadServices()
            return true
        } catch NetworkError.decodingError(_) {
            // Запрос прошёл, но ответ не декодировался — всё равно считаем успехом
            await loadServices()
            return true
        } catch {
            return false
        }
    }

    func updateService(_ service: Service, name: String, price: Int, duration: Int, category: String) async -> Bool {
        let request = ServiceCreateRequest(
            name: name,
            priceDefault: price,
            durationMin: duration,
            category: category
        )
        do {
            let _ = try await api.request(.updateService(id: service.id, request), as: MessageResponse.self)
            if let index: Int = services.firstIndex(where: { $0.id == service.id }) {
                services[index] = Service(
                    id: service.id,
                    name: name,
                    priceDefault: price,
                    durationMin: duration,
                    category: category
                )
                total = services.count
            }
            return true
        } catch {
            return false
        }
    }

    /// Удаление услуги, открытой в шторке
    func deleteEditingService() async -> Bool {
        guard let service = editingService else { return false }
        return await deleteService(service)
    }

    func deleteService(_ service: Service) async -> Bool {
        do {
            let _ = try await api.request(.deleteService(id: service.id), as: MessageResponse.self)
            services.removeAll { $0.id == service.id }
            total = services.count
            // Удалённая услуга могла быть подсвечена или выбрана в фильтре
            selectedCategory = SVCategory.all
            searchText = ""
            highlightId = nil
            scrollTargetId = nil
            return true
        } catch {
            return false
        }
    }
}

#Preview {
    ServicesView()
        .environment(\.theme, .pink)
        .environmentObject(NotificationsViewModel())
}
