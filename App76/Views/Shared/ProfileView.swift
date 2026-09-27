import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var showChangePassword = false

    var body: some View {
        NavigationStack {
            List {
                if let user = store.currentUser {
                    Section("Datos de la cuenta") {
                        LabeledContent("Nombre", value: user.name)
                        LabeledContent("Correo", value: user.email)
                        LabeledContent("Rol", value: user.role.rawValue)
                        if let branchID = user.branchID,
                           let branch = store.branches.first(where: { $0.id == branchID }) {
                            LabeledContent("Sucursal", value: branch.name)
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
                        store.logout()
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
