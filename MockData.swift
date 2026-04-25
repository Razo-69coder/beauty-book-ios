import Foundation

// MARK: - Mock Data (для офлайн-разработки и превью)

enum MockData {

    // MARK: - Master

    static let master = MasterProfile(
        id: 1,
        email: "master@beautybook.ru",
        name: "Анна Козлова",
        workStart: 9,
        workEnd: 20,
        slotDuration: 60,
        timezone: "Europe/Moscow",
        reminderDays: 30,
        paymentCard: "4276 1234 5678 9012",
        paymentPhone: "+7 (900) 123-45-67",
        paymentBanks: "Сбер, Тинькофф",
        depositEnabled: true,
        depositPercent: 30,
        theme: "pink"
    )

    // MARK: - Services

    static let services: [Service] = [
        Service(id: 1, name: "Маникюр классический", priceDefault: 1200, durationMin: 60),
        Service(id: 2, name: "Маникюр с покрытием",  priceDefault: 1800, durationMin: 90),
        Service(id: 3, name: "Педикюр классический", priceDefault: 1500, durationMin: 90),
        Service(id: 4, name: "Педикюр с покрытием",  priceDefault: 2200, durationMin: 120),
        Service(id: 5, name: "Наращивание ногтей",   priceDefault: 3500, durationMin: 180),
        Service(id: 6, name: "Коррекция",             priceDefault: 2000, durationMin: 120),
    ]

    // MARK: - Clients

    static let clients: [Client] = [
        Client(id: 1, name: "Мария Иванова",    phone: "+7 (916) 234-56-78", notes: "Аллергия на акрил", lastVisit: "2026-04-20", username: "maria_i",   telegramId: nil),
        Client(id: 2, name: "Елена Смирнова",   phone: "+7 (903) 345-67-89", notes: "",                   lastVisit: "2026-04-15", username: "lena_s",    telegramId: nil),
        Client(id: 3, name: "Ольга Петрова",    phone: "+7 (925) 456-78-90", notes: "VIP клиент",         lastVisit: "2026-04-18", username: nil,          telegramId: nil),
        Client(id: 4, name: "Дарья Козлова",    phone: "+7 (977) 567-89-01", notes: "",                   lastVisit: "2026-03-30", username: "dasha_k",   telegramId: nil),
        Client(id: 5, name: "Анастасия Новикова",phone: "+7 (915) 678-90-12",notes: "Нравятся пастель",   lastVisit: "2026-04-22", username: nil,          telegramId: nil),
        Client(id: 6, name: "Виктория Орлова",  phone: "+7 (926) 789-01-23", notes: "",                   lastVisit: "2026-04-10", username: "vika_o",    telegramId: nil),
    ]

    // MARK: - Appointments (today)

    static func appointments(for date: String = todayString) -> [Appointment] {
        [
            Appointment(id: 1, clientId: 1, masterId: 1, procedure: "Маникюр с покрытием",  appointmentDate: date, time: "09:00", price: 1800, notes: "",         status: .confirmed,  depositStatus: .paid,        depositAmount: 540, clientName: "Мария Иванова",     clientPhone: "+7 (916) 234-56-78", serviceDoneAt: nil),
            Appointment(id: 2, clientId: 2, masterId: 1, procedure: "Педикюр классический", appointmentDate: date, time: "11:00", price: 1500, notes: "Первый раз",status: .confirmed,  depositStatus: .notRequired, depositAmount: 0,   clientName: "Елена Смирнова",    clientPhone: "+7 (903) 345-67-89", serviceDoneAt: nil),
            Appointment(id: 3, clientId: 3, masterId: 1, procedure: "Наращивание ногтей",   appointmentDate: date, time: "13:00", price: 3500, notes: "",         status: .pending,    depositStatus: .pendingPayment,depositAmount: 1050,clientName: "Ольга Петрова",     clientPhone: "+7 (925) 456-78-90", serviceDoneAt: nil),
            Appointment(id: 4, clientId: 4, masterId: 1, procedure: "Коррекция",            appointmentDate: date, time: "16:00", price: 2000, notes: "",         status: .completed,  depositStatus: .notRequired, depositAmount: 0,   clientName: "Дарья Козлова",     clientPhone: "+7 (977) 567-89-01", serviceDoneAt: date),
        ]
    }

    static var todayString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    // MARK: - History

    static func history(for clientId: Int) -> [AppointmentHistory] {
        [
            AppointmentHistory(procedure: "Маникюр с покрытием",  appointmentDate: "2026-04-20", price: 1800, notes: ""),
            AppointmentHistory(procedure: "Педикюр классический", appointmentDate: "2026-03-15", price: 1500, notes: "Доволен"),
            AppointmentHistory(procedure: "Маникюр с покрытием",  appointmentDate: "2026-02-28", price: 1800, notes: ""),
            AppointmentHistory(procedure: "Наращивание ногтей",   appointmentDate: "2026-01-10", price: 3200, notes: "Гель"),
        ]
    }

    // MARK: - Stats

    static let stats = StatsResponse(
        totalClients: 34,
        totalAppointments: 187,
        totalEarnings: 324500,
        monthEarnings: 42800,
        topProcedures: [
            TopProcedure(procedure: "Маникюр с покрытием",  count: 68),
            TopProcedure(procedure: "Педикюр классический", count: 41),
            TopProcedure(procedure: "Наращивание ногтей",   count: 28),
        ]
    )

    static let earningsByDay: [(String, Int)] = {
        let calendar = Calendar.current
        let today = Date()
        let amounts = [1200, 3400, 0, 2800, 5200, 1800, 4100, 2200, 3600, 0, 4800, 1500, 3900, 2700]
        return (0..<14).reversed().map { (offset: Int) -> (String, Int) in
            let d = calendar.date(byAdding: .day, value: -offset, to: today)!
            let f = DateFormatter(); f.dateFormat = "dd.MM"
            return (f.string(from: d), amounts[offset % 14])
        }
    }()
}
