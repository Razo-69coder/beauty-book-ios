import Foundation

enum APIConfig {
    static let baseURL = "https://beauty-bot-44ou.onrender.com/api/v1"
    static let timeout: TimeInterval = 30
}

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String)
    case unauthorized
    case noConnection

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "Неверный URL"
        case .noData:            return "Нет данных"
        case .decodingError(let e): return "Ошибка данных: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Ошибка \(code): \(msg)"
        case .unauthorized:      return "Требуется авторизация"
        case .noConnection:      return "Нет соединения с интернетом"
        }
    }
}

enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case delete = "DELETE"
    case patch  = "PATCH"
}

protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var requiresAuth: Bool { get }
    var body: Data? { get }
    var queryParams: [String: String]? { get }
}

extension APIEndpoint {
    var requiresAuth: Bool { true }
    var body: Data? { nil }
    var queryParams: [String: String]? { nil }
}

enum Endpoint: APIEndpoint {
    case login(email: String, password: String)
    case verifyCode(email: String, code: String)
    case resendCode(email: String)
    case requestCode(telegramId: Int)
    case verifyCodeOld(telegramId: Int, code: String)
    case me
    case updateSettings(MasterSettingsRequest)
    case updatePayment(PaymentRequest)
    case stats
    case clients(page: Int, search: String)
    case clientDetail(id: Int)
    case createClient(ClientCreateRequest)
    case updateClient(id: Int, ClientUpdateRequest)
    case deleteClient(id: Int)
    case appointments(date: String?, status: String?)
    case appointmentDetail(id: Int)
    case createAppointment(AppointmentCreateRequest)
    case updateAppointment(id: Int, AppointmentUpdateRequest)
    case cancelAppointment(id: Int)
    case markDone(id: Int)
    case schedule(date: String)
    case slots(date: String)
    case services
    case createService(ServiceCreateRequest)
    case deleteService(id: Int)

    var path: String {
        switch self {
        case .login:                return "/auth/login"
        case .verifyCode:           return "/auth/verify"
        case .resendCode:          return "/auth/resend"
        case .requestCode:         return "/auth/request-code"
        case .verifyCodeOld:       return "/auth/verify"
        case .me:                  return "/masters/me"
        case .updateSettings:       return "/masters/me"
        case .updatePayment:        return "/masters/me/payment"
        case .stats:              return "/masters/me/stats"
        case .clients:             return "/clients"
        case .clientDetail(let id): return "/clients/\(id)"
        case .createClient:         return "/clients"
        case .updateClient(let id, _): return "/clients/\(id)"
        case .deleteClient(let id): return "/clients/\(id)"
        case .appointments:         return "/appointments"
        case .appointmentDetail(let id): return "/appointments/\(id)"
        case .createAppointment:  return "/appointments"
        case .updateAppointment(let id, _): return "/appointments/\(id)"
        case .cancelAppointment(let id): return "/appointments/\(id)"
        case .markDone(let id):  return "/appointments/\(id)/done"
        case .schedule:          return "/schedule"
        case .slots:             return "/slots"
        case .services:          return "/services"
        case .createService:     return "/services"
        case .deleteService(let id): return "/services/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .verifyCode, .resendCode, .requestCode, .verifyCodeOld,
             .createClient, .createAppointment, .createService, .markDone:
            return .post
        case .updateSettings, .updatePayment, .updateClient, .updateAppointment:
            return .put
        case .deleteClient, .cancelAppointment, .deleteService:
            return .delete
        default:
            return .get
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .verifyCode, .resendCode, .requestCode, .verifyCodeOld: return false
        default: return true
        }
    }

    var body: Data? {
        switch self {
        case .login(let email, let password):
            let body: [String: Any] = ["email": email, "password": password]
            return try? JSONSerialization.data(withJSONObject: body)
        case .verifyCode(let email, let code):
            let body: [String: Any] = ["email": email, "code": code]
            return try? JSONSerialization.data(withJSONObject: body)
        case .resendCode(let email):
            let body: [String: Any] = ["email": email]
            return try? JSONSerialization.data(withJSONObject: body)
        case .requestCode(let tgId):
            let body: [String: Any] = ["telegram_id": tgId]
            return try? JSONSerialization.data(withJSONObject: body)
        case .verifyCodeOld(let tgId, let code):
            let body: [String: Any] = ["telegram_id": tgId, "code": code]
            return try? JSONSerialization.data(withJSONObject: body)
        case .updateSettings(let req):
            return try? JSONEncoder().encode(req)
        case .updatePayment(let req):
            return try? JSONEncoder().encode(req)
        case .createClient(let req):
            return try? JSONEncoder().encode(req)
        case .updateClient(_, let req):
            return try? JSONEncoder().encode(req)
        case .createAppointment(let req):
            return try? JSONEncoder().encode(req)
        case .updateAppointment(_, let req):
            return try? JSONEncoder().encode(req)
        case .createService(let req):
            return try? JSONEncoder().encode(req)
        default: return nil
        }
    }

    var queryParams: [String: String]? {
        switch self {
        case .clients(let page, let search):
            var params: [String: String] = ["page": "\(page)"]
            if !search.isEmpty { params["search"] = search }
            return params
        case .appointments(let date, let status):
            var params: [String: String] = [:]
            if let date { params["date"] = date }
            if let status { params["status"] = status }
            return params.isEmpty ? nil : params
        case .schedule(let date):  return ["date": date]
        case .slots(let date):     return ["date": date]
        default: return nil
        }
    }
}

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(_ endpoint: Endpoint, type: T.Type = T.self) async throws -> T {
        let urlRequest = try buildRequest(endpoint)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        case 401:
            NotificationCenter.default.post(name: .tokenExpired, object: nil)
            throw NetworkError.unauthorized
        default:
            let message = (try? decoder.decode(APIError.self, from: data))?.detail ?? "Неизвестная ошибка"
            throw NetworkError.serverError(httpResponse.statusCode, message)
        }
    }

    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        guard var components = URLComponents(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }

        if let params = endpoint.queryParams {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if endpoint.requiresAuth, let token = KeychainManager.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = body
        }

        return request
    }
}

extension APIClient {
    func getMe() async throws -> MasterProfile {
        try await request(.me, type: MasterProfile.self)
    }

    func getClients(page: Int = 0, search: String = "") async throws -> ClientsResponse {
        try await request(.clients(page: page, search: search), type: ClientsResponse.self)
    }

    func getSchedule(date: String) async throws -> ScheduleResponse {
        try await request(.schedule(date: date), type: ScheduleResponse.self)
    }

    func getStats() async throws -> StatsResponse {
        try await request(.stats, type: StatsResponse.self)
    }
}

extension Notification.Name {
    static let tokenExpired = Notification.Name("tokenExpired")
}

struct APIError: Decodable {
    let detail: String
}