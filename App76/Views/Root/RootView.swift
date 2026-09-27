import SwiftUI

/// Punto de entrada de navegación: decide qué mostrar según si hay sesión
/// iniciada y cuál es el rol del usuario actual.
struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if let user = store.currentUser {
                switch user.role {
                case .generalManager:
                    GeneralManagerTabView()
                case .branchManager:
                    BranchManagerTabView()
                }
            } else {
                LoginView()
            }
        }
        .animation(.default, value: store.currentUser)
    }
}
