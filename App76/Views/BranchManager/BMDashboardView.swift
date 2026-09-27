import SwiftUI

/// Dashboard del Gerente de Sucursal: únicamente la información de su sucursal.
struct BMDashboardView: View {
    @EnvironmentObject var store: AppStore
    @State private var showReceptionForm = false
    @State private var showCutForm = false

    private var branch: Branch? {
        guard let user = store.currentUser else { return nil }
        return store.branch(for: user)
    }

    private var todaySales: [FuelType: Double] {
        guard let branch else { return [:] }
        return store.sales(for: branch.id, on: Date())
    }

    private var todayRevenue: Double {
        guard let branch else { return 0 }
        return store.revenue(for: branch.id, on: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let branch {
                    VStack(alignment: .leading, spacing: 20) {
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

                        HStack(spacing: 16) {
                            Button {
                                showReceptionForm = true
                            } label: {
                                Label("Registrar recepción", systemImage: "shippingbox.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.gas76Blue)

                            Button {
                                showCutForm = true
                            } label: {
                                Label("Registrar corte", systemImage: "clipboard.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.gas76Orange)
                        }
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
            .sheet(isPresented: $showReceptionForm) {
                if let branch {
                    NavigationStack {
                        ReceptionFormView(branch: branch)
                    }
                }
            }
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
