import SwiftUI
import PhotosUI
import UIKit

struct ClientDetailView: View {
    let client: Client
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var history: [AppointmentHistory] = []
    @State private var photos: [ClientPhoto] = []
    @State private var uiPhotos: [UIImage] = []
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showGalleryPicker = false
    @State private var selectedPhoto: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        Color.clear
            .overlay {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroSection
                        statsSection
                        contactsSection
                        if !history.isEmpty {
                            historySection
                        }
                        photoGallery
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .task {
                isLoading = true
                if let resp = try? await APIClient.shared.request(.clientDetail(id: client.id), as: ClientDetail.self) {
                    history = resp.history
                } else {
                    history = MockData.history(for: client.id)
                }
                photos = MockData.mockPhotos
                uiPhotos = ClientPhotoStorage.load(clientId: client.id)
                isLoading = false
    }
}

struct ClientPhotoStorage {
    static func directory(for clientId: Int) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ClientPhotos/\(clientId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ image: UIImage, clientId: Int) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let file = directory(for: clientId).appendingPathComponent("\(UUID().uuidString).jpg")
        try? data.write(to: file)
    }

    static func load(clientId: Int) -> [UIImage] {
        let dir = directory(for: clientId)
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.compactMap { UIImage(contentsOfFile: $0.path) }
    }
}

    private func formattedBirthday(_ bday: String) -> String {
        let parts = bday.split(separator: "-").map { String($0) }
        guard let monthStr = parts.first,
              let dayStr = parts.dropFirst().first,
              let month = Int(monthStr),
              let day = Int(dayStr) else { return bday }
        let months = ["","Янв","Фев","Мар","Апр","Май","Июн","Июл","Авг","Сен","Окт","Ноя","Дек"]
        guard month >= 1 && month <= 12 else { return bday }
        return "\(day) \(months[month])"
    }

    private func isBirthdayToday(_ bday: String) -> Bool {
        let parts = bday.split(separator: "-").map { String($0) }
        guard let monthStr = parts.first,
              let dayStr = parts.dropFirst().first,
              let month = Int(monthStr),
              let day = Int(dayStr) else { return false }
        let cal = Calendar.current
        let now = Date()
        return cal.component(.month, from: now) == month && cal.component(.day, from: now) == day
    }

    private var initials: String {
        let name = client.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return "?" }
        let first = name[name.startIndex]
        if name.count > 1 {
            if let spaceIdx = name.firstIndex(of: " ") {
                let afterSpace = name.index(after: spaceIdx)
                if afterSpace < name.endIndex {
                    let second = name[afterSpace]
                    return "\(first)\(second)".uppercased()
                }
            }
        }
        return String(first).uppercased()
    }

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(theme.gradientPrimary.opacity(0.15))
                .frame(height: 160)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.gradientPrimary)
                        .frame(width: 72, height: 72)
                        .shadow(color: theme.accentGlow, radius: 16)
                    Text(initials.isEmpty ? "?" : initials)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(client.name)
                    .font(DS.titleSmall)
                    .foregroundColor(theme.textPrimary)
                Text(client.phone)
                    .font(DS.body)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.bottom, 20)
        }
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(visitsCount)", label: "Визитов")
            StatTile(value: totalRevenue, label: "Выручка")
            StatTile(value: lastVisitDate, label: "Последний визит")
        }
        .padding(.horizontal, 20)
    }

    private var visitsCount: Int {
        client.appointmentsCount ?? history.count
    }

    private var totalRevenue: String {
        let total = history.reduce(0) { $0 + $1.price }
        return total > 0 ? "\(total)₽" : "—"
    }

    private var lastVisitDate: String {
        guard let last = history.first?.appointmentDate else { return "—" }
        return formatShortDate(last)
    }

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "Контакты")

            BBGlassCard {
                VStack(spacing: 12) {
                    ContactRow(icon: "phone.fill", label: "Телефон", value: client.phone, theme: theme)
                    if let username = client.username, !username.isEmpty {
                        Divider().background(theme.borderSubtle)
                        ContactRow(icon: "paperplane.fill", label: "Telegram", value: "@\(username)", theme: theme)
                    }
                    if let bday = client.birthday {
                        Divider().background(theme.borderSubtle).padding(.horizontal, 16)
                        HStack {
                            Image(systemName: "gift")
                                .foregroundColor(theme.accent)
                                .frame(width: 20)
                            Text(formattedBirthday(bday))
                                .font(DS.body)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if isBirthdayToday(bday) {
                                Text("Сегодня! 🎂")
                                    .font(DS.labelSmall)
                                    .foregroundColor(theme.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(theme.accent.opacity(0.15))
                                    .cornerRadius(DS.rFull)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BBSectionHeader(title: "История визитов")

            ForEach(history) { item in
                AppointmentHistoryCard(item: item, theme: theme)
            }
        }
        .padding(.horizontal, 20)
    }

    private var photoGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ФОТО РАБОТ")
                    .font(DS.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button {
                    showPhotoPicker = true
                } label: {
                    Text("+ Добавить")
                        .font(DS.label)
                        .foregroundColor(theme.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.r12)
                                .fill(theme.backgroundInput)
                                .frame(width: 90, height: 120)
                            Image(systemName: "camera")
                                .font(.system(size: 24))
                                .foregroundColor(theme.textMuted)
                        }
                    }
                    .frame(width: 90, height: 120)

                    ForEach(Array(uiPhotos.enumerated()), id: \.offset) { index, image in
                        Button {
                            selectedPhoto = image
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: DS.r12))
                                .shadow(color: theme.accentGlow, radius: 8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .confirmationDialog("Добавить фото", isPresented: $showPhotoPicker) {
            Button("Камера") {
                showCamera = true
            }
            Button("Галерея") {
                showGalleryPicker = true
            }
            Button("Отмена", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                uiPhotos.append(image)
                ClientPhotoStorage.save(image, clientId: client.id)
            }
        }
        .sheet(isPresented: $showGalleryPicker) {
            PHPickerViewWrapper { image in
                uiPhotos.append(image)
                ClientPhotoStorage.save(image, clientId: client.id)
            }
        }
        .sheet(isPresented: .constant(selectedPhoto != nil)) {
            if let photo = selectedPhoto {
                ZStack {
                    theme.backgroundDeep.ignoresSafeArea()
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                selectedPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }

    private func formatShortDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        let f2 = DateFormatter(); f2.dateFormat = "d MMM"; f2.locale = Locale(identifier: "ru_RU")
        return f2.string(from: d)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    @Environment(\.theme) private var theme

    var body: some View {
        BBGlassCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(DS.titleSmall)
                    .foregroundColor(theme.accent)
                Text(label)
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ContactRow: View {
    let icon: String
    let label: String
    let value: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DS.caption)
                    .foregroundColor(theme.textMuted)
                Text(value)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
            }
            Spacer()
        }
    }
}

struct AppointmentHistoryCard: View {
    let item: AppointmentHistory
    let theme: AppTheme

    private var statusColor: Color {
        switch (item.status ?? "").lowercased() {
        case "completed": return theme.statusGreen
        case "cancelled": return theme.statusRed
        default: return theme.statusYellow
        }
    }

    private func formatDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        let f2 = DateFormatter(); f2.dateFormat = "d MMM yyyy"; f2.locale = Locale(identifier: "ru_RU")
        return f2.string(from: d)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.procedure)
                        .font(DS.headline)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(item.time)
                        .font(DS.labelSmall)
                        .foregroundColor(theme.textMuted)
                }

                HStack(spacing: 6) {
                    Text(formatDate(item.appointmentDate))
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textMuted)
                    Spacer()
                    Text("\(item.price)₽")
                        .font(DS.label)
                        .foregroundColor(theme.accent)
                }
            }
            .padding(16)
        }
        .background(theme.backgroundCard)
        .cornerRadius(DS.r16)
        .overlay(
            RoundedRectangle(cornerRadius: DS.r16)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

#Preview {
    ClientDetailView(client: MockData.clients[0])
        .environment(\.theme, .pink)
}

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct PHPickerViewWrapper: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerViewWrapper
        init(_ parent: PHPickerViewWrapper) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                if let img = image as? UIImage {
                    DispatchQueue.main.async { self.parent.onImagePicked(img) }
                }
            }
        }
    }
}