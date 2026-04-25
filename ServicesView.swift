import SwiftUI

// MARK: - Services ViewModel

@MainActor
final class ServicesViewModel: ObservableObject {
    @Published var services: [Service]  = []
    @Published var isLoading            = false
    @Published var errorMessage: String? = nil
    @Published var showAddSheet         = false

    private let api = APIClient.shared

    func load() async {
        isLoading = true
        do {
            let resp = try await api.request(.services, as: ServicesResponse.self)
            services = resp.services
        } catch {
            // Фолбэк на мок-данные если нет сети
            services = MockData.services
        }
        isLoading = false
    }

    func delete(service: Service) async {
        services.removeAll { $0.id == service.id }
        do {
            let _ = try await api.request(.deleteService(id: service.id), as: MessageResponse.self)
        } catch {
            services.append(service) // откат
        }
    }

    func add(name: String, price: Int, duration: Int) async {
        let req = ServiceCreateRequest(name: name, priceDefault: price, durationMin: duration)
        do {
            let _ = try await api.request(.createService(req), as: MessageResponse.self)
            await load()
        } catch {
            // Оптимистичное добавление с временным id
            let temp = Service(id: Int.random(in: 10000...99999), name: name, priceDefault: price, durationMin: duration)
            services.append(temp)
        }
    }
}

// MARK: - Services View

struct ServicesView: View {
    @StateObject private var vm = ServicesViewModel()
    @Environment(\.theme) private var theme
    @State private var showAdd = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            theme.backgroundDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if vm.isLoading {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    Spacer()
                } else if vm.services.isEmpty {
                    emptyState
                } else {
                    servicesList
                }
            }

            // FAB
            Button(action: { showAdd = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(theme.gradientPrimary)
                    .clipShape(Circle())
                    .shadow(color: theme.accentGlow, radius: 12, x: 0, y: 6)
            }
            .padding(.bottom, 100)
            .padding(.trailing, 20)
        }
        .task { await vm.load() }
        .sheet(isPresented: $showAdd) {
            AddServiceSheet(vm: vm)
                .environment(\.theme, theme)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Услуги")
                    .font(DS.titleSmall)
                    .foregroundColor(theme.textPrimary)
                Text("\(vm.services.count) услуг")
                    .font(DS.body)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.s20)
        .padding(.top, DS.s16)
        .padding(.bottom, DS.s16)
    }

    private var servicesList: some View {
        List {
            ForEach(vm.services) { service in
                ServiceRow(service: service, theme: theme)
                    .listRowBackground(theme.backgroundCard)
                    .listRowSeparatorTint(theme.borderSubtle)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await vm.delete(service: service) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.backgroundDeep)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "scissors")
                .font(.system(size: 48))
                .foregroundColor(theme.textMuted)
            Text("Нет услуг")
                .font(DS.headline)
                .foregroundColor(theme.textPrimary)
            Text("Добавь услуги, которые ты оказываешь,\nи они появятся при создании записи")
                .font(DS.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, DS.s32)
    }
}

// MARK: - Service Row

struct ServiceRow: View {
    let service: Service
    let theme: AppTheme

    var body: some View {
        HStack(spacing: DS.s12) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.r8)
                    .fill(theme.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(DS.label)
                    .foregroundColor(theme.textPrimary)
                HStack(spacing: 8) {
                    Label("\(service.durationMin) мин", systemImage: "clock")
                        .font(DS.bodySmall)
                        .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()

            Text("\(service.priceDefault)₽")
                .font(DS.headline)
                .foregroundColor(theme.accent)
        }
        .padding(.vertical, DS.s8)
    }
}

// MARK: - Add Service Sheet

struct AddServiceSheet: View {
    @ObservedObject var vm: ServicesViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name     = ""
    @State private var priceStr = ""
    @State private var durStr   = "60"

    private var isValid: Bool { !name.isEmpty && !priceStr.isEmpty }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundDeep.ignoresSafeArea()
                VStack(spacing: DS.s16) {
                    BBTextField(placeholder: "Название услуги", text: $name).environment(\.theme, theme)
                    HStack(spacing: DS.s12) {
                        BBTextField(placeholder: "Цена (₽)", text: $priceStr, keyboardType: .numberPad).environment(\.theme, theme)
                        BBTextField(placeholder: "Мин.", text: $durStr, keyboardType: .numberPad).environment(\.theme, theme)
                    }
                    BBPrimaryButton(title: "Добавить", isDisabled: !isValid) {
                        let price = Int(priceStr) ?? 0
                        let dur   = Int(durStr)   ?? 60
                        Task { await vm.add(name: name, price: price, duration: dur) }
                        dismiss()
                    }.environment(\.theme, theme)
                    Spacer()
                }
                .padding(DS.s20)
            }
            .navigationTitle("Новая услуга")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundColor(theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ServicesView().environment(\.theme, .pink)
}
