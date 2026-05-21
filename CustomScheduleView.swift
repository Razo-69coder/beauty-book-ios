import SwiftUI

@MainActor
final class CustomScheduleViewModel: ObservableObject {
    @Published var slotsForMonth: [String: [String]] = [:]
    @Published var selectedDate: Date = Date()
    @Published var slotsForDay: [String] = []
    @Published var isLoading = false
    @Published var showTimePicker = false
    @Published var newSlotTimeText: String = ""
    @Published var slotTimeError: String? = nil

    private let api = APIClient.shared
    private let cal = Calendar(identifier: .gregorian)
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM"; return f
    }()
    var currentMonth: String { monthFmt.string(from: selectedDate) }
    var dateKey: String { dateFmt.string(from: selectedDate) }

    var daysInMonth: [Date] {
        guard let range = cal.range(of: .day, in: .month, for: selectedDate),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: selectedDate))
        else { return [] }
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    var firstWeekdayOffset: Int {
        guard let first = daysInMonth.first else { return 0 }
        let wd = cal.component(.weekday, from: first)
        return (wd + 5) % 7
    }

    func loadMonth() async {
        isLoading = true
        slotsForMonth = (try? await api.fetchCustomSlots(month: currentMonth)) ?? [:]
        slotsForDay = slotsForMonth[dateKey] ?? []
        isLoading = false
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        slotsForDay = slotsForMonth[dateKey] ?? []
    }

    func addSlot() async {
        let raw = newSlotTimeText.trimmingCharacters(in: .whitespaces)
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              h >= 0 && h <= 23, m >= 0 && m <= 59 else {
            slotTimeError = "Введите время в формате ЧЧ:ММ, например 09:30"
            return
        }
        let timeStr = String(format: "%02d:%02d", h, m)
        guard !slotsForDay.contains(timeStr) else {
            slotTimeError = "Этот слот уже добавлен"
            return
        }
        slotTimeError = nil
        try? await api.addCustomSlot(date: dateKey, time: timeStr)
        slotsForDay.append(timeStr)
        slotsForDay.sort()
        slotsForMonth[dateKey] = slotsForDay
        newSlotTimeText = ""
        showTimePicker = false
    }

    func removeSlot(_ time: String) async {
        try? await api.removeCustomSlot(date: dateKey, time: time)
        slotsForDay.removeAll { $0 == time }
        if slotsForDay.isEmpty {
            slotsForMonth.removeValue(forKey: dateKey)
        } else {
            slotsForMonth[dateKey] = slotsForDay
        }
    }

    func changeMonth(by value: Int) async {
        guard let newDate = cal.date(byAdding: .month, value: value, to: selectedDate) else { return }
        selectedDate = cal.date(from: cal.dateComponents([.year, .month], from: newDate)) ?? newDate
        await loadMonth()
    }
}

struct CustomScheduleView: View {
    @StateObject private var vm = CustomScheduleViewModel()
    @Environment(\.theme) private var theme

    private let cal = Calendar(identifier: .gregorian)
    private let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private let monthNames = ["","Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"]

    private var monthTitle: String {
        let m = cal.component(.month, from: vm.selectedDate)
        let y = cal.component(.year, from: vm.selectedDate)
        return "\(monthNames[m]) \(y)"
    }

    var body: some View {
        ZStack {
            theme.backgroundDeep.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    monthHeader
                    calendarGrid
                    daySlots
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Моё расписание")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accent)
        .task { await vm.loadMonth() }
        .sheet(isPresented: $vm.showTimePicker) { timePickerSheet }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button { Task { await vm.changeMonth(by: -1) } } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
            Spacer()
            Text(monthTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer()
            Button { Task { await vm.changeMonth(by: 1) } } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<vm.firstWeekdayOffset, id: \.self) { _ in Color.clear.frame(height: 44) }
                ForEach(vm.daysInMonth, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(16)
    }

    private func dayCell(_ date: Date) -> some View {
        let dateFmt: DateFormatter = {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
        }()
        let key = dateFmt.string(from: date)
        let day = cal.component(.day, from: date)
        let isSelected = cal.isDate(date, inSameDayAs: vm.selectedDate)
        let hasSlots = vm.slotsForMonth[key] != nil
        let isToday = cal.isDateInToday(date)

        return Button { vm.selectDate(date) } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? theme.accent : theme.textPrimary))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? AnyShapeStyle(theme.gradientPrimary) : AnyShapeStyle(Color.clear))
                    .clipShape(Circle())
                Circle()
                    .fill(hasSlots ? theme.accent : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Slots

    private var daySlots: some View {
        let dateFmt: DateFormatter = {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "d MMMM"; f.locale = Locale(identifier: "ru_RU"); return f
        }()
        let title = dateFmt.string(from: vm.selectedDate)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button { vm.showTimePicker = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Добавить")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.accent)
                }
            }

            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if vm.slotsForDay.isEmpty {
                Text("Нет слотов — в этот день запись недоступна (используется стандартное расписание)")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(vm.slotsForDay, id: \.self) { time in
                        HStack(spacing: 4) {
                            Text(time)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Button { Task { await vm.removeSlot(time) } } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(theme.textMuted)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(theme.backgroundCard)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.borderSubtle, lineWidth: 1))
                    }
                }
            }
        }
        .padding(16)
        .background(theme.backgroundCard)
        .cornerRadius(16)
    }

    // MARK: - Time Picker Sheet

    private var timePickerSheet: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Введите время слота")
                            .font(DS.body)
                            .foregroundColor(theme.textMuted)

                        TextField("09:30", text: $vm.newSlotTimeText)
                            .keyboardType(.numbersAndPunctuation)
                            .font(.system(size: 40, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(theme.backgroundCard)
                            .cornerRadius(16)
                            .onChange(of: vm.newSlotTimeText) { _, new in
                                vm.newSlotTimeText = formatTimeInput(new)
                                vm.slotTimeError = nil
                            }

                        if let err = vm.slotTimeError {
                            Text(err)
                                .font(DS.bodySmall)
                                .foregroundColor(theme.statusRed)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)

                    BBPrimaryButton(title: "Добавить слот") {
                        Task { await vm.addSlot() }
                    }
                    .environment(\.theme, theme)
                    .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Добавить время")
            .navigationBarTitleDisplayMode(.inline)
            .tint(theme.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        vm.newSlotTimeText = ""
                        vm.slotTimeError = nil
                        vm.showTimePicker = false
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatTimeInput(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        guard digits.count > 2 else { return String(digits.prefix(2)) }
        let h = String(digits.prefix(2))
        let m = String(digits.dropFirst(2).prefix(2))
        return "\(h):\(m)"
    }
}

#Preview {
    NavigationStack {
        CustomScheduleView().environment(\.theme, .pink)
    }
}
