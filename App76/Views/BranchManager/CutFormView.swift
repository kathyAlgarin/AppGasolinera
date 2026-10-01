import SwiftUI

/// Registro de corte. La apertura captura los niveles de tanque; el cierre captura además
/// los litros vendidos por cada bomba. Un corte ya guardado queda de solo lectura.
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
                    Text(viewModel.label(for: .opening)).tag(CutType.opening)
                    Text(viewModel.label(for: .closing)).tag(CutType.closing)
                }
                .pickerStyle(.segmented)
            }

            if viewModel.isLocked {
                Section {
                    Label(viewModel.lockedMessage, systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundColor(.green)
                }
            } else if viewModel.closingBlocked {
                Section {
                    Label("Primero debes registrar el corte de apertura de hoy.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
            }

            Group {
                Section("Niveles de tanque (litros)") {
                    ForEach(FuelType.allCases) { type in
                        VStack(alignment: .leading, spacing: 2) {
                            fuelRow(type, text: viewModel.levelBinding(for: type))
                            if let warning = viewModel.levelWarning(for: type) {
                                Text(warning).font(.caption).foregroundColor(.red)
                            } else if !viewModel.isLocked {
                                Text("Capacidad: \(Int(viewModel.capacity(for: type))) L")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if viewModel.showsSales {
                    Section {
                        Text("Anota los litros que vendió hoy cada bomba, por tipo de combustible.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Ventas por bomba")
                    }

                    ForEach(viewModel.pumps) { pump in
                        Section(pump.name) {
                            ForEach(FuelType.allCases) { type in
                                fuelRow(type, text: viewModel.saleBinding(pump: pump, fuel: type))
                            }
                        }
                    }
                }
            }
            .disabled(viewModel.isLocked)

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button(viewModel.isLocked ? "Corte ya registrado" : "Guardar corte") { viewModel.save() }
                    .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle("Registrar corte")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(viewModel.isLocked ? "Cerrar" : "Cancelar") { dismiss() }
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
