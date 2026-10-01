import SwiftUI

/// Formulario para crear o editar un usuario. Aplica la regla de negocio:
/// solo un Gerente de Sucursal activo por sucursal.
struct UserFormView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: UserFormViewModel

    init(existingUser: AppUser?) {
        _viewModel = StateObject(wrappedValue: UserFormViewModel(existingUser: existingUser))
    }

    var body: some View {
        Form {
            Section("Datos del usuario") {
                TextField("Nombre completo", text: $viewModel.name)
                TextField("Correo electrónico", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("Contraseña", text: $viewModel.password)
            }

            Section("Rol") {
                Picker("Rol", selection: $viewModel.role) {
                    Text("Gerente General").tag(UserRole.generalManager)
                    Text("Gerente de Sucursal").tag(UserRole.branchManager)
                }
                .pickerStyle(.segmented)

                if viewModel.role == .branchManager {
                    Picker("Sucursal", selection: $viewModel.branchID) {
                        Text("Selecciona una sucursal").tag(UUID?.none)
                        ForEach(viewModel.branches) { branch in
                            Text(branch.name).tag(Optional(branch.id))
                        }
                    }
                }
            }

            if viewModel.existingUser != nil {
                Section {
                    Toggle("Usuario activo", isOn: $viewModel.isActive)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button(viewModel.existingUser == nil ? "Crear usuario" : "Guardar cambios") {
                    viewModel.save()
                }
                .disabled(!viewModel.isValid)
            }
        }
        .navigationTitle(viewModel.existingUser == nil ? "Nuevo usuario" : "Editar usuario")
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }
}
