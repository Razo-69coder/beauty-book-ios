import SwiftUI

struct FeedbackButton: View {
    @State private var storedOffset: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging = false
    @State private var showSheet = false
    @Environment(\.theme) private var theme

    private var anchor: CGSize {
        CGSize(width: 44, height: UIScreen.main.bounds.height * 0.75)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("Идеи?")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.accent)
                .shadow(color: .white.opacity(0.8), radius: 2)
            Image("bratz_doll")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .shadow(color: theme.accentGlow, radius: isDragging ? 16 : 8)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .animation(DS.springSnappy, value: isDragging)
        }
        .offset(
            x: anchor.width + storedOffset.width + dragTranslation.width,
            y: anchor.height + storedOffset.height + dragTranslation.height
        )
        .gesture(
            DragGesture()
                .onChanged { v in
                    isDragging = true
                    dragTranslation = v.translation
                }
                .onEnded { v in
                    isDragging = false
                    storedOffset = CGSize(
                        width: storedOffset.width + v.translation.width,
                        height: storedOffset.height + v.translation.height
                    )
                    dragTranslation = .zero
                    let currentX = anchor.width + storedOffset.width
                    let screenW = UIScreen.main.bounds.width
                    let targetX = currentX < screenW / 2 ? 12.0 : screenW - 80.0
                    withAnimation(DS.springSnappy) {
                        storedOffset.width = targetX - anchor.width
                    }
                }
        )
        .onTapGesture { showSheet = true }
        .sheet(isPresented: $showSheet) {
            FeedbackSheet()
                .environmentObject(ThemeManager.shared)
                .environment(\.theme, theme)
        }
    }
}

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var text = ""
    @State private var isSending = false
    @State private var sent = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Что улучшить или добавить?")
                    .font(DS.titleSmall)
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Любая идея важна — мы читаем каждое сообщение 💅")
                    .font(DS.bodySmall)
                    .foregroundColor(theme.textMuted)
                    .multilineTextAlignment(.center)

                TextEditor(text: $text)
                    .font(DS.body)
                    .foregroundColor(theme.textPrimary)
                    .colorScheme(theme == .platinum ? .light : .dark)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(theme.backgroundInput)
                    .cornerRadius(DS.r12)
                    .overlay(RoundedRectangle(cornerRadius: DS.r12).stroke(theme.borderSubtle, lineWidth: 1))

                if sent {
                    Text("Отправлено! Спасибо 🙏")
                        .font(DS.body)
                        .foregroundColor(theme.statusGreen)
                } else {
                    BBPrimaryButton(title: isSending ? "Отправляем..." : "Отправить", isLoading: isSending) {
                        Task { await sendFeedback() }
                    }
                    .environment(\.theme, theme)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
            .background(theme.backgroundDeep.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(theme.accent)
                }
            }
        }
    }

    func sendFeedback() async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSending = true
        _ = try? await APIClient.shared.request(.sendFeedback(text), as: MessageResponse.self)
        isSending = false
        sent = true
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        dismiss()
    }
}
