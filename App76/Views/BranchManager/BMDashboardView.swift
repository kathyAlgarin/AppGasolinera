import SwiftUI

/// Dashboard del Gerente de Sucursal: únicamente la información de su sucursal.
struct BMDashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var showCutForm = false
    @State private var date = Date()

    private var branch: Branch? {
        guard let user = store.currentUser else { return nil }
        return store.branch(for: user)
    }

    private var todayTotals: [FuelType: FuelTotals] {
        guard let branch else { return [:] }
        return store.totals(branchID: branch.id, on: date)
    }

    private var todayRevenue: Double {
        guard let branch else { return 0 }
        return store.revenue(branchID: branch.id, on: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let branch {
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

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Cortes (\(date.dayLabel))")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(CutShift.allCases) { shift in
                                let cut = store.cut(for: branch.id, shift: shift, on: date)
                                let count = cut?.readings.count ?? 0
                                HStack {
                                    Text("Corte \(shift.rawValue)")
                                    Spacer()
                                    Text(cut?.isClosed == true ? "Guardado" : "En curso · \(count)/\(Pump.count) bombas")
                                        .foregroundColor(cut?.isClosed == true ? .green : .secondary)
                                }
                                .padding()
                                .background(Color.gas76Card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }
                        }

                        Button {
                            showCutForm = true
                        } label: {
                            Label("Registrar corte", systemImage: "clipboard.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.gas76Orange)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No tienes una sucursal asignada.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 80)
                }
            }
            .background(Color.gas76Background)
            .navigationTitle(branch?.name ?? "Panel de Sucursal")
            .sheet(isPresented: $showCutForm) {
                if let branch {
                    NavigationStack {
                        CutFormView(branch: branch)
                    }
                }
            }
        }
    }
}
