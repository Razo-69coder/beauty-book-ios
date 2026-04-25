import SwiftUI

// MARK: - Theme Manager

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "app_theme") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_theme") ?? AppTheme.pink.rawValue
        current = AppTheme(rawValue: saved) ?? .pink
    }
}

// MARK: - Theme Enum

enum AppTheme: String, CaseIterable {
    case pink     = "pink"
    case platinum = "platinum"

    var displayName: String {
        switch self {
        case .pink:     return "Розовая"
        case .platinum: return "Платина"
        }
    }

    var icon: String {
        switch self {
        case .pink:     return "🌸"
        case .platinum: return "💎"
        }
    }

    // MARK: - Colors

    var accent: Color {
        switch self {
        case .pink:     return Color(hex: "#FF2D78")
        case .platinum: return Color(hex: "#C0C8D4")
        }
    }

    var accentSecondary: Color {
        switch self {
        case .pink:     return Color(hex: "#FF006E")
        case .platinum: return Color(hex: "#8FA3B1")
        }
    }

    var accentGlow: Color {
        switch self {
        case .pink:     return Color(hex: "#FF2D78").opacity(0.35)
        case .platinum: return Color(hex: "#C0C8D4").opacity(0.25)
        }
    }

    var backgroundDeep: Color {
        switch self {
        case .pink:     return Color(hex: "#080810")
        case .platinum: return Color(hex: "#0A0C10")
        }
    }

    var backgroundCard: Color {
        switch self {
        case .pink:     return Color(hex: "#11111E")
        case .platinum: return Color(hex: "#12151C")
        }
    }

    var backgroundInput: Color {
        switch self {
        case .pink:     return Color(hex: "#1A1A2E")
        case .platinum: return Color(hex: "#161B24")
        }
    }

    var textPrimary: Color { .white }

    var textSecondary: Color { Color(hex: "#A0A0C0") }

    var textMuted: Color { Color(hex: "#5A5A7A") }

    var borderSubtle: Color { Color.white.opacity(0.07) }

    // MARK: - Gradient

    var gradientPrimary: LinearGradient {
        switch self {
        case .pink:
            return LinearGradient(
                colors: [Color(hex: "#FF2D78"), Color(hex: "#FF006E")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .platinum:
            return LinearGradient(
                colors: [Color(hex: "#C0C8D4"), Color(hex: "#8FA3B1")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    var gradientCard: LinearGradient {
        LinearGradient(
            colors: [backgroundCard, backgroundDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Status Colors (common)

    var statusGreen:  Color { Color(hex: "#00E5A0") }
    var statusYellow: Color { Color(hex: "#FFD166") }
    var statusRed:    Color { Color(hex: "#FF4757") }
    var statusBlue:   Color { Color(hex: "#4ECDC4") }
}

// MARK: - Environment Key

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .pink
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Design Tokens

enum DS {
    // Spacing (4pt grid)
    static let s4:  CGFloat = 4
    static let s8:  CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32
    static let s48: CGFloat = 48

    // Corner Radius
    static let r8:   CGFloat = 8
    static let r12:  CGFloat = 12
    static let r16:  CGFloat = 16
    static let r24:  CGFloat = 24
    static let rFull: CGFloat = 999

    // Typography
    static let titleLarge  = Font.system(size: 34, weight: .bold,     design: .rounded)
    static let titleMedium = Font.system(size: 28, weight: .bold,     design: .rounded)
    static let titleSmall  = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let headline    = Font.system(size: 17, weight: .semibold)
    static let bodyLarge   = Font.system(size: 17, weight: .regular)
    static let body        = Font.system(size: 15, weight: .regular)
    static let bodySmall   = Font.system(size: 13, weight: .regular)
    static let label       = Font.system(size: 15, weight: .semibold)
    static let labelSmall  = Font.system(size: 12, weight: .medium)
    static let caption     = Font.system(size: 11, weight: .regular)

    // Animations
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let springSmooth = Animation.spring(response: 0.5, dampingFraction: 0.85)
}

// MARK: - Reusable Components

struct BBPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme
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
                        .font(DS.headline)
                        .foregroundColor(isDisabled ? theme.textMuted : .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: DS.r16)
                    .fill(isDisabled ? AnyShapeStyle(theme.backgroundInput) : AnyShapeStyle(theme.gradientPrimary))
            )
            .shadow(color: isDisabled ? .clear : theme.accentGlow, radius: 12, x: 0, y: 6)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded   { _ in withAnimation(DS.springSnappy) { isPressed = false } }
        )
        .animation(DS.springSnappy, value: isDisabled)
    }
}

struct BBSecondaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.label)
                .foregroundColor(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r16)
                        .stroke(theme.accent.opacity(0.5), lineWidth: 1.5)
                )
        }
    }
}

struct BBTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var isValid: Bool = true

    @Environment(\.theme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(theme.textMuted)
                    .font(DS.body)
                    .padding(.horizontal, 16)
            }
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .font(DS.bodyLarge)
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 16)
            .focused($focused)
        }
        .frame(height: 56)
        .background(theme.backgroundInput)
        .cornerRadius(DS.r12)
        .overlay(
            RoundedRectangle(cornerRadius: DS.r12)
                .stroke(
                    focused ? theme.accent.opacity(0.6) :
                    (isValid ? theme.borderSubtle : theme.statusRed.opacity(0.5)),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.15), value: focused)
    }
}

struct BBCard<Content: View>: View {
    private let content: Content
    @Environment(\.theme) private var theme

    init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS.s16)
            .background(theme.backgroundCard)
            .cornerRadius(DS.r16)
            .overlay(
                RoundedRectangle(cornerRadius: DS.r16)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
    }
}

struct BBErrorBanner: View {
    let message: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(theme.statusRed)
            Text(message)
                .font(DS.bodySmall)
                .foregroundColor(theme.statusRed)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.statusRed.opacity(0.1))
        .cornerRadius(DS.r12)
        .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.statusRed.opacity(0.2), lineWidth: 1))
    }
}

struct BBSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Добавить"

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(title)
                .font(DS.labelSmall)
                .foregroundColor(theme.textMuted)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DS.labelSmall)
                        .foregroundColor(theme.accent)
                }
            }
        }
    }
}

// MARK: - Color Extension

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
