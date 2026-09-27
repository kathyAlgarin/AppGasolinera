import SwiftUI

/// Registro de corte (apertura o cierre): lectura manual del nivel de cada tanque.
struct CutFormView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let branch: Branch

    @State private var cutType: CutType = .opening
    @State private var levelTexts: [FuelType: String] = [:]
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Tipo de corte") {
                Picker("Corte", selection: $cutType) {
                    Text("Apertura").tag(CutType.opening)
                    Text("Cierre").tag(CutType.closing)
                }
                .pickerStyle(.segmented)
            }

            Section("Niveles actuales (litros)") {
                ForEach(FuelType.allCases) { type in
                    HStack {
                        Image(systemName: type.symbolName)
                            .foregroundColor(.gas76Orange)
                        Text(type.rawValue)
                        Spacer()
                        TextField("0", text: Binding(
                            get: { levelTexts[type] ?? "" },
                            set: { levelTexts[type] = $0 }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button("Guardar corte") { save() }
            }
        }
        .navigationTitle("Registrar corte")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        }
        .onAppear {
            for tank in branch.tanks {
                levelTexts[tank.fuelType] = String(Int(tank.currentLevel))
            }
        }
    }

    private func save() {
        var levels: [FuelType: Double] = [:]
        for type in FuelType.allCases {
            levels[type] = Double(levelTexts[type] ?? "") ?? 0
        }

        do {
            try store.addCut(branchID: branch.id, type: cutType, levels: levels)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
