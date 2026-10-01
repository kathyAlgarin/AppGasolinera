import SwiftUI

/// Dashboard del Gerente de Sucursal: únicamente la información de su sucursal.
struct BMDashboardView: View {
    @StateObject private var viewModel: BranchOverviewViewModel
    @State private var showReceptionForm = false
    @State private var showCutForm = false

    init(branchID: UUID?) {
        _viewModel = StateObject(wrappedValue: BranchOverviewViewModel(branchID: branchID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let branch = viewModel.branch {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 14) {
                            ActionCard(
                                title: "Registrar corte",
                                subtitle: viewModel.cutStatusText,
                                systemImage: viewModel.cutsComplete ? "checkmark.seal.fill" : "clipboard.fill",
                                tint: viewModel.cutsComplete ? .green : .gas76Orange
                            ) { showCutForm = true }

                            ActionCard(
                                title: "Recepción y pérdidas",
                                subtitle: viewModel.receptionStatusText,
                                systemImage: "shippingbox.fill",
                                tint: .gas76Blue
                            ) { showReceptionForm = true }
                        }
                        .padding(.horizontal)

                        BranchReportSection(viewModel: viewModel)
                    }
                    .padding(.vertical)
                    .sheet(isPresented: $showReceptionForm) {
                        NavigationStack {
                            ReceptionFormView(branchID: branch.id)
                        }
                    }
                    .sheet(isPresented: $showCutForm) {
                        NavigationStack {
                            CutFormView(branchID: branch.id)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No tienes una sucursal asignada.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 80)
                }
            }
            .background(Color.gas76Background)
            .navigationTitle(viewModel.title)
        }
    }
}
