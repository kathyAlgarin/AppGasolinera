import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Recuperar contraseña") {
                    TextField("Correo electrónico", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                if sent {
                    Text("Si el correo existe en el sistema, se enviarán instrucciones para restablecer la contraseña.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Enviar instrucciones") {
                        sent = true
                    }
                    .disabled(email.isEmpty)
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
