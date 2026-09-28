import SwiftUI

/// Dashboard consolidado: datos de TODAS las sucursales combinados.
struct GMDashboardView: View {
    @EnvironmentObject var store: AppStore

    /// nil = panorama general de todas las sucursales.
    @State private var selectedBranchID: UUID?
    @State private var date = Date()

    private var totals: [FuelType: FuelTotals] {
        store.totals(branchID: selectedBranchID, on: date)
    }

    private var scopedBranches: [Branch] {
        store.branches.filter { selectedBranchID == nil || $0.id == selectedBranchID }
    }

    private var criticalTanks: Int {
        scopedBranches.flatMap(\.tanks).filter { $0.status == .critical }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Sucursal", selection: $selectedBranchID) {
                        Text("Todas las sucursales").tag(UUID?.none)
                        ForEach(store.branches) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)

                    DayPickerRow(date: $date, isPartial: store.hasOpenCut(branchID: selectedBranchID, on: date))
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        SummaryCard(
                            title: "Litros vendidos (\(date.dayLabel))",
                            value: "\(Int(totals.values.reduce(0) { $0 + $1.sales })) L",
                            systemImage: "fuelpump.fill"
                        )
                        SummaryCard(
                            title: "Ingresos estimados (\(date.dayLabel))",
                            value: store.revenue(branchID: selectedBranchID, on: date).formatted(.currency(code: "USD")),
                            systemImage: "dollarsign.circle.fill",
                            tint: .gas76Blue
                        )
                        SummaryCard(
                            title: "Tanques en estado crítico",
                            value: "\(criticalTanks)",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: criticalTanks > 0 ? .red : .green
                        )
                        SummaryCard(
                            title: "Sucursales activas",
                            value: "\(store.branches.filter { $0.isActive }.count)",
                            systemImage: "building.2.fill"
                        )
                    }
                    .padding(.horizontal)

                    FuelTotalsSection(title: "Consolidado por combustible (\(date.dayLabel))", branchID: selectedBranchID, date: date)

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
