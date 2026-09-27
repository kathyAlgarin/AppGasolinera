import SwiftUI

/// Detalle de un tipo de combustible: ventas (litros y dinero), compras, pérdidas,
/// estado del tanque e historial diario. `branchID == nil` = todas las sucursales.
struct FuelDetailView: View {
    @EnvironmentObject var store: AppStore
    let fuelType: FuelType
    let branchID: UUID?
    let date: Date

    private var scope: [Branch] {
        store.branches.filter { branchID == nil || $0.id == branchID }
    }

    var body: some View {
        let today = store.totals(branchID: branchID, on: date)[fuelType] ?? FuelTotals()
        let todayRevenue = store.revenueByFuel(branchID: branchID, on: date)[fuelType] ?? 0

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(branchID == nil ? "Todas las sucursales"
                     : store.branches.first { $0.id == branchID }?.name ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    SummaryCard(title: "Litros vendidos (\(date.dayLabel))", value: "\(Int(today.sales)) L",
                                systemImage: "fuelpump.fill")
                    SummaryCard(title: "Ventas (\(date.dayLabel))", value: todayRevenue.formatted(.currency(code: "USD")),
                                systemImage: "dollarsign.circle.fill", tint: .gas76Blue)
                    SummaryCard(title: "Compras (\(date.dayLabel))", value: "\(Int(today.purchases)) L",
                                systemImage: "shippingbox.fill")
                    SummaryCard(title: "Pérdidas (\(date.dayLabel))", value: "\(Int(today.losses)) L",
                                systemImage: "exclamationmark.triangle.fill", tint: .red)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text(branchID == nil ? "Por sucursal (\(date.dayLabel))" : "Ventas y tanque (\(date.dayLabel))")
                        .font(.headline)
                        .padding(.horizontal)
                    ForEach(scope) { branch in
                        let t = store.totals(branchID: branch.id, on: date)[fuelType] ?? FuelTotals()
                        let revenue = store.revenueByFuel(branchID: branch.id, on: date)[fuelType] ?? 0
                        VStack(alignment: .leading, spacing: 6) {
                            if branchID == nil {
                                Text(branch.name).font(.subheadline.bold())
                            }
                            HStack {
                                Text("Vendido: \(Int(t.sales)) L")
                                Spacer()
                                Text(revenue.formatted(.currency(code: "USD")))
                                    .foregroundColor(.gas76Blue)
                            }
                            .font(.footnote.bold())
                            Text("Compras \(Int(t.purchases)) L · Pérdidas \(Int(t.losses)) L")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            if let tank = branch.tanks.first(where: { $0.fuelType == fuelType }) {
                                TankLevelRow(tank: tank, autonomyDays: store.autonomyDays(branchID: branch.id, tank: tank))
                            }
                            if branchID != nil,
                               let price = store.currentPrice(branchID: branch.id, fuelType: fuelType) {
                                Text("Precio vigente: \(price.formatted(.currency(code: "USD"))) por litro")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gas76Card.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Historial de ventas por día")
                        .font(.headline)
                        .padding(.horizontal)
                    let history = store.history(branchID: branchID, fuelType: fuelType)
                    if history.isEmpty {
                        Text("Aún no hay cortes registrados.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    VStack(spacing: 8) {
                        ForEach(history) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.day.formatted(date: .abbreviated, time: .omitted) + (entry.isPartial ? " · parcial" : ""))
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(entry.revenue.formatted(.currency(code: "USD")))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.gas76Blue)
                                }
                                Text("Vendidos \(Int(entry.totals.sales)) L · Compras \(Int(entry.totals.purchases)) L · Pérdidas \(Int(entry.totals.losses)) L")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .navigationTitle(fuelType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
