import SwiftUI

/// Gestión de precios por sucursal: el precio puede variar entre sucursales.
struct PriceManagementView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedBranchID: UUID?

    private var selectedBranch: Branch? {
        if let id = selectedBranchID, let branch = store.branches.first(where: { $0.id == id }) {
            return branch
        }
        return store.branches.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if store.branches.count > 1 {
                    Picker("Sucursal", selection: Binding(
                        get: { selectedBranchID ?? store.branches.first?.id },
                        set: { selectedBranchID = $0 }
                    )) {
                        ForEach(store.branches) { branch in
                            Text(branch.name).tag(Optional(branch.id))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                if let branch = selectedBranch {
                    List {
                        ForEach(FuelType.allCases) { type in
                            NavigationLink {
                                PriceEditView(branch: branch, fuelType: type)
                            } label: {
                                HStack {
                                    Image(systemName: type.symbolName)
                                        .foregroundColor(.gas76Orange)
                                    Text(type.rawValue)
                                    Spacer()
                                    Text((store.currentPrice(branchID: branch.id, fuelType: type) ?? 0).formatted(.currency(code: "USD")))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Spacer()
                    Text("No hay sucursales registradas todavía.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Precios")
        }
    }
}
