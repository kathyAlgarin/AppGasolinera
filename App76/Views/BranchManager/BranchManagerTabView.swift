import SwiftUI

struct BranchManagerTabView: View {
    @StateObject private var viewModel = BranchManagerTabViewModel()

    var body: some View {
        TabView {
            BMDashboardView(branchID: viewModel.branchID)
                .tabItem { Label("Panel", systemImage: "chart.bar.fill") }

            ProfileView()
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
        .tint(.gas76Orange)
    }
}
