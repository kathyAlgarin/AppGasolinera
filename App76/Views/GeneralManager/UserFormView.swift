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
        _password = State(initialValue: "")
        _role = State(initialValue: existingUser?.role ?? .branchManager)
        _branchID = State(initialValue: existingUser?.branchID)
        _isActive = State(initialValue: existingUser?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Datos del usuario") {
                TextField("Nombre completo", text: $name)
                    .onChange(of: name) { _, new in
                        // Solo letras, espacios y signos propios de nombres.
                        let clean = new.filter { $0.isLetter || $0 == " " || $0 == "'" || $0 == "-" || $0 == "." }
                        if clean != new { name = clean }
                    }
                TextField("Correo electrónico", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .onChange(of: email) { _, new in
                        if new.contains(" ") { email = new.replacingOccurrences(of: " ", with: "") }
                    }
                if existingUser == nil {
                    SecureField("Contraseña", text: $password)
                }
            }

            // El Gerente General restablece la contraseña del usuario (no hay recuperación desde el login).
            if existingUser != nil {
                Section {
                    SecureField("Nueva contraseña", text: $password)
                } header: {
                    Text("Cambiar contraseña")
                } footer: {
                    Text("Déjala en blanco para conservar la actual. Mínimo 4 caracteres.")
                }
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
        .dismissKeyboardSupport()
        .toolbar {
            // Al crear un usuario el formulario se abre como hoja: botón para cerrarla.
            if existingUser == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        // El error se limpia al cambiar cualquier dato del formulario y a los 4 s.
        .onChange(of: role) { _, _ in errorMessage = nil }
        .onChange(of: branchID) { _, _ in errorMessage = nil }
        .onChange(of: name) { _, _ in errorMessage = nil }
        .onChange(of: email) { _, _ in errorMessage = nil }
        .onChange(of: password) { _, _ in errorMessage = nil }
        .task(id: errorMessage) {
            guard errorMessage != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            errorMessage = nil
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && email.isValidEmail && (password.count >= 4 || (existingUser != nil && password.isEmpty)) && (role == .generalManager || branchID != nil)
    }

    private func save() {
        let user = AppUser(
            id: existingUser?.id ?? UUID(),
            name: name,
            email: email,
            password: password.isEmpty ? (existingUser?.password ?? "") : password,
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
