import SwiftUI

/// Registro de recepción de combustible (camión cisterna) y de pérdidas con su razón.
struct ReceptionFormView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ReceptionFormViewModel

    init(branchID: UUID) {
        _viewModel = StateObject(wrappedValue: ReceptionFormViewModel(branchID: branchID))
    }

    var body: some View {
        Form {
            Section {
                Picker("Tipo de registro", selection: $viewModel.mode) {
                    ForEach(ReceptionFormViewModel.Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(viewModel.mode == .reception ? "Recepción de combustible" : "Pérdida de combustible") {
                Picker("Tipo de combustible", selection: $viewModel.fuelType) {
                    ForEach(FuelType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                HStack {
                    Text(viewModel.quantityLabel)
                    Spacer()
                    TextField("0", text: $viewModel.quantityText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                if viewModel.mode == .loss {
                    TextField("Razón de la pérdida (fuga, derrame…)", text: $viewModel.reasonText, axis: .vertical)
                }
            }

            Section {
                Button(viewModel.saveLabel) { viewModel.save() }
                    .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle(viewModel.title)
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
