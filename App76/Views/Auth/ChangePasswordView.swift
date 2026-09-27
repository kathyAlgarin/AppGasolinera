import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Contraseña actual") {
                    SecureField("Contraseña actual", text: $currentPassword)
                }
                Section("Nueva contraseña") {
                    SecureField("Nueva contraseña", text: $newPassword)
                    SecureField("Confirmar contraseña", text: $confirmPassword)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Section {
                    Button("Guardar") { save() }
                }
            }
            .navigationTitle("Cambiar contraseña")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func save() {
        guard var user = store.currentUser else { return }
        guard user.password == currentPassword else {
            errorMessage = "La contraseña actual no es correcta."
            return
        }
        guard !newPassword.isEmpty, newPassword == confirmPassword else {
            errorMessage = "Las contraseñas nuevas no coinciden."
            return
        }
        user.password = newPassword
        _ = store.updateUser(user)
        dismiss()
    }
}
