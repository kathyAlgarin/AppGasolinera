import SwiftUI

/// Registro de corte (apertura o cierre): niveles de tanque y contador de cada bomba.
struct CutFormView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: CutFormViewModel

    init(branchID: UUID) {
        _viewModel = StateObject(wrappedValue: CutFormViewModel(branchID: branchID))
    }

    var body: some View {
        Form {
            Section("Tipo de corte") {
                Picker("Corte", selection: $viewModel.cutType) {
                    Text("Apertura").tag(CutType.opening)
                    Text("Cierre").tag(CutType.closing)
                }
                .pickerStyle(.segmented)
            }

            Section("Niveles de tanque (litros)") {
                ForEach(FuelType.allCases) { type in
                    fuelRow(type, text: viewModel.levelBinding(for: type))
                }
            }

            ForEach(viewModel.pumps) { pump in
                Section {
                    ForEach(FuelType.allCases) { type in
                        fuelRow(type, text: viewModel.meterBinding(pump: pump, fuel: type))
                    }
                } header: {
                    Text(pump.name)
                } footer: {
                    Text("Contador acumulado del surtidor (litros)")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button("Guardar corte") { viewModel.save() }
                    .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle("Registrar corte")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }

    private func fuelRow(_ type: FuelType, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: type.symbolName)
                .foregroundColor(.gas76Orange)
            Text(type.rawValue)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }
}
