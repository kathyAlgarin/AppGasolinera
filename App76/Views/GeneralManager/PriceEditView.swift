import SwiftUI

struct PriceEditView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: PriceEditViewModel

    init(branchID: UUID, fuelType: FuelType) {
        _viewModel = StateObject(wrappedValue: PriceEditViewModel(branchID: branchID, fuelType: fuelType))
    }

    var body: some View {
        Form {
            Section("Precio actual (por litro)") {
                HStack {
                    Text("Precio")
                    Spacer()
                    TextField("0.00", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Section {
                Button("Guardar precio") { viewModel.save() }
                    .disabled(!viewModel.canSave)
            }

            if !viewModel.history.isEmpty {
                Section("Historial de cambios") {
                    ForEach(viewModel.history) { entry in
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
        .navigationTitle(viewModel.title)
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }
}
