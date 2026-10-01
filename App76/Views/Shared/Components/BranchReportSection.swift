import SwiftUI

/// Contenido común del detalle de una sucursal: ventas, tanques, bombas,
/// consolidado y cuadre. Lo usan el panel del Gerente de Sucursal y el detalle
/// de solo lectura del Gerente General.
struct BranchReportSection: View {
    @ObservedObject var viewModel: BranchOverviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                SummaryCard(
                    title: "Ventas de hoy",
                    value: viewModel.totalLitersText,
                    systemImage: "fuelpump.fill"
                )
                SummaryCard(
                    title: "Ingresos estimados",
                    value: viewModel.revenueText,
                    systemImage: "dollarsign.circle.fill",
                    tint: .gas76Blue
                )
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Text("Niveles de tanque")
                    .font(.headline)
                    .padding(.horizontal)
                ForEach(viewModel.tanks) { tank in
                    TankLevelRow(tank: tank)
                        .padding(.horizontal)
                }
            }

            if viewModel.hasReport {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ventas por bomba")
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(viewModel.pumpRows) { row in
                        PumpSalesRowView(row: row)
                            .padding(.horizontal)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Consolidado de las bombas")
                        .font(.headline)
                        .padding(.horizontal)
                    VStack(spacing: 8) {
                        ForEach(FuelType.allCases) { fuel in
                            HStack {
                                Image(systemName: fuel.symbolName)
                                    .foregroundColor(.gas76Orange)
                                Text(fuel.rawValue)
                                Spacer()
                                Text("\(Int(viewModel.consolidatedLiters(for: fuel))) L")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gas76Card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Cuadre con tanques")
                        .font(.headline)
                        .padding(.horizontal)
                    Text("Compara lo que vendieron las bombas con lo que bajó el tanque.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    ForEach(viewModel.reconciliation) { row in
                        ReconciliationRowView(row: row)
                            .padding(.horizontal)
                    }
                }
            } else {
                Text("Aún no hay corte de apertura y cierre de hoy")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}
