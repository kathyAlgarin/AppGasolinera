import SwiftUI

/// Vista de solo lectura para que el Gerente General inspeccione el detalle
/// de una sucursal específica (misma información que ve el Gerente de Sucursal).
struct BranchDetailView: View {
    @EnvironmentObject var store: AppStore
    let branch: Branch

    private var todaySales: [FuelType: Double] {
        store.sales(for: branch.id, on: Date())
    }

    private var todayRevenue: Double {
        store.revenue(for: branch.id, on: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Modo solo lectura", systemImage: "eye")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    SummaryCard(
                        title: "Ventas de hoy",
                        value: "\(Int(todaySales.values.reduce(0, +))) L",
                        systemImage: "fuelpump.fill"
                    )
                    SummaryCard(
                        title: "Ingresos estimados",
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
                        TankLevelRow(tank: tank)
                            .padding(.horizontal)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Ventas de hoy por tipo (calculadas)")
                        .font(.headline)
                        .padding(.horizontal)
                    VStack(spacing: 8) {
                        ForEach(FuelType.allCases) { type in
                            HStack {
                                Image(systemName: type.symbolName)
                                    .foregroundColor(.gas76Orange)
                                Text(type.rawValue)
                                Spacer()
                                Text("\(Int(todaySales[type] ?? 0)) L")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gas76Card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.gas76Background)
        .navigationTitle(branch.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
