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
                        BranchReportSection(viewModel: viewModel)

                        HStack(spacing: 16) {
                            Button {
                                showReceptionForm = true
                            } label: {
                                Label("Registrar recepción", systemImage: "shippingbox.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.gas76Blue)

                            Button {
                                showCutForm = true
                            } label: {
                                Label("Registrar corte", systemImage: "clipboard.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.gas76Orange)
                        }
                        .padding(.horizontal)
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
