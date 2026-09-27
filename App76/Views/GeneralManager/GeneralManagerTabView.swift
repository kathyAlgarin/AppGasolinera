import SwiftUI

struct GeneralManagerTabView: View {
    var body: some View {
        TabView {
            GMDashboardView()
                .tabItem { Label("Panel", systemImage: "chart.bar.fill") }

            UserManagementView()
                .tabItem { Label("Usuarios", systemImage: "person.2.fill") }

            BranchManagementView()
                .tabItem { Label("Sucursales", systemImage: "building.2.fill") }

            PriceManagementView()
                .tabItem { Label("Precios", systemImage: "tag.fill") }

            ProfileView()
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
        .tint(.gas76Orange)
    }
}
