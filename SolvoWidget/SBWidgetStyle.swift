import SwiftUI
import Foundation

// MARK: - Оформление виджета
// Виджет не знает про тему приложения — свои цвета и формат времени задаём здесь.
// Файл нужен всем экранам виджета, поэтому объявления не private.

/// Цвета виджета «Сегодня» и Live Activity
enum SBWidgetStyle {
    /// Тёмный фон виджета
    static let background: Color = Color(red: 0.07, green: 0.04, blue: 0.08)
    /// Розовый акцент
    static let accent: Color = Color(red: 1.0, green: 0.24, blue: 0.53)
    /// Белый текст
    static let primary: Color = Color.white
    /// Белый вторичный текст (70%)
    static let secondary: Color = Color.white.opacity(0.7)
}

/// Время в формате "HH:mm"
let SBWidgetTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "HH:mm"
    return formatter
}()
