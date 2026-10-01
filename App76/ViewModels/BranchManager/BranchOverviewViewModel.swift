import Foundation

struct PumpSalesRow: Identifiable {
    let id: UUID
    let name: String
    let litersByFuel: [FuelType: Double]
    let total: Double
}

struct ReconciliationRow: Identifiable {
    var id: FuelType { fuel }
    let fuel: FuelType
    let difference: Double
    let isBalanced: Bool
}

final class BranchOverviewViewModel: ViewModel {
    private let repository: AppRepository
    private let branchID: UUID?

    /// branchID = nil → el usuario no tiene sucursal asignada.
    init(branchID: UUID?, repository: AppRepository = .shared) {
        self.branchID = branchID
        self.repository = repository
        super.init()
        forwardChanges(from: repository)
    }

    var branch: Branch? { branchID.flatMap { repository.branch(id: $0) } }
    var title: String { branch?.name ?? "Panel de Sucursal" }
    var tanks: [Tank] { branch?.tanks ?? [] }

    private var report: DailyReport? {
        branchID.flatMap { repository.dailyReport(branchID: $0, on: Date()) }
    }
    var hasReport: Bool { report != nil }

    var totalLitersText: String { "\(Int(report?.totalLiters ?? 0)) L" }
    var revenueText: String { (report?.revenue ?? 0).formatted(.currency(code: "USD")) }

    /// Una fila por bomba (6 filas).
    var pumpRows: [PumpSalesRow] {
        guard let branch, let report else { return [] }
        return branch.pumps.map { pump in
            PumpSalesRow(id: pump.id, name: pump.name,
                         litersByFuel: report.pumpSales[pump.id] ?? [:],
                         total: report.liters(ofPump: pump.id))
        }
    }

    /// Consolidación de las 6 bombas por combustible.
    func consolidatedLiters(for fuel: FuelType) -> Double { report?.litersByFuel[fuel] ?? 0 }

    /// Cuadre bombas vs. tanques.
    var reconciliation: [ReconciliationRow] {
        guard let report else { return [] }
        return FuelType.allCases.map {
            ReconciliationRow(fuel: $0, difference: report.difference(for: $0), isBalanced: report.isBalanced(for: $0))
        }
    }
}
