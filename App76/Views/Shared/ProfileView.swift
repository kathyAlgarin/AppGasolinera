import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showChangePassword = false

    var body: some View {
        NavigationStack {
            List {
                if let user = viewModel.user {
                    Section("Datos de la cuenta") {
                        LabeledContent("Nombre", value: user.name)
                        LabeledContent("Correo", value: user.email)
                        LabeledContent("Rol", value: user.role.rawValue)
                        if let branchName = viewModel.branchName {
                            LabeledContent("Sucursal", value: branchName)
                        }
                    }
                }

                Section {
                    Button("Cambiar contraseña") {
                        showChangePassword = true
                    }
                }

                Section {
                    Button("Cerrar sesión", role: .destructive) {
                        viewModel.logout()
                    }
                }
            }
            .navigationTitle("Perfil")
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
        }
    }
}
