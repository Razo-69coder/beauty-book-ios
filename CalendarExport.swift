import Foundation
import EventKit

// MARK: - Результат

/// Что получилось при добавлении записи в Календарь iPhone
enum CALResult {
    case added
    case alreadyAdded
    case denied
    case failed
}

// MARK: - Экспорт в Календарь

/// Добавляет запись в Календарь iPhone и помнит, что уже добавляли
@MainActor
final class CALExporter {
    static let shared = CALExporter()

    private let store: EKEventStore
    /// Ключ UserDefaults: id записи → «дата время», под которыми добавляли
    private let defaultsKey: String = "CALAddedEvents"

    private init() {
        store = EKEventStore()
    }

    /// Добавить запись в календарь по умолчанию
    func add(_ appointment: Appointment) async -> CALResult {
        let granted: Bool
        do {
            granted = try await store.requestWriteOnlyAccessToEvents()
        } catch {
            return .failed
        }
        guard granted else { return .denied }

        // С этой датой и временем уже добавляли — второй раз не создаём
        let stamp: String = calStamp(appointment)
        if savedStamps()[stampKey(appointment.id)] == stamp { return .alreadyAdded }

        guard let start: Date = calStartDate(appointment) else { return .failed }

        let minutes: Int = appointment.duration ?? 60
        let event: EKEvent = EKEvent(eventStore: store)
        event.title = "\(appointment.procedure) — \(appointment.clientName ?? "Клиентка")"
        event.startDate = start
        event.endDate = start.addingTimeInterval(Double(max(1, minutes)) * 60)
        event.notes = calNotes(appointment)
        event.calendar = store.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -3600))

        do {
            try store.save(event, span: .thisEvent)
        } catch {
            return .failed
        }

        saveStamp(stampKey(appointment.id), value: stamp)
        return .added
    }

    /// Уже в календаре с этой датой и временем — для подписи кнопки
    func isAdded(_ appointment: Appointment) -> Bool {
        savedStamps()[stampKey(appointment.id)] == calStamp(appointment)
    }

    // MARK: - Даты и текст

    /// «2026-10-04 18:00» → Date в часовом поясе телефона
    private func calStartDate(_ appointment: Appointment) -> Date? {
        let formatter: DateFormatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(appointment.appointmentDate) \(appointment.time)")
    }

    /// Цена и телефон клиентки — одной строкой
    private func calNotes(_ appointment: Appointment) -> String {
        var notes: String = "Solvo Beauty · \(appointment.price) ₽"
        if let phone: String = appointment.clientPhone, !phone.isEmpty {
            notes = notes + " · " + phone
        }
        return notes
    }

    private func calStamp(_ appointment: Appointment) -> String {
        "\(appointment.appointmentDate) \(appointment.time)"
    }

    private func stampKey(_ appointmentId: Int) -> String {
        "\(appointmentId)"
    }

    // MARK: - UserDefaults

    private func savedStamps() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
    }

    private func saveStamp(_ key: String, value: String) {
        var stamps: [String: String] = savedStamps()
        stamps[key] = value
        UserDefaults.standard.set(stamps, forKey: defaultsKey)
    }
}