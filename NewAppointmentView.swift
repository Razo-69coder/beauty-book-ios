import SwiftUI

struct NewAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showClientPicker = false
    @State private var showServicePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Новая запись")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Button("Сохранить") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#080810"))
            .navigationTitle("Новая запись")
        }
    }
}

#Preview {
    NewAppointmentView()
        .preferredColorScheme(.dark)
}