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
    let openingLevel: Double
    let received: Double
    let closingLevel: Double
    let tankLiters: Double      // lo que bajó el tanque
    let pumpLiters: Double      // lo que registraron las bombas
    let difference: Double      // tanque − bombas
    let tolerance: Double
    let isBalanced: Bool

    /// Explicación en lenguaje natural de por qué cuadra o no.
    var explanation: String {
        let diff = Int(abs(difference).rounded())
        let tol = Int(tolerance.rounded())
        if isBalanced {
            return "Cuadra: el tanque bajó \(Int(tankLiters)) L y las bombas registraron \(Int(pumpLiters)) L. "
                + "La diferencia (\(diff) L) está dentro de la tolerancia de ±\(tol) L."
        }
        let detail = difference > 0
            ? "del tanque salieron \(diff) L más de los que registraron las bombas"
            : "las bombas registraron \(diff) L más de los que bajó el tanque"
        return "No cuadra: \(detail) (tolerancia ±\(tol) L). Posible fuga, merma, bomba descalibrada o error de captura."
    }
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
            ReconciliationRow(
                fuel: $0,
                openingLevel: report.openingLevels[$0] ?? 0,
                received: report.receivedByFuel[$0] ?? 0,
                closingLevel: report.closingLevels[$0] ?? 0,
                tankLiters: report.tankLitersByFuel[$0] ?? 0,
                pumpLiters: report.litersByFuel[$0] ?? 0,
                difference: report.difference(for: $0),
                tolerance: report.tolerance(for: $0),
                isBalanced: report.isBalanced(for: $0)
            )
        }
    }
}
