import SwiftUI

struct BranchManagerTabView: View {
    var body: some View {
        TabView {
            BMDashboardView()
                .tabItem { Label("Panel", systemImage: "chart.bar.fill") }

            ProfileView()
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
        .tint(.gas76Orange)
    }
}
