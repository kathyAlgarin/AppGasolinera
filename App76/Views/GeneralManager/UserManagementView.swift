import SwiftUI

/// Gestión de usuarios: solo visible/accesible para el Gerente General.
struct UserManagementView: View {
    @StateObject private var viewModel = UserManagementViewModel()
    @State private var showAddUser = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.users) { user in
                    NavigationLink(value: user) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(user.name).font(.subheadline.bold())
                                if !user.isActive {
                                    Text("Inactivo")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.15))
                                        .foregroundColor(.red)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.roleDescription(for: user))
                                .font(.caption)
                                .foregroundColor(.gas76Blue)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Usuarios")
            .navigationDestination(for: AppUser.self) { user in
                UserFormView(existingUser: user)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddUser = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddUser) {
                NavigationStack {
                    UserFormView(existingUser: nil)
                }
            }
        }
    }
}
