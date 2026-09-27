import SwiftUI

/// Formulario para crear o editar un usuario. Aplica la regla de negocio:
/// solo un Gerente de Sucursal activo por sucursal.
struct UserFormView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let existingUser: AppUser?

    @State private var name: String
    @State private var email: String
    @State private var password: String
    @State private var role: UserRole
    @State private var branchID: UUID?
    @State private var isActive: Bool
    @State private var errorMessage: String?

    init(existingUser: AppUser?) {
        self.existingUser = existingUser
        _name = State(initialValue: existingUser?.name ?? "")
        _email = State(initialValue: existingUser?.email ?? "")
        _password = State(initialValue: existingUser?.password ?? "")
        _role = State(initialValue: existingUser?.role ?? .branchManager)
        _branchID = State(initialValue: existingUser?.branchID)
        _isActive = State(initialValue: existingUser?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Datos del usuario") {
                TextField("Nombre completo", text: $name)
                TextField("Correo electrónico", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("Contraseña", text: $password)
            }

            Section("Rol") {
                Picker("Rol", selection: $role) {
                    Text("Gerente General").tag(UserRole.generalManager)
                    Text("Gerente de Sucursal").tag(UserRole.branchManager)
                }
                .pickerStyle(.segmented)

                if role == .branchManager {
                    Picker("Sucursal", selection: $branchID) {
                        Text("Selecciona una sucursal").tag(UUID?.none)
                        ForEach(store.branches) { branch in
                            Text(branch.name).tag(Optional(branch.id))
                        }
                    }
                }
            }

            if existingUser != nil {
                Section {
                    Toggle("Usuario activo", isOn: $isActive)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button(existingUser == nil ? "Crear usuario" : "Guardar cambios") {
                    save()
                }
                .disabled(!isValid)
            }
        }
        .navigationTitle(existingUser == nil ? "Nuevo usuario" : "Editar usuario")
    }

    private var isValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && (role == .generalManager || branchID != nil)
    }

    private func save() {
        let user = AppUser(
            id: existingUser?.id ?? UUID(),
            name: name,
            email: email,
            password: password,
            role: role,
            branchID: role == .generalManager ? nil : branchID,
            isActive: isActive
        )

        let success = existingUser == nil ? store.addUser(user) : store.updateUser(user)

        if success {
            dismiss()
        } else {
            errorMessage = "Esa sucursal ya tiene un gerente asignado. Desactívalo primero o elige otra sucursal."
        }
    }
}
