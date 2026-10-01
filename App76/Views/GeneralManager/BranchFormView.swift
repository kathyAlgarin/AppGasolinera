import SwiftUI

/// Formulario para crear o editar una sucursal y la capacidad de sus tanques.
struct BranchFormView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: BranchFormViewModel

    init(existingBranch: Branch?) {
        _viewModel = StateObject(wrappedValue: BranchFormViewModel(existingBranch: existingBranch))
    }

    var body: some View {
        Form {
            Section("Datos generales") {
                TextField("Nombre de la sucursal", text: $viewModel.name)
                TextField("Dirección", text: $viewModel.address)
                LabeledContent("Bombas", value: viewModel.pumpsText)
            }

            Section("Capacidad de tanques (litros)") {
                ForEach(FuelType.allCases) { type in
                    HStack {
                        Image(systemName: type.symbolName)
                            .foregroundColor(.gas76Orange)
                        Text(type.rawValue)
                        Spacer()
                        TextField("Litros", text: viewModel.capacityBinding(for: type))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }

            if viewModel.existingBranch != nil {
                Section {
                    Toggle("Sucursal activa", isOn: $viewModel.isActive)
                }
            }

            Section {
                Button(viewModel.existingBranch == nil ? "Crear sucursal" : "Guardar cambios") {
                    viewModel.save()
                }
                .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle(viewModel.existingBranch == nil ? "Nueva sucursal" : "Editar sucursal")
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }
}
