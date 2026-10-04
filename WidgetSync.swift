import Foundation
import WidgetKit
import ActivityKit

// MARK: - Синхронизация расписания с виджетом и Live Activity
// Виджет не ходит в сеть: приложение кладёт снимок в общие UserDefaults (App Group)
// и просит WidgetKit перерисоваться. Ошибка сети — тихо выходим, в виджете
// остаются прошлые данные.

// Не чаще раза в 30 секунд, чтобы не дёргать сервер на каждый чих
private let SBWidgetMinInterval: TimeInterval = 30

@MainActor
final class SBWidgetSync {
    static let shared = SBWidgetSync()

    private var lastRefresh: Date?

    /// Дата для запроса расписания: "yyyy-MM-dd"
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let calendar: Calendar = Calendar.current

    private init() {}

    // MARK: Обновление

    /// Перезаписать снимок и Live Activity. Не чаще раза в 30 секунд, если не force
    func refresh(force: Bool = false) async {
        let now = Date()
        if !force,
           let previous: Date = lastRefresh,
           now.timeIntervalSince(previous) < SBWidgetMinInterval {
            return
        }
        lastRefresh = now

        // Сегодня и завтра — завтра нужен, чтобы «следующая запись» была видна заранее
        var visits: [SBWidgetVisit] = []
        for offset: Int in 0...1 {
            guard let day: Date = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let dayString: String = dayFormatter.string(from: day)
            guard let response: ScheduleResponse = try? await APIClient.shared.request(
                .schedule(date: dayString),
                as: ScheduleResponse.self
            ) else {
                // Нет сети или 401 — прошлые данные в виджете не трогаем
                return
            }
            for appointment: Appointment in response.appointments {
                if let visit: SBWidgetVisit = makeVisit(appointment) {
                    visits.append(visit)
                }
            }
        }

        let snapshot = SBWidgetSnapshot(
            updatedAt: now,
            visits: visits.sorted { $0.start < $1.start }
        )
        SBWidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        await updateLiveActivity(snapshot.visits)
    }

    /// Выход из аккаунта: снимок и Live Activity больше не показываем
    func clear() async {
        SBWidgetStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
        lastRefresh = nil
        for activity in Activity<SBVisitAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Запись → визит

    /// Отменённые и «неявки» в виджет не попадают
    private func makeVisit(_ appointment: Appointment) -> SBWidgetVisit? {
        if appointment.status == .cancelled { return nil }
        if appointment.status == .noShow { return nil }

        guard let day: Date = dayFormatter.date(from: appointment.appointmentDate) else { return nil }
        let parts: [String] = appointment.time.split(separator: ":").map { String($0) }
        guard parts.count >= 2,
              let hour: Int = Int(parts[0]),
              let minute: Int = Int(parts[1]),
              let start: Date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
            return nil
        }

        let duration: Int = appointment.duration ?? 60
        return SBWidgetVisit(
            id: appointment.id,
            start: start,
            durationMin: duration > 0 ? duration : 60,
            client: firstName(appointment.clientName),
            procedure: appointment.procedure
        )
    }

    /// Виджет показывает только имя: «Анна», а не «Анна Иванова»
    private func firstName(_ fullName: String?) -> String {
        guard let full: String = fullName else { return "Клиентка" }
        let trimmed: String = full.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Клиентка" }
        guard let space: Range<String.Index> = trimmed.range(of: " ") else { return trimmed }
        let first: String = String(trimmed[trimmed.startIndex..<space.lowerBound])
        return first.isEmpty ? "Клиентка" : first
    }

    // MARK: Live Activity

    /// Показываем Live Activity только для ближайшего визита, до которого не больше 2 часов
    private func updateLiveActivity(_ visits: [SBWidgetVisit]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()

        // Ближайший: уже начался (но не больше длительности назад), ещё не закончился, впереди не дальше 2 часов
        var target: SBWidgetVisit?
        for visit in visits {
            let lead: TimeInterval = visit.start.timeIntervalSince(now)
            if lead > 2 * 60 * 60 { continue }
            if lead < -(TimeInterval(visit.durationMin) * 60) { continue }
            if visit.end <= now { continue }
            target = visit
            break
        }

        // Всё, что не про наш визит или уже закончилось — закрываем
        var existing: Activity<SBVisitAttributes>?
        for activity in Activity<SBVisitAttributes>.activities {
            if let current: SBWidgetVisit = target,
               activity.attributes.visitId == current.id {
                existing = activity
                continue
            }
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        guard let visit: SBWidgetVisit = target else { return }

        let state = SBVisitAttributes.ContentState(
            client: visit.client,
            procedure: visit.procedure,
            start: visit.start,
            end: visit.end
        )
        let content = ActivityContent(state: state, staleDate: visit.end)

        if let current: Activity<SBVisitAttributes> = existing {
            await current.update(content)
        } else {
            let attributes = SBVisitAttributes(visitId: visit.id)
            do {
                _ = try Activity<SBVisitAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                print("[SBWidget] Live Activity не запустилась: \(error.localizedDescription)")
            }
        }
    }
}
