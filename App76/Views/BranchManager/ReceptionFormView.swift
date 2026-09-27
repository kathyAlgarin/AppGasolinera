import SwiftUI

/// Registro de recepción de combustible (llegada de camión cisterna).
struct ReceptionFormView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let branch: Branch

    @State private var fuelType: FuelType = .regular
    @State private var quantityText: String = ""

    var body: some View {
        Form {
            Section("Recepción de combustible") {
                Picker("Tipo de combustible", selection: $fuelType) {
                    ForEach(FuelType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                HStack {
                    Text("Cantidad recibida (L)")
                    Spacer()
                    TextField("0", text: $quantityText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Section {
                Button("Registrar recepción") {
                    if let quantity = Double(quantityText), quantity > 0 {
                        store.addReception(branchID: branch.id, fuelType: fuelType, quantity: quantity)
                        dismiss()
                    }
                }
                .disabled(!(Double(quantityText).map { $0 > 0 } ?? false))
            }
        }
        .navigationTitle("Nueva recepción")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
    }
}
