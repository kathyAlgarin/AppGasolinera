import SwiftUI

struct BranchManagementView: View {
    @StateObject private var viewModel = BranchManagementViewModel()
    @State private var showAddBranch = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.branches) { branch in
                    NavigationLink(value: branch) {
                        BranchSummaryRow(branch: branch, showsChevron: false)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Sucursales")
            .navigationDestination(for: Branch.self) { branch in
                BranchFormView(existingBranch: branch)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddBranch = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBranch) {
                NavigationStack {
                    BranchFormView(existingBranch: nil)
                }
            }
        }
    }
}
