import Foundation

// MARK: - Config

enum APIConfig {
    static let baseURL = "https://beauty-bot-44ou.onrender.com/api/v1"
    static let timeout: TimeInterval = 30
}

// MARK: - Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String)
    case unauthorized
    case noConnection

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Неверный URL"
        case .noData:                  return "Нет данных от сервера"
        case .decodingError(let e):    return "Ошибка данных: \(e.localizedDescription)"
        case .serverError(let c, let m): return "Ошибка \(c): \(m)"
        case .unauthorized:            return "Требуется авторизация"
        case .noConnection:            return "Нет соединения с интернетом"
        }
    }
}

// MARK: - Endpoints

enum Endpoint {
    // Auth
    case login(LoginRequest)
    case register(RegisterRequest)
    case forgotPassword(email: String)
    // Master
    case me
    case updateSettings(MasterSettingsRequest)
    case updatePayment(PaymentRequest)
    case stats
    // Clients
    case clients(page: Int, search: String)
    case clientDetail(id: Int)
    case createClient(ClientCreateRequest)
    case updateClient(id: Int, ClientUpdateRequest)
    case deleteClient(id: Int)
    // Appointments
    case appointments(date: String?, status: String?)
    case appointmentDetail(id: Int)
    case createAppointment(AppointmentCreateRequest)
    case cancelAppointment(id: Int)
    case markDone(id: Int)
    // Schedule / Slots
    case schedule(date: String)
    case slots(date: String)
    // Services
    case services
    case createService(ServiceCreateRequest)
    case deleteService(id: Int)
}

extension Endpoint {
    var path: String {
        switch self {
        case .login:                    return "/auth/login"
        case .register:                 return "/auth/register"
        case .forgotPassword:           return "/auth/forgot-password"
        case .me:                       return "/masters/me"
        case .updateSettings:           return "/masters/me"
        case .updatePayment:            return "/masters/me/payment"
        case .stats:                    return "/masters/me/stats"
        case .clients:                  return "/clients"
        case .clientDetail(let id):     return "/clients/\(id)"
        case .createClient:             return "/clients"
        case .updateClient(let id, _):  return "/clients/\(id)"
        case .deleteClient(let id):     return "/clients/\(id)"
        case .appointments:             return "/appointments"
        case .appointmentDetail(let id): return "/appointments/\(id)"
        case .createAppointment:        return "/appointments"
        case .cancelAppointment(let id): return "/appointments/\(id)"
        case .markDone(let id):         return "/appointments/\(id)/done"
        case .schedule:                 return "/schedule"
        case .slots:                    return "/slots"
        case .services:                 return "/services"
        case .createService:            return "/services"
        case .deleteService(let id):    return "/services/\(id)"
        }
    }

    var method: String {
        switch self {
        case .login, .register, .forgotPassword,
             .createClient, .createAppointment, .createService, .markDone:
            return "POST"
        case .updateSettings, .updatePayment, .updateClient:
            return "PUT"
        case .deleteClient, .cancelAppointment, .deleteService:
            return "DELETE"
        default:
            return "GET"
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .register, .forgotPassword: return false
        default: return true
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .clients(let page, let search):
            var items = [URLQueryItem(name: "page", value: "\(page)")]
            if !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
            return items
        case .appointments(let date, let status):
            var items: [URLQueryItem] = []
            if let d = date   { items.append(URLQueryItem(name: "date",   value: d)) }
            if let s = status { items.append(URLQueryItem(name: "status", value: s)) }
            return items.isEmpty ? nil : items
        case .schedule(let date): return [URLQueryItem(name: "date", value: date)]
        case .slots(let date):    return [URLQueryItem(name: "date", value: date)]
        default: return nil
        }
    }

    var body: Data? {
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
        switch self {
        case .login(let r):               return try? encoder.encode(r)
        case .register(let r):            return try? encoder.encode(r)
        case .forgotPassword(let email):  return try? encoder.encode(["email": email])
        case .updateSettings(let r):      return try? encoder.encode(r)
        case .updatePayment(let r):       return try? encoder.encode(r)
        case .createClient(let r):        return try? encoder.encode(r)
        case .updateClient(_, let r):     return try? encoder.encode(r)
        case .createAppointment(let r):   return try? encoder.encode(r)
        case .createService(let r):       return try? encoder.encode(r)
        default: return nil
        }
    }
}

// MARK: - API Client

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = APIConfig.timeout
        session = URLSession(configuration: cfg)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let req = try buildRequest(endpoint)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.noData }

        switch http.statusCode {
        case 200...299:
            do { return try decoder.decode(T.self, from: data) }
            catch { throw NetworkError.decodingError(error) }
        case 401:
            NotificationCenter.default.post(name: .tokenExpired, object: nil)
            throw NetworkError.unauthorized
        default:
            let msg = (try? decoder.decode(APIErrorResponse.self, from: data))?.detail ?? "Ошибка сервера"
            throw NetworkError.serverError(http.statusCode, msg)
        }
    }

    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        guard var components = URLComponents(string: APIConfig.baseURL + endpoint.path) else {
            throw NetworkError.invalidURL
        }
        components.queryItems = endpoint.queryItems
        guard let url = components.url else { throw NetworkError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.requiresAuth, let token = KeychainManager.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = endpoint.body
        return req
    }
}

struct APIErrorResponse: Decodable { let detail: String }
