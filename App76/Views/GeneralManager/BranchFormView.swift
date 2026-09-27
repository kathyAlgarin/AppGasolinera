import SwiftUI

/// Formulario para crear o editar una sucursal y la capacidad de sus tanques.
struct BranchFormView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let existingBranch: Branch?

    @State private var name: String
    @State private var address: String
    @State private var capacities: [FuelType: String]
    @State private var isActive: Bool

    init(existingBranch: Branch?) {
        self.existingBranch = existingBranch
        _name = State(initialValue: existingBranch?.name ?? "")
        _address = State(initialValue: existingBranch?.address ?? "")
        _isActive = State(initialValue: existingBranch?.isActive ?? true)

        var initialCapacities: [FuelType: String] = [:]
        for type in FuelType.allCases {
            if let tank = existingBranch?.tanks.first(where: { $0.fuelType == type }) {
                initialCapacities[type] = String(Int(tank.capacity))
            } else {
                initialCapacities[type] = ""
            }
        }
        _capacities = State(initialValue: initialCapacities)
    }

    var body: some View {
        Form {
            Section("Datos generales") {
                TextField("Nombre de la sucursal", text: $name)
                TextField("Dirección", text: $address)
            }

            Section {
                ForEach(FuelType.allCases) { type in
                    HStack {
                        Image(systemName: type.symbolName)
                            .foregroundColor(.gas76Orange)
                        Text(type.rawValue)
                        Spacer()
                        TextField("Litros", text: Binding(
                            get: { capacities[type] ?? "" },
                            set: { capacities[type] = $0 }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .numericInput(Binding(
                            get: { capacities[type] ?? "" },
                            set: { capacities[type] = $0 }
                        ))
                    }
                }
            } header: {
                Text("Capacidad de tanques (litros)")
            } footer: {
                if let existingBranch, !capacitiesAreValid {
                    let levels = existingBranch.tanks.map { "\($0.fuelType.rawValue) \(Int($0.currentLevel)) L" }.joined(separator: " · ")
                    Text("La capacidad no puede ser menor al nivel actual del tanque (\(levels)).")
                }
            }

            if existingBranch != nil {
                Section {
                    Toggle("Sucursal activa", isOn: $isActive)
                }
            }

            Section {
                Button(existingBranch == nil ? "Crear sucursal" : "Guardar cambios") {
                    save()
                }
                .disabled(name.isEmpty || address.isEmpty || !capacitiesAreValid)
            }
        }
        .navigationTitle(existingBranch == nil ? "Nueva sucursal" : "Editar sucursal")
        .dismissKeyboardSupport()
        .toolbar {
            // Al crear una sucursal el formulario se abre como hoja: botón para cerrarla.
            if existingBranch == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    /// Las 3 capacidades deben ser mayores a 0 y no menores al nivel actual del tanque.
    private var capacitiesAreValid: Bool {
        FuelType.allCases.allSatisfy { type in
            let capacity = Double(capacities[type] ?? "") ?? 0
            let level = existingBranch?.tanks.first(where: { $0.fuelType == type })?.currentLevel ?? 0
            return capacity > 0 && capacity >= level
        }
    }

    private func save() {
        var tanks: [Tank] = []
        for type in FuelType.allCases {
            let capacityValue = Double(capacities[type] ?? "") ?? 0
            if let existingTank = existingBranch?.tanks.first(where: { $0.fuelType == type }) {
                tanks.append(Tank(id: existingTank.id, fuelType: type, capacity: capacityValue, currentLevel: existingTank.currentLevel))
            } else {
                tanks.append(Tank(fuelType: type, capacity: capacityValue, currentLevel: 0))
            }
        }

        let branch = Branch(
            id: existingBranch?.id ?? UUID(),
            name: name,
            address: address,
            tanks: tanks,
            isActive: isActive
        )

        if let idx = store.branches.firstIndex(where: { $0.id == branch.id }) {
            store.branches[idx] = branch
        } else {
            store.branches.append(branch)
        }
        dismiss()
    }
}
