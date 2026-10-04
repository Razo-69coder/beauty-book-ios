import SwiftUI
import WidgetKit
import Foundation

// MARK: - Запись для временной шкалы

struct SBTodayEntry: TimelineEntry {
    /// Момент, на который построена запись
    let date: Date
    /// Визиты на дату записи, по времени начала
    let visitsToday: [SBWidgetVisit]
    /// Первый визит, который ещё не закончился
    let next: SBWidgetVisit?
    /// Снимок вообще существует (иначе приложение ещё ни разу не открывали)
    let hasData: Bool
}

// MARK: - Данные для шкалы

private enum SBTodaySource {
    /// Снимок из общего хранилища
    static func snapshot() -> SBWidgetSnapshot? {
        SBWidgetStore.load()
    }

    /// Визиты на дату, отсортированные по времени начала
    static func visits(at date: Date) -> [SBWidgetVisit] {
        guard let snapshot: SBWidgetSnapshot = snapshot() else { return [] }
        let calendar: Calendar = Calendar.current
        return snapshot.visits
            .filter { calendar.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }

    /// Запись для момента времени
    static func entry(at date: Date) -> SBTodayEntry {
        let today: [SBWidgetVisit] = visits(at: date)
        let upcoming: SBWidgetVisit? = today.first { $0.end > date }
        return SBTodayEntry(
            date: date,
            visitsToday: today,
            next: upcoming,
            hasData: snapshot() != nil
        )
    }

    /// Пример для превью в галерее виджетов
    static var placeholderVisits: [SBWidgetVisit] {
        let calendar: Calendar = Calendar.current
        let now: Date = Date()
        let first: Date = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now
        return [
            SBWidgetVisit(id: 1, start: first, durationMin: 60, client: "Анна", procedure: "Маникюр"),
            SBWidgetVisit(id: 2, start: calendar.date(byAdding: .hour, value: 2, to: first) ?? first, durationMin: 90, client: "Мария", procedure: "Педикюр"),
            SBWidgetVisit(id: 3, start: calendar.date(byAdding: .hour, value: 4, to: first) ?? first, durationMin: 120, client: "Ольга", procedure: "Окрашивание"),
            SBWidgetVisit(id: 4, start: calendar.date(byAdding: .hour, value: 6, to: first) ?? first, durationMin: 60, client: "Дарья", procedure: "Коррекция")
        ]
    }
}

// MARK: - Провайдер

struct SBTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> SBTodayEntry {
        let visits: [SBWidgetVisit] = SBTodaySource.placeholderVisits
        return SBTodayEntry(
            date: Date(),
            visitsToday: visits,
            next: visits.first,
            hasData: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SBTodayEntry) -> Void) {
        completion(SBTodaySource.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SBTodayEntry>) -> Void) {
        let now: Date = Date()
        let calendar: Calendar = Calendar.current
        let startOfToday: Date = calendar.startOfDay(for: now)
        // Полночь — следующая точка обновления: «сегодня» станет «завтра»
        let midnight: Date = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? now.addingTimeInterval(60 * 60 * 24)

        // Точки обновления: сейчас, начало каждого сегодняшнего визита и полночь —
        // тогда «следующая запись» меняется сама
        var points: [Date] = [now, midnight]
        for visit: SBWidgetVisit in SBTodaySource.visits(at: now) {
            if visit.start > now { points.append(visit.start) }
        }

        var unique: [Date] = []
        for point: Date in points.sorted() {
            if let last: Date = unique.last, last == point { continue }
            unique.append(point)
        }

        let entries: [SBTodayEntry] = unique.map { SBTodaySource.entry(at: $0) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Виджет «Сегодня»

struct SBTodayWidget: Widget {
    let kind: String = "SBTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SBTodayProvider()) { entry in
            SBTodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Записи на сегодня")
        .description("Сколько записей сегодня и кто следующий")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Отрисовка

struct SBTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SBTodayEntry

    var body: some View {
        switch family {
        case .systemSmall:           smallBody
        case .systemMedium:          mediumBody
        case .accessoryRectangular:  rectangularBody
        default:                     inlineBody
        }
    }

    // Крупное число записей

    private var countBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(entry.visitsToday.count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(SBWidgetStyle.primary)
            Text(SBPlural(entry.visitsToday.count, "запись", "записи", "записей"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SBWidgetStyle.secondary)
        }
    }

    /// Ближайшая запись: время и имя
    private var nextBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Следующая")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBWidgetStyle.secondary)
            if let next: SBWidgetVisit = entry.next {
                Text("\(SBWidgetTime.string(from: next.start)) · \(next.client)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SBWidgetStyle.accent)
                    .lineLimit(1)
                Text(next.procedure)
                    .font(.system(size: 12))
                    .foregroundStyle(SBWidgetStyle.secondary)
                    .lineLimit(1)
            } else {
                Text("Все записи прошли")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SBWidgetStyle.secondary)
            }
        }
    }

    private var emptyText: String {
        entry.hasData ? "Сегодня свободно" : "Откройте Solvo Beauty"
    }

    // systemSmall

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Сегодня")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBWidgetStyle.secondary)
            if entry.visitsToday.isEmpty {
                Text(emptyText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SBWidgetStyle.primary)
                    .lineLimit(2)
            } else {
                countBlock
                nextBlock
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .containerBackground(for: .widget) { SBWidgetStyle.background }
    }

    // systemMedium

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Сегодня")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SBWidgetStyle.secondary)
                if entry.visitsToday.isEmpty {
                    Text(emptyText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SBWidgetStyle.primary)
                        .lineLimit(2)
                } else {
                    countBlock
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Ближайшие")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SBWidgetStyle.secondary)
                ForEach(upcoming, id: \.id) { visit in
                    Text("\(SBWidgetTime.string(from: visit.start)) \(visit.client) — \(visit.procedure)")
                        .font(.system(size: 13))
                        .foregroundStyle(SBWidgetStyle.primary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .containerBackground(for: .widget) { SBWidgetStyle.background }
    }

    /// До трёх ближайших, которые ещё не закончились
    private var upcoming: [SBWidgetVisit] {
        let list: [SBWidgetVisit] = entry.visitsToday.filter { $0.end > entry.date }
        return Array(list.prefix(3))
    }

    // accessoryRectangular — экран блокировки

    private var rectangularBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rectangularTitle)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if let next: SBWidgetVisit = entry.next {
                Text("Далее \(SBWidgetTime.string(from: next.start)) · \(next.client)")
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var rectangularTitle: String {
        if entry.visitsToday.isEmpty { return emptyText }
        let word: String = SBPlural(entry.visitsToday.count, "запись", "записи", "записей")
        return "Сегодня: \(entry.visitsToday.count) \(word)"
    }

    // accessoryInline

    private var inlineBody: some View {
        Text(inlineText)
            .containerBackground(for: .widget) { Color.clear }
    }

    private var inlineText: String {
        guard let next: SBWidgetVisit = entry.next else { return emptyText }
        return "\(SBWidgetTime.string(from: next.start)) · \(next.client)"
    }
}
