import SwiftUI

// MARK: - AuthView (главный контейнер)

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            // Фон с градиентом
            Color(hex: "#080810").ignoresSafeArea()
            backgroundGlow

            VStack(spacing: 0) {
                // Логотип
                logoSection
                    .padding(.top, 80)
                    .padding(.bottom, 48)

                // Контент по шагу
                Group {
                    switch viewModel.step {
                    case .enterTelegramId:
                        TelegramIdStep(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .enterCode:
                        CodeStep(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .authenticated:
                        EmptyView() // TabBarView подхватит через AppState
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.step.id)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 16) {
            // Иконка
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FF2D78"), Color(hex: "#FF006E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "#FF2D78").opacity(0.5), radius: 20, x: 0, y: 8)

                Text("✿")
                    .font(.system(size: 36))
            }

            VStack(spacing: 6) {
                Text("Beauty Book")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Твоя студия в кармане")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "#A0A0C0"))
            }
        }
        .scaleEffect(logoScale)
        .opacity(logoOpacity)
    }

    // MARK: - Background glow

    private var backgroundGlow: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#FF2D78").opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color(hex: "#FF006E").opacity(0.08))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 120, y: 100)
        }
    }
}

// MARK: - Step 1: Telegram ID

struct TelegramIdStep: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Заголовок
            VStack(spacing: 8) {
                Text("Войти в аккаунт")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Введи свой Telegram ID.\nКод для входа придёт в бот.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#A0A0C0"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Поле ввода
            BBTextField(
                placeholder: "Telegram ID (например, 550421233)",
                text: $viewModel.telegramIdText,
                keyboardType: .numberPad,
                isValid: viewModel.telegramIdValid || viewModel.telegramIdText.isEmpty
            )

            // Ошибка
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Кнопка
            BBButton(
                title: "Получить код",
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.canRequestCode
            ) {
                Task { await viewModel.requestCode() }
            }

            // Подсказка как узнать ID
            TelegramIdHint()
        }
    }
}

// MARK: - Step 2: Код

struct CodeStep: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Кнопка назад
            HStack {
                Button(action: viewModel.goBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Назад")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#A0A0C0"))
                }
                Spacer()
            }

            // Иконка telegram
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1A1A2E"))
                    .frame(width: 64, height: 64)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "#FF2D78"))
            }

            // Заголовок
            VStack(spacing: 8) {
                Text("Введи код из Telegram")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let success = viewModel.successMessage {
                    Text(success)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#00E5A0"))
                }
            }

            // 6-значный код
            CodeInputField(text: $viewModel.codeText)

            // Ошибка
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Кнопка входа
            BBButton(
                title: "Войти",
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.canVerify
            ) {
                Task { await viewModel.verifyCode() }
            }

            // Переотправка кода
            Button("Отправить код повторно") {
                Task { await viewModel.resendCode() }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(hex: "#FF2D78").opacity(viewModel.isLoading ? 0.4 : 1))
            .disabled(viewModel.isLoading)
        }
    }
}

// MARK: - Code Input Field (6 ячеек)

struct CodeInputField: View {
    @Binding var text: String

    private let cellCount = 6

    init(text: Binding<String>) {
        self._text = text
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<cellCount, id: \.self) { index in
                CodeCell(
                    digit: digit(at: index),
                    isActive: isActive(at: index)
                )
            }
        }
        .overlay(
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .opacity(0.01)
                .onChange(of: text) { new in
                    text = String(new.filter(\.isNumber).prefix(6))
                }
        )
    }

    private func digit(at index: Int) -> String {
        let digits = text.filter(\.isNumber)
        guard index < digits.count else { return "" }
        return String(digits[digits.index(digits.startIndex, offsetBy: index)])
    }

    private func isActive(at index: Int) -> Bool {
        text.filter(\.isNumber).count == index
    }
}

struct CodeCell: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1A1A2E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isActive ? Color(hex: "#FF2D78") :
                            (digit.isEmpty ? Color.white.opacity(0.08) : Color(hex: "#FF2D78").opacity(0.4)),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                .frame(width: 46, height: 56)
                .scaleEffect(isActive ? 1.05 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isActive)

            Text(digit)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Reusable Components

struct BBTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isValid: Bool = true

    var body: some View {
        TextField("", text: $text)
            .keyboardType(keyboardType)
            .font(.system(size: 17))
            .foregroundColor(.white)
            .placeholder(when: text.isEmpty) {
                Text(placeholder)
                    .foregroundColor(Color(hex: "#5A5A7A"))
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(Color(hex: "#1A1A2E"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isValid ? Color.white.opacity(0.08) : Color(hex: "#FF4757").opacity(0.6),
                        lineWidth: 1
                    )
            )
    }
}

struct BBButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isDisabled {
                        Color(hex: "#2A2A3E")
                    } else {
                        LinearGradient(
                            colors: [Color(hex: "#FF2D78"), Color(hex: "#FF006E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(16)
            .shadow(
                color: isDisabled ? .clear : Color(hex: "#FF2D78").opacity(0.35),
                radius: 12, x: 0, y: 6
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3)) { isPressed = false } }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDisabled)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Color(hex: "#FF4757"))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#FF4757"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "#FF4757").opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#FF4757").opacity(0.2), lineWidth: 1)
        )
    }
}

struct TelegramIdHint: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                    Text("Как узнать свой Telegram ID?")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                }
                .foregroundColor(Color(hex: "#A0A0C0"))
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    HintRow(number: "1", text: "Открой бот @userinfobot в Telegram")
                    HintRow(number: "2", text: "Нажми /start")
                    HintRow(number: "3", text: "Скопируй Id из ответа")
                }
                .padding(14)
                .background(Color(hex: "#11111E"))
                .cornerRadius(12)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

struct HintRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#FF2D78"))
                .frame(width: 18, height: 18)
                .background(Color(hex: "#FF2D78").opacity(0.15))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#A0A0C0"))
        }
    }
}

// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { content() }
            self
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - AuthStep Equatable helper

extension AuthStep {
    var id: String {
        switch self {
        case .enterTelegramId: return "telegramId"
        case .enterCode: return "code"
        case .authenticated: return "auth"
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .preferredColorScheme(.dark)
}
