import Foundation

// MARK: - Auth Models

struct AuthTokenResponse: Decodable {
    let token: String
    let master: MasterProfile
}

struct LoginResponse: Decodable {
    let token: String
    let masterId: Int
}

struct ResendCodeResponse: Decodable {
    let ok: Bool
}

struct RequestCodeResponse: Decodable {
    let ok: Bool
}

// MARK: - Master

struct MasterProfile: Decodable, Identifiable {
    let id: Int
    let telegramId: Int
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
    let stats: StatsResponse?
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

struct AppointmentHistory: Decodable, Identifiable {
    var id: String { "\(procedure)-\(appointmentDate)" }
    let procedure: String
    let appointmentDate: String
    let price: Int
    let notes: String?
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
    let username: String
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
}

enum AppointmentStatus: String, Decodable, CaseIterable {
    case confirmed  = "confirmed"
    case pending    = "pending"
    case completed  = "completed"
    case cancelled  = "cancelled"

    var displayName: String {
        switch self {
        case .confirmed:  return "Подтверждено"
        case .pending:    return "Ожидает"
        case .completed:  return "Выполнено"
        case .cancelled:  return "Отменено"
        }
    }

    var color: String {
        switch self {
        case .confirmed:  return "#00E5A0"
        case .pending:    return "#FFD166"
        case .completed:  return "#4ECDC4"
        case .cancelled:  return "#FF4757"
        }
    }
}

enum DepositStatus: String, Decodable {
    case notRequired     = "not_required"
    case pendingPayment  = "pending_payment"
    case paid            = "paid"
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
}

struct ServicesResponse: Decodable {
    let services: [Service]
}

struct ServiceCreateRequest: Encodable {
    let name: String
    let priceDefault: Int
}

// MARK: - Keychain Manager

import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private let tokenKey = "beauty_book_jwt"
    private let masterIdKey = "beauty_book_master_id"

    private init() {}

    func saveToken(_ token: String) {
        save(key: tokenKey, value: token)
    }

    func getToken() -> String? {
        load(key: tokenKey)
    }

    func deleteToken() {
        delete(key: tokenKey)
    }

    func saveMasterId(_ id: Int) {
        save(key: masterIdKey, value: "\(id)")
    }

    func getMasterId() -> Int? {
        guard let str = load(key: masterIdKey) else { return nil }
        return Int(str)
    }

    var isAuthenticated: Bool { getToken() != nil }

    private func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
