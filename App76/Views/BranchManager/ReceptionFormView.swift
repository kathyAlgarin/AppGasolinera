import SwiftUI

/// Registro de recepción de combustible (llegada de camión cisterna).
struct ReceptionFormView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ReceptionFormViewModel

    init(branchID: UUID) {
        _viewModel = StateObject(wrappedValue: ReceptionFormViewModel(branchID: branchID))
    }

    var body: some View {
        Form {
            Section("Recepción de combustible") {
                Picker("Tipo de combustible", selection: $viewModel.fuelType) {
                    ForEach(FuelType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                HStack {
                    Text("Cantidad recibida (L)")
                    Spacer()
                    TextField("0", text: $viewModel.quantityText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Section {
                Button("Registrar recepción") { viewModel.save() }
                    .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle("Nueva recepción")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }
}
