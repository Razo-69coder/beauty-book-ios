import Foundation
import Security

// MARK: - Auth

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String
}

struct AuthTokenResponse: Decodable {
    let token: String
    let master: MasterProfile
}

struct MessageResponse: Decodable {
    let ok: Bool
    let message: String?
}

struct BookingLinkResponse: Decodable {
    let bookingLink: String
}

// MARK: - Master

struct MasterProfile: Decodable, Identifiable {
    let id: Int
    let email: String?
    let name: String?
    let workStart: Int
    let workEnd: Int
    let slotDuration: Int
    let timezone: String
    let reminderDays: Int
    let paymentCard: String?
    let paymentPhone: String?
    let paymentBanks: String?
    let depositEnabled: Bool
    let depositPercent: Int
    let theme: String
}

struct MasterSettingsRequest: Encodable {
    var name: String
    var workStart: Int
    var workEnd: Int
    var slotDuration: Int
    var reminderDays: Int
    var timezone: String
}

struct PaymentRequest: Encodable {
    var paymentCard: String
    var paymentPhone: String
    var paymentBanks: String
}

// MARK: - Stats

struct StatsResponse: Decodable {
    let totalClients: Int
    let totalAppointments: Int
    let totalEarnings: Int
    let monthEarnings: Int
    let topProcedures: [TopProcedure]
}

struct TopProcedure: Decodable, Identifiable {
    var id: String { procedure }
    let procedure: String
    let count: Int
}

// MARK: - Clients

struct Client: Decodable, Identifiable {
    let id: Int
    let name: String
    let phone: String
    let notes: String?
    let lastVisit: String?
    let username: String?
    let telegramId: Int?
    var appointmentsCount: Int?
    var birthday: String?
}

struct ClientDetail: Decodable, Identifiable {
    let id: Int
    let name: String
    let phone: String
    let notes: String?
    let username: String?
    let telegramId: Int?
    let history: [AppointmentHistory]
}

struct ClientPhoto: Identifiable, Codable {
    let id: Int
    let clientId: Int
    let url: String
    var caption: String?
    let createdAt: String
}

struct ClientPhotosResponse: Codable {
    let photos: [ClientPhoto]
}

struct AppointmentHistory: Decodable, Identifiable {
    var id: String { "\(procedure)-\(appointmentDate)" }
    let procedure: String
    let appointmentDate: String
    let time: String
    let price: Int
    let notes: String?
    let status: String?
}

struct ClientsResponse: Decodable {
    let clients: [Client]
    let total: Int
    let page: Int
}

struct ClientCreateRequest: Encodable {
    let name: String
    let phone: String
    let notes: String
}

struct ClientUpdateRequest: Encodable {
    let name: String
    let phone: String
    let notes: String
}

// MARK: - Appointments

struct Appointment: Decodable, Identifiable {
    let id: Int
    let clientId: Int
    let masterId: Int
    let procedure: String
    let appointmentDate: String
    let time: String
    let price: Int
    let notes: String?
    let status: AppointmentStatus
    let depositStatus: DepositStatus?
    let depositAmount: Int?
    let clientName: String?
    let clientPhone: String?
    let serviceDoneAt: String?
    var duration: Int?
}

enum AppointmentStatus: String, Decodable, CaseIterable {
    case confirmed = "confirmed"
    case pending   = "pending"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .confirmed: return "Подтверждено"
        case .pending:   return "Ожидает"
        case .completed: return "Выполнено"
        case .cancelled: return "Отменено"
        }
    }

    var hexColor: String {
        switch self {
        case .confirmed: return "#00E5A0"
        case .pending:   return "#FFD166"
        case .completed: return "#4ECDC4"
        case .cancelled: return "#FF4757"
        }
    }
}

enum DepositStatus: String, Decodable {
    case notRequired    = "not_required"
    case pendingPayment = "pending_payment"
    case paid           = "paid"
}

struct AppointmentCreateRequest: Encodable {
    let clientId: Int
    let procedure: String
    let appointmentDate: String
    let time: String
    let price: Int
    let notes: String
}

struct AppointmentUpdateRequest: Encodable {
    var procedure: String?
    var appointmentDate: String?
    var time: String?
    var price: Int?
    var notes: String?
    var status: String?
}

// MARK: - Schedule

struct ScheduleResponse: Decodable {
    let date: String
    let appointments: [Appointment]
}

struct SlotsResponse: Decodable {
    let slots: [String]
}

// MARK: - Services

struct Service: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let priceDefault: Int
    let durationMin: Int
    var category: String = "Основные"
}

struct ServicesResponse: Decodable {
    let services: [Service]
}

struct ServiceCreateRequest: Encodable {
    let name: String
    let priceDefault: Int
    let durationMin: Int
    let category: String
}

// MARK: - Expenses

struct Expense: Identifiable, Codable {
    let id: Int
    let category: String
    let amount: Int
    let description: String
    let date: String
}

struct ExpensesResponse: Codable {
    let expenses: [Expense]
}

enum ExpenseCategory: String, CaseIterable {
    case materials = "Материалы"
    case rent = "Аренда"
    case tools = "Инструменты"
    case other = "Другое"
    
    var icon: String {
        switch self {
        case .materials: return "cart"
        case .rent: return "house"
        case .tools: return "scissors"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Keychain Manager

final class KeychainManager {
    static let shared = KeychainManager()
    private let tokenKey    = "beauty_book_jwt"
    private let masterIdKey = "beauty_book_master_id"
    private init() {}

    func saveToken(_ token: String) { save(key: tokenKey, value: token) }
    func getToken() -> String?      { load(key: tokenKey) }
    func deleteToken()               { delete(key: tokenKey) }
    func saveMasterId(_ id: Int)    { save(key: masterIdKey, value: "\(id)") }
    func getMasterId() -> Int?      { load(key: masterIdKey).flatMap { Int($0) } }
    var isAuthenticated: Bool        { getToken() != nil }

    private func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key, kSecValueData: data]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }
    private func load(key: String) -> String? {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key,
                                   kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func delete(key: String) {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(q as CFDictionary)
    }
}
