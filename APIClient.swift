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
    case resetPassword(email: String, code: String, newPassword: String)
    // Master
    case me
    case updateSettings(MasterSettingsRequest)
    case updatePayment(PaymentRequest)
    case updateProfile(ProfileUpdateRequest)
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
    case updateAppointment(id: Int, AppointmentUpdateRequest)
    case cancelAppointment(id: Int)
    case markDone(id: Int)
    // Schedule / Slots
    case schedule(date: String)
    case slots(date: String)
    // Services
    case services
    case createService(ServiceCreateRequest)
    case updateService(id: Int, ServiceCreateRequest)
    case deleteService(id: Int)
    case setServiceCorrection(id: Int, ServiceCorrectionRequest)
    // Free windows
    case freeWindows(dateFrom: String, dateTo: String, duration: Int)
    // Broadcasts
    case broadcastPreview(BroadcastPreviewRequest)
    case sendBroadcast(BroadcastSendRequest)
    case broadcasts
    case askBroadcastConsent

    case getBookingLink
    case updateBookingLink(String)
    // Blocked days
    case getBlockedDays
    case addBlockedDay(String)
    case removeBlockedDay(String)
    // Feedback
    case sendFeedback(String)
    // Loyalty
    case updateLoyaltySettings(LoyaltySettingsRequest)
    case telegramLinkToken
    // Status
    case updateAppointmentStatus(id: Int, status: String)
    case statsYearly(year: Int)
    case getReminderTemplates
    case updateReminderTemplate(type: String, template: String, enabled: Bool)
    // Import
    case importClients([ClientImportItem])
    // Merge duplicates
    case mergeDuplicates
    // Notifications
    case notifications
    case unreadCount
    case markRead(id: Int)
    case markAllRead
    // Personal notes
    case getNotes(date: String)
    case createNote(PersonalNoteCreateRequest)
    case deleteNote(id: Int)
    // Waitlist
    case waitlistEntries(dateFrom: String, dateTo: String)
    case removeWaitlistEntry(id: Int)
    // Passes
    case clientPasses(clientId: Int)
    case createPass(clientId: Int, PassCreateRequest)
    case usePass(id: Int)
    case undoPass(id: Int)
    case deletePass(id: Int)
}

extension Endpoint {
    var path: String {
        switch self {
        case .login:                    return "/auth/login"
        case .register:                 return "/auth/register"
        case .forgotPassword:           return "/auth/forgot-password"
        case .resetPassword:            return "/auth/reset-password"
        case .me:                       return "/masters/me"
        case .updateSettings:           return "/masters/me"
        case .updatePayment:            return "/masters/me/payment"
        case .updateProfile:            return "/profile"
        case .stats:                    return "/masters/me/stats"
        case .clients:                  return "/clients"
        case .clientDetail(let id):     return "/clients/\(id)"
        case .createClient:             return "/clients"
        case .updateClient(let id, _):  return "/clients/\(id)"
        case .deleteClient(let id):     return "/clients/\(id)"
        case .appointments:             return "/appointments"
        case .appointmentDetail(let id): return "/appointments/\(id)"
        case .createAppointment:        return "/appointments"
        case .updateAppointment(let id, _): return "/appointments/\(id)"
        case .cancelAppointment(let id): return "/appointments/\(id)"
        case .markDone(let id):         return "/appointments/\(id)/done"
        case .schedule:                 return "/schedule"
        case .slots:                    return "/slots"
        case .services:                 return "/services"
        case .createService:            return "/services"
        case .updateService(let id, _): return "/services/\(id)"
        case .deleteService(let id):    return "/services/\(id)"
        case .setServiceCorrection(let id, _): return "/services/\(id)/correction"
        case .freeWindows:         return "/free-windows"
        case .broadcastPreview:    return "/broadcasts/preview"
        case .sendBroadcast:       return "/broadcasts"
        case .broadcasts:          return "/broadcasts"
        case .askBroadcastConsent: return "/broadcasts/ask-consent"
        case .getBookingLink:           return "/masters/me/booking-link"
        case .updateBookingLink:        return "/masters/booking-link"
        case .getBlockedDays:            return "/schedule/blocked-days"
        case .addBlockedDay:             return "/schedule/blocked-days"
        case .removeBlockedDay(let date): return "/schedule/blocked-days/\(date)"
        case .sendFeedback:              return "/feedback"
        case .updateLoyaltySettings:     return "/loyalty-settings"
        case .telegramLinkToken:        return "/telegram-link-token"
        case .updateAppointmentStatus(let id, _): return "/appointments/\(id)/status"
        case .importClients:             return "/clients/import"
        case .statsYearly:              return "/masters/me/stats/yearly"
        case .getReminderTemplates:     return "/reminders/templates"
        case .updateReminderTemplate(let type, _, _): return "/reminders/templates/\(type)"
        case .notifications:            return "/notifications"
        case .unreadCount:              return "/notifications/unread-count"
        case .markRead(let id):         return "/notifications/\(id)/read"
        case .markAllRead:              return "/notifications/read-all"
        case .mergeDuplicates:          return "/clients/merge-duplicates"
        case .getNotes:                 return "/notes"
        case .createNote:               return "/notes"
        case .deleteNote(let id):       return "/notes/\(id)"
        case .waitlistEntries:          return "/waitlist-clients"
        case .removeWaitlistEntry(let id): return "/waitlist-clients/\(id)"
        case .clientPasses(let clientId): return "/clients/\(clientId)/passes"
        case .createPass(let clientId, _): return "/clients/\(clientId)/passes"
        case .usePass(let id):          return "/passes/\(id)/use"
        case .undoPass(let id):         return "/passes/\(id)/undo"
        case .deletePass(let id):       return "/passes/\(id)"
        }
    }

    /// Кэшируются только GET-ответы, из которых экраны берут «последнее загруженное».
    /// fileprivate — читает APIClient из этого же файла.
    fileprivate var OFFIsCacheable: Bool {
        switch self {
        case .schedule, .getNotes, .clients, .services, .appointments, .notifications:
            return true
        default:
            return false
        }
    }

    /// Имя файла кэша: путь + запрос, все не буквенно-цифровые символы → «_»
    fileprivate var OFFCacheFileName: String {
        var raw: String = path
        if let items: [URLQueryItem] = queryItems {
            let query: String = items.compactMap { item in
                guard let value: String = item.value else { return nil }
                return "\(item.name)=\(value)"
            }.joined(separator: "&")
            if !query.isEmpty { raw = raw + "?" + query }
        }
        let allowed: CharacterSet = .alphanumerics
        let safe: String = String(raw.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
        return safe
    }

    var method: String {
        switch self {
        case .login, .register, .forgotPassword, .resetPassword, .sendFeedback,
             .createClient, .createAppointment, .createService, .markDone:
            return "POST"
        case .updateSettings, .updatePayment, .updateProfile, .updateClient, .updateBookingLink, .updateLoyaltySettings, .updateAppointment, .updateService:
            return "PUT"
        case .deleteClient, .cancelAppointment, .deleteService:
            return "DELETE"
        case .addBlockedDay:   return "POST"
        case .mergeDuplicates: return "POST"
        case .removeBlockedDay: return "DELETE"
        case .createNote:       return "POST"
        case .deleteNote:       return "DELETE"
        case .telegramLinkToken: return "GET"
        case .updateAppointmentStatus: return "PATCH"
        case .setServiceCorrection: return "PATCH"
        case .broadcastPreview, .sendBroadcast, .askBroadcastConsent: return "POST"
        case .importClients: return "POST"
        case .markRead, .markAllRead: return "POST"
        case .notifications, .unreadCount: return "GET"
        case .updateReminderTemplate: return "PUT"
        case .createPass, .usePass, .undoPass: return "POST"
        case .removeWaitlistEntry, .deletePass: return "DELETE"
        case .clientPasses: return "GET"
        default:
            return "GET"
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .register, .forgotPassword, .resetPassword: return false
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
        case .getNotes(let date): return [URLQueryItem(name: "date", value: date)]
        case .waitlistEntries(let dateFrom, let dateTo):
            return [
                URLQueryItem(name: "date_from", value: dateFrom),
                URLQueryItem(name: "date_to", value: dateTo)
            ]
        case .freeWindows(let dateFrom, let dateTo, let duration):
            return [
                URLQueryItem(name: "date_from", value: dateFrom),
                URLQueryItem(name: "date_to", value: dateTo),
                URLQueryItem(name: "duration", value: "\(duration)")
            ]
        case .statsYearly(let year):
            return [URLQueryItem(name: "year", value: "\(year)")]
        default: return nil
        }
    }

    var body: Data? {
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
        switch self {
        case .login(let r):               return try? encoder.encode(r)
        case .register(let r):            return try? encoder.encode(r)
        case .forgotPassword(let email):  return try? encoder.encode(["email": email])
        case .resetPassword(let email, let code, let newPassword): return try? encoder.encode(["email": email, "code": code, "new_password": newPassword])
        case .sendFeedback(let text):    return try? encoder.encode(["text": text])
        case .updateSettings(let r):      return try? encoder.encode(r)
        case .updatePayment(let r):       return try? encoder.encode(r)
        case .updateProfile(let r):     return try? encoder.encode(r)
        case .createClient(let r):        return try? encoder.encode(r)
        case .updateClient(_, let r):     return try? encoder.encode(r)
        case .createAppointment(let r):   return try? encoder.encode(r)
        case .updateAppointment(_, let r): return try? encoder.encode(r)
        case .createService(let r):       return try? encoder.encode(r)
        case .updateService(_, let r):    return try? encoder.encode(r)
        case .setServiceCorrection(_, let r): return try? encoder.encode(r)
        case .broadcastPreview(let r): return try? encoder.encode(r)
        case .sendBroadcast(let r):    return try? encoder.encode(r)
        case .updateBookingLink(let link): return try? encoder.encode(["link": link])
        case .addBlockedDay(let date): return try? encoder.encode(["date": date])
        case .updateLoyaltySettings(let r): return try? encoder.encode(r)
        case .updateAppointmentStatus(_, let status):
            return try? JSONEncoder().encode(["status": status])
        case .importClients(let items):
            return try? encoder.encode(ClientImportRequest(clients: items))
        case .updateReminderTemplate(_, let template, let enabled):
            return try? encoder.encode(ReminderTemplateUpdate(template: template, enabled: enabled))
        case .createNote(let r):
            return try? encoder.encode(r)
        case .createPass(_, let r):
            return try? encoder.encode(r)
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
    private let encoder: JSONEncoder

    /// Нет интернета и показываем сохранённые данные
    @Published private(set) var isOffline: Bool = false

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = APIConfig.timeout
        session = URLSession(configuration: cfg)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func request<T: Decodable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let req = try buildRequest(endpoint)
        let cacheable: Bool = endpoint.OFFIsCacheable

        var data: Data
        var response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            // Отмена задачи (переключение даты) — это не офлайн
            guard !Task.isCancelled, OFFIsOffline(urlError.code) else { throw urlError }
            // Есть сохранённый ответ — отдаём его, экран остаётся живым
            if cacheable, let cached: Data = OFFReadCache(for: endpoint) {
                isOffline = true
                do { return try decoder.decode(T.self, from: cached) }
                catch { throw NetworkError.decodingError(error) }
            }
            isOffline = true
            throw NetworkError.noConnection
        }

        guard let http = response as? HTTPURLResponse else { throw NetworkError.noData }

        switch http.statusCode {
        case 200...299:
            // Свежие данные — обновляем кэш и снимаем режим офлайна
            if cacheable {
                OFFWriteCache(data, for: endpoint)
                isOffline = false
            }
            do { return try decoder.decode(T.self, from: data) }
            catch { throw NetworkError.decodingError(error) }
        case 401:
            switch endpoint {
            case .login, .register, .forgotPassword, .resetPassword:
                // Не залогинен ещё — 401 здесь значит "неверный email/пароль",
                // а не "токен истёк". Показываем реальное сообщение сервера.
                let body = try? JSONDecoder().decode([String: String].self, from: data)
                let msg = body?["detail"] ?? "Неверный email или пароль"
                throw NetworkError.serverError(http.statusCode, msg)
            default:
                NotificationCenter.default.post(name: .tokenExpired, object: nil)
                throw NetworkError.unauthorized
            }
        case 403:
            let body = try? JSONDecoder().decode([String: String].self, from: data)
            let msg = body?["detail"] ?? "Доступ запрещён"
            throw NetworkError.serverError(http.statusCode, msg)
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

    func updateAppointmentStatus(id: Int, status: AppointmentStatus) async throws -> MessageResponse {
        return try await request(.updateAppointmentStatus(id: id, status: status.rawValue), as: MessageResponse.self)
    }

    func importClients(_ items: [ClientImportItem]) async throws -> ClientImportResponse {
        return try await request(.importClients(items), as: ClientImportResponse.self)
    }
}

struct APIErrorResponse: Decodable { let detail: String }

extension APIClient {
    /// При выходе из аккаунта сохранённые данные больше не нужны
    func OFFClearCache() {
        guard let dir: URL = OFFCacheDirectory else { return }
        try? FileManager.default.removeItem(at: dir)
        isOffline = false
    }
}

// MARK: - Офлайн-кэш

/// Сеть недоступна — значит работаем с сохранёнными данными
private func OFFIsOffline(_ code: URLError.Code) -> Bool {
    switch code {
    case .notConnectedToInternet, .networkConnectionLost, .timedOut,
         .cannotConnectToHost, .cannotFindHost:
        return true
    default:
        return false
    }
}

/// Папка кэша в Caches: OFFCache
private var OFFCacheDirectory: URL? {
    guard let base: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        return nil
    }
    return base.appendingPathComponent("OFFCache", isDirectory: true)
}

/// Сохраняем сырые байты ответа — модели не перекодируем
private func OFFWriteCache(_ data: Data, for endpoint: Endpoint) {
    guard let dir: URL = OFFCacheDirectory else { return }
    let fileURL: URL = dir.appendingPathComponent(endpoint.OFFCacheFileName)
    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    } catch {
        // Не смогли записать кэш — работаем как раньше, молча
    }
}

/// Последний успешный ответ по этому запросу, если он есть
private func OFFReadCache(for endpoint: Endpoint) -> Data? {
    guard let dir: URL = OFFCacheDirectory else { return nil }
    let fileURL: URL = dir.appendingPathComponent(endpoint.OFFCacheFileName)
    return try? Data(contentsOf: fileURL)
}

// MARK: - Expenses Extension
extension APIClient {
    func fetchExpenses() async throws -> [Expense] {
        let data = try await get("/expenses")
        return try decoder.decode(ExpensesResponse.self, from: data).expenses
    }

    func addExpense(_ expense: ExpenseCreateRequest) async throws -> Int {
        let body = try encoder.encode(expense)
        let data = try await post("/expenses", body: body)
        struct R: Decodable { let id: Int }
        return try decoder.decode(R.self, from: data).id
    }

    func deleteExpense(id: Int) async throws {
        _ = try await delete("/expenses/\(id)")
    }
    
    func earningsByDay(days: Int) async throws -> [EarningsDay] {
        let data = try await get("/masters/me/stats/earnings-by-day?days=\(days)")
        return try JSONDecoder().decode(EarningsByDayResponse.self, from: data).days
    }

    func earningsByRange(start: String, end: String) async throws -> [EarningsDay] {
        let data = try await get("/masters/me/stats/earnings-by-range?start=\(start)&end=\(end)")
        return try JSONDecoder().decode(EarningsByDayResponse.self, from: data).days
    }

    func telegramLinkToken() async throws -> (token: String, botUsername: String) {
        let data = try await get("/telegram-link-token")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String] ?? [:]
        return (json["token"] ?? "", json["bot_username"] ?? "")
    }

    private func get(_ path: String) async throws -> Data {
        let url = URL(string: APIConfig.baseURL + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainManager.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.noData }
        guard 200...299 ~= http.statusCode else { throw NetworkError.serverError(http.statusCode, "GET failed") }
        return data
    }
    
    private func post(_ path: String, body: Data) async throws -> Data {
        let url = URL(string: APIConfig.baseURL + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = body
        if let token = KeychainManager.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.noData }
        guard 200...299 ~= http.statusCode else { throw NetworkError.serverError(http.statusCode, "POST failed") }
        return data
    }
    
    func fetchCustomSlots(month: String) async throws -> [String: [String]] {
        let data = try await get("/schedule/custom-slots?month=\(month)")
        return (try? JSONDecoder().decode(CustomSlotsMonthResponse.self, from: data).slots) ?? [:]
    }

    func addCustomSlot(date: String, time: String) async throws {
        let body = try encoder.encode(CustomSlotRequest(date: date, time: time))
        _ = try await post("/schedule/custom-slots", body: body)
    }

    func removeCustomSlot(date: String, time: String) async throws {
        let url = URL(string: APIConfig.baseURL + "/schedule/custom-slots")!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(CustomSlotRequest(date: date, time: time))
        if let token = KeychainManager.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw NetworkError.serverError(0, "DELETE custom slot failed")
        }
    }

    private func delete(_ path: String) async throws -> Data {
        let url = URL(string: APIConfig.baseURL + path)!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainManager.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.noData }
        guard 200...299 ~= http.statusCode else { throw NetworkError.serverError(http.statusCode, "DELETE failed") }
        return data
    }
}

// MARK: - Импорт клиентов из файла

extension APIClient {
    /// Граница multipart-формы для одного файла
    private static let CIMaxFileSize: Int = 5 * 1024 * 1024

    /// Загружает .xlsx или .csv на разбор. Сервер ничего не сохраняет —
    /// отдаёт предпросмотр строк. Сохранение делает importClients.
    func CIUploadClientsFile(data: Data, filename: String) async throws -> CIFileParseResponse {
        guard let url = URL(string: APIConfig.baseURL + "/clients/import-file") else {
            throw NetworkError.invalidURL
        }

        let boundary: String = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token: String = KeychainManager.shared.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = CIMultipartBody(boundary: boundary, filename: filename, data: data)

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            guard !Task.isCancelled, OFFIsOffline(urlError.code) else { throw urlError }
            isOffline = true
            throw NetworkError.noConnection
        }

        guard let http: HTTPURLResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }

        if 200...299 ~= http.statusCode {
            isOffline = false
            do { return try decoder.decode(CIFileParseResponse.self, from: responseData) }
            catch { throw NetworkError.decodingError(error) }
        }
        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .tokenExpired, object: nil)
            throw NetworkError.unauthorized
        }
        let detail: String = (try? decoder.decode(APIErrorResponse.self, from: responseData))?.detail
            ?? "Ошибка сервера"
        throw NetworkError.serverError(http.statusCode, detail)
    }

    /// Больше 5 МБ сервер не примет — проверяем на устройстве, без запроса
    static func CIFileIsTooLarge(byteCount: Int) -> Bool {
        return byteCount > CIMaxFileSize
    }
}

/// Тело multipart-запроса: одно поле file с байтами файла
private func CIMultipartBody(boundary: String, filename: String, data: Data) -> Data {
    var body: Data = Data()
    let crlf: String = "\r\n"

    let head: String = "--\(boundary)\(crlf)"
        + "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(crlf)"
        + "Content-Type: application/octet-stream\(crlf)\(crlf)"
    body.append(Data(head.utf8))
    body.append(data)
    body.append(Data("\(crlf)--\(boundary)--\(crlf)".utf8))
    return body
}
