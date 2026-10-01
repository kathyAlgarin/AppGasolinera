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
            if let shiftMessage = viewModel.shiftMessage {
                Section {
                    Label(shiftMessage, systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
            }

            Section {
                Picker("Tipo de registro", selection: $viewModel.mode) {
                    ForEach(ReceptionFormViewModel.Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
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
            } header: {
                Text(viewModel.mode == .reception ? "Recepción de combustible" : "Pérdida de combustible")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.limitHint)
                    if let warning = viewModel.quantityWarning {
                        Text(warning).foregroundColor(.red)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red).font(.footnote)
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
