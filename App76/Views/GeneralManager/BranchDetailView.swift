import SwiftUI

/// Vista de solo lectura para que el Gerente General inspeccione el detalle
/// de una sucursal específica (misma información que ve el Gerente de Sucursal).
struct BranchDetailView: View {
    @StateObject private var viewModel: BranchOverviewViewModel

    init(branchID: UUID) {
        _viewModel = StateObject(wrappedValue: BranchOverviewViewModel(branchID: branchID))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Modo solo lectura", systemImage: "eye")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                BranchReportSection(viewModel: viewModel)
            }
            .padding(.vertical)
        }
        .background(Color.gas76Background)
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
