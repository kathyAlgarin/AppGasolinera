import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ForgotPasswordViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Recuperar contraseña") {
                    TextField("Correo electrónico", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                if viewModel.sent {
                    Text("Si el correo existe en el sistema, se enviarán instrucciones para restablecer la contraseña.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Enviar instrucciones") {
                        viewModel.send()
                    }
                    .disabled(!viewModel.canSend)
                }
            }
            .navigationTitle("Olvidé mi contraseña")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
