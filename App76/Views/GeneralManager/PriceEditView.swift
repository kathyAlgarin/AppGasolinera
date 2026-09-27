import SwiftUI

struct PriceEditView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let branch: Branch
    let fuelType: FuelType

    @State private var priceText: String = ""

    private var history: [PriceHistoryEntry] {
        store.priceHistory
            .filter { $0.branchID == branch.id && $0.fuelType == fuelType }
            .sorted { $0.changedAt > $1.changedAt }
    }

    var body: some View {
        Form {
            Section("Precio actual (por litro)") {
                HStack {
                    Text("Precio")
                    Spacer()
                    TextField("0.00", text: $priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Section {
                Button("Guardar precio") {
                    if let newPrice = Double(priceText) {
                        store.updatePrice(branchID: branch.id, fuelType: fuelType, newPrice: newPrice)
                        dismiss()
                    }
                }
                .disabled(Double(priceText) == nil)
            }

            if !history.isEmpty {
                Section("Historial de cambios") {
                    ForEach(history) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.oldPrice.formatted(.currency(code: "USD"))) → \(entry.newPrice.formatted(.currency(code: "USD")))")
                                .font(.subheadline)
                            Text(entry.changedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(fuelType.rawValue) · \(branch.name)")
        .onAppear {
            let current = store.currentPrice(branchID: branch.id, fuelType: fuelType) ?? 0
            priceText = String(format: "%.2f", current)
        }
    }
}
