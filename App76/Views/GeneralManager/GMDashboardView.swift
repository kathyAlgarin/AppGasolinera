import SwiftUI

/// Dashboard consolidado: datos de TODAS las sucursales activas combinados.
struct GMDashboardView: View {
    @StateObject private var viewModel = GMDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SummaryCard(
                            title: "Litros vendidos hoy",
                            value: viewModel.totalLitersText,
                            systemImage: "fuelpump.fill"
                        )
                        SummaryCard(
                            title: "Ingresos estimados hoy",
                            value: viewModel.totalRevenueText,
                            systemImage: "dollarsign.circle.fill",
                            tint: .gas76Blue
                        )
                        SummaryCard(
                            title: "Sucursales activas",
                            value: "\(viewModel.activeBranchesCount)",
                            systemImage: "building.2.fill"
                        )
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ventas por combustible (todas las sucursales)")
                            .font(.headline)
                            .padding(.horizontal)
                        VStack(spacing: 8) {
                            ForEach(FuelType.allCases) { fuel in
                                HStack {
                                    Image(systemName: fuel.symbolName)
                                        .foregroundColor(.gas76Orange)
                                    Text(fuel.rawValue)
                                    Spacer()
                                    Text("\(Int(viewModel.totalLiters(for: fuel))) L")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.gas76Card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sucursales")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 10) {
                            ForEach(viewModel.branches) { branch in
                                NavigationLink(value: branch) {
                                    BranchSummaryRow(branch: branch)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.gas76Background)
            .navigationTitle("Panel General")
            .navigationDestination(for: Branch.self) { branch in
                BranchDetailView(branchID: branch.id)
            }
        }
    }
}
