import SwiftUI

/// Vista de solo lectura para que el Gerente General inspeccione el detalle
/// de una sucursal específica (misma información que ve el Gerente de Sucursal).
struct BranchDetailView: View {
    @EnvironmentObject var store: AppStore
    let branch: Branch
    @State private var date = Date()

    private var todayTotals: [FuelType: FuelTotals] {
        store.totals(branchID: branch.id, on: date)
    }

    private var todayRevenue: Double {
        store.revenue(branchID: branch.id, on: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DayPickerRow(date: $date, isPartial: store.hasOpenCut(branchID: branch.id, on: date))
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    SummaryCard(
                        title: "Ventas (\(date.dayLabel))",
                        value: "\(Int(todayTotals.values.reduce(0) { $0 + $1.sales })) L",
                        systemImage: "fuelpump.fill"
                    )
                    SummaryCard(
                        title: "Ingresos estimados (\(date.dayLabel))",
                        value: todayRevenue.formatted(.currency(code: "USD")),
                        systemImage: "dollarsign.circle.fill",
                        tint: .gas76Blue
                    )
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Niveles de tanque")
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(branch.tanks) { tank in
                        TankLevelRow(tank: tank, autonomyDays: store.autonomyDays(branchID: branch.id, tank: tank))
                            .padding(.horizontal)
                    }
                }

                FuelTotalsSection(title: "Movimientos por combustible (\(date.dayLabel))", branchID: branch.id, date: date)
            }
            .padding(.vertical)
        }
        .background(Color.gas76Background)
        .navigationTitle(branch.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
