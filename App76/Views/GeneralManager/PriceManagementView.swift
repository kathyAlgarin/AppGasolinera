import SwiftUI

/// Gestión de precios por sucursal: el precio puede variar entre sucursales.
struct PriceManagementView: View {
    @StateObject private var viewModel = PriceManagementViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if viewModel.branches.count > 1 {
                    Picker("Sucursal", selection: Binding(
                        get: { viewModel.selectedBranchID ?? viewModel.branches.first?.id },
                        set: { viewModel.selectedBranchID = $0 }
                    )) {
                        ForEach(viewModel.branches) { branch in
                            Text(branch.name).tag(Optional(branch.id))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                if let branch = viewModel.selectedBranch {
                    List {
                        ForEach(FuelType.allCases) { type in
                            NavigationLink {
                                PriceEditView(branchID: branch.id, fuelType: type)
                            } label: {
                                HStack {
                                    Image(systemName: type.symbolName)
                                        .foregroundColor(.gas76Orange)
                                    Text(type.rawValue)
                                    Spacer()
                                    Text(viewModel.price(branchID: branch.id, fuelType: type).formatted(.currency(code: "USD")))
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
