import SwiftUI

struct ChangePasswordView: View {
    @StateObject private var viewModel = ChangePasswordViewModel()
    @Environment(\.dismiss) var dismiss


    var body: some View {
        NavigationStack {
            Form {
                Section("Contraseña actual") {
                    SecureField("Contraseña actual", text: $viewModel.currentPassword)
                }
                Section("Nueva contraseña") {
                    SecureField("Nueva contraseña", text: $viewModel.newPassword)
                    SecureField("Confirmar contraseña", text: $viewModel.confirmPassword)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Section {
                    Button("Guardar") { viewModel.save() }
                }
            }
            .navigationTitle("Cambiar contraseña")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onChange(of: viewModel.didSave) { _, saved in
                if saved { dismiss() }
            }
        }
    }
}
