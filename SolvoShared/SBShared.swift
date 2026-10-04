import Foundation
import ActivityKit

// MARK: - Общая группа приложений
// Этот файл собирается и в приложении, и в виджете.
// Здесь нельзя ссылаться на типы приложения (Appointment, APIClient, тема, DS) —
// в виджете их нет, сборка упадёт.

// Идентификатор App Group: приложение пишет снимок, виджет его читает
let SBAppGroupID: String = "group.com.solvobeauty.app"

// Ключ снимка в общих UserDefaults
private let SBWidgetSnapshotKey: String = "SBWidgetSnapshot"

// MARK: - Данные для виджета

/// Один визит в том виде, в каком его показывает виджет
struct SBWidgetVisit: Codable, Hashable, Identifiable {
    let id: Int
    let start: Date
    let durationMin: Int
    let client: String
    let procedure: String

    /// Время окончания визита
    var end: Date {
        start.addingTimeInterval(TimeInterval(durationMin) * 60)
    }
}

/// Снимок расписания: визиты на сегодня и завтра, отсортированы по времени начала
struct SBWidgetSnapshot: Codable {
    let updatedAt: Date
    let visits: [SBWidgetVisit]
}

// MARK: - Хранилище снимка

/// Запись и чтение снимка в общих UserDefaults (App Group)
enum SBWidgetStore {
    /// Общие настройки приложения и виджета
    private static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SBAppGroupID)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// Сохранить снимок. Не смогли — молча, виджет покажет прошлые данные
    static func save(_ snapshot: SBWidgetSnapshot) {
        guard let defaults = sharedDefaults() else { return }
        guard let data: Data = try? makeEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: SBWidgetSnapshotKey)
    }

    /// Прочитать снимок. Нет снимка — nil
    static func load() -> SBWidgetSnapshot? {
        guard let defaults = sharedDefaults() else { return nil }
        guard let data: Data = defaults.data(forKey: SBWidgetSnapshotKey) else { return nil }
        return try? makeDecoder().decode(SBWidgetSnapshot.self, from: data)
    }

    /// Стереть снимок (выход из аккаунта)
    static func clear() {
        sharedDefaults()?.removeObject(forKey: SBWidgetSnapshotKey)
    }
}

// MARK: - Русские склонения

/// 1 запись, 2 записи, 5 записей; 11–14 → many
func SBPlural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let value: Int = abs(n)
    let lastTwo: Int = value % 100
    let lastOne: Int = value % 10
    if lastTwo >= 11 && lastTwo <= 14 { return many }
    switch lastOne {
    case 1: return one
    case 2, 3, 4: return few
    default: return many
    }
}

// MARK: - Live Activity

/// Данные Live Activity «Скоро визит»
struct SBVisitAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var client: String
        var procedure: String
        var start: Date
        var end: Date
    }
    /// id записи в расписании — по нему узнаём, что Live Activity устарела
    var visitId: Int
}
