import SwiftUI

/// Dashboard consolidado: datos de TODAS las sucursales combinados.
struct GMDashboardView: View {
    @EnvironmentObject var store: AppStore

    private var totalLitersToday: Double {
        store.branches.reduce(0) { partial, branch in
            partial + store.sales(for: branch.id, on: Date()).values.reduce(0, +)
        }
    }

    private var totalRevenueToday: Double {
        store.branches.reduce(0) { $0 + store.revenue(for: $1.id, on: Date()) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SummaryCard(
                            title: "Litros vendidos hoy",
                            value: "\(Int(totalLitersToday)) L",
                            systemImage: "fuelpump.fill"
                        )
                        SummaryCard(
                            title: "Ingresos estimados hoy",
                            value: totalRevenueToday.formatted(.currency(code: "USD")),
                            systemImage: "dollarsign.circle.fill",
                            tint: .gas76Blue
                        )
                        SummaryCard(
                            title: "Sucursales activas",
                            value: "\(store.branches.filter { $0.isActive }.count)",
                            systemImage: "building.2.fill"
                        )
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sucursales")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 10) {
                            ForEach(store.branches) { branch in
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
                BranchDetailView(branch: branch)
            }
        }
    }
}
