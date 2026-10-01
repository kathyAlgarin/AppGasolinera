import SwiftUI

/// Punto de entrada de navegación: decide qué mostrar según si hay sesión
/// iniciada y cuál es el rol del usuario actual.
struct RootView: View {
    @StateObject private var viewModel = RootViewModel()

    var body: some View {
        Group {
            switch viewModel.destination {
            case .generalManager:
                GeneralManagerTabView()
            case .branchManager:
                BranchManagerTabView()
            case .login:
                LoginView()
            }
        }
        .animation(.default, value: viewModel.destination)
    }
}
