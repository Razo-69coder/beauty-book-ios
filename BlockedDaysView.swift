import SwiftUI

@MainActor
final class BlockedDaysViewModel: ObservableObject {
    @Published var blockedDays: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let api = APIClient.shared

    var days: [Date] {
        (0..<60).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    }

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d"
        return f
    }()

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEEE"
        return f
    }()

    func dateString(_ date: Date) -> String { formatter.string(from: date) }
    func dayNumber(_ date: Date) -> String { displayFormatter.string(from: date) }
    func dayName(_ date: Date) -> String { dayNameFormatter.string(from: date).uppercased() }
    func monthTitle(_ date: Date) -> String { monthFormatter.string(from: date).capitalized }

    func isBlocked(_ date: Date) -> Bool { blockedDays.contains(dateString(date)) }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func load() async {
        isLoading = true
        if let r = try? await api.request(.getBlockedDays, as: BlockedDaysResponse.self) {
            blockedDays = Set(r.blockedDays)
        }
        isLoading = false
    }

    func toggle(_ date: Date) async {
        let str = dateString(date)
        if blockedDays.contains(str) {
            _ = try? await api.request(.removeBlockedDay(str), as: MessageResponse.self)
            blockedDays.remove(str)
        } else {
            _ = try? await api.request(.addBlockedDay(str), as: MessageResponse.self)
            blockedDays.insert(str)
        }
        HapticManager.light()
    }
}

struct BlockedDaysView: View {
    @StateObject private var vm = BlockedDaysViewModel()
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ZStack {
            AppBackground(theme: theme).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                if vm.isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            infoCard
                            daysGrid
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task { await vm.load() }
    }

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.accent)
            }
            Spacer()
            Text("Нерабочие дни")
                .font(DS.titleSmall)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Color.clear.frame(width: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var infoCard: some View {
        BBGlassCard {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.minus")
                    .font(.system(size: 22))
                    .foregroundColor(theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Отметьте дни, когда не работаете")
                        .font(DS.label)
                        .foregroundColor(theme.textPrimary)
                    Text("Клиенты не смогут записаться на эти даты")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
    }

    private var daysGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            BBSectionHeader(title: "Ближайшие 60 дней")

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(vm.days, id: \.self) { day in
                    DayCell(
                        dayNumber: vm.dayNumber(day),
                        dayName: vm.dayName(day),
                        isBlocked: vm.isBlocked(day),
                        isToday: vm.isToday(day),
                        theme: theme
                    ) {
                        Task { await vm.toggle(day) }
                    }
                }
            }

            if !vm.blockedDays.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(theme.statusRed).frame(width: 8, height: 8)
                    Text("Заблокировано дней: \(vm.blockedDays.count)")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.top, 4)
            }
        }
    }
}

struct DayCell: View {
    let dayNumber: String
    let dayName: String
    let isBlocked: Bool
    let isToday: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isBlocked ? .white.opacity(0.7) : theme.textMuted)
                Text(dayNumber)
                    .font(.system(size: 15, weight: isToday ? .bold : .medium))
                    .foregroundColor(isBlocked ? .white : (isToday ? theme.accent : theme.textPrimary))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isBlocked ? AnyShapeStyle(theme.statusRed.opacity(0.85)) : AnyShapeStyle(theme.backgroundInput))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isToday ? theme.accent : theme.borderSubtle, lineWidth: isToday ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
