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
    let loss: Double            // pérdidas registradas
    let isBalanced: Bool

    /// Explicación en lenguaje natural de por qué cuadra o no.
    var explanation: String {
        let diff = Int(abs(difference).rounded())
        let tol = Int(tolerance.rounded())
        let lossText = loss > 0 ? " más \(Int(loss)) L de pérdidas registradas" : ""
        if isBalanced {
            return "Cuadra: el tanque bajó \(Int(tankLiters)) L y las bombas registraron \(Int(pumpLiters)) L\(lossText). "
                + "La diferencia (\(diff) L) está dentro de la tolerancia de ±\(tol) L."
        }
        let detail = difference > 0
            ? "del tanque salieron \(diff) L más de los que explican las bombas\(lossText)"
            : "las bombas\(lossText) explican \(diff) L más de los que bajó el tanque"
        return "No cuadra: \(detail) (tolerancia ±\(tol) L). Posible fuga, merma, bomba descalibrada o error de captura."
    }
}

struct LossRow: Identifiable {
    let id: UUID
    let fuel: FuelType
    let liters: Double
    let reason: String
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

    // MARK: Estado de los cortes de hoy

    private var todayCuts: (opening: FuelCut?, closing: FuelCut?) {
        guard let branchID else { return (nil, nil) }
        return repository.cuts(for: branchID, on: Date())
    }
    var openingDone: Bool { todayCuts.opening != nil }
    var closingDone: Bool { todayCuts.closing != nil }
    var cutsComplete: Bool { openingDone && closingDone }

    /// Texto de la tarjeta "Registrar corte": qué falta o que ya está completo.
    var cutStatusText: String {
        if cutsComplete { return "Apertura ✓ · Cierre ✓" }
        if openingDone { return "Apertura ✓ · Falta el cierre" }
        return "Falta la apertura"
    }

    /// Subtítulo de la tarjeta de recepciones/pérdidas según el estado del turno.
    var receptionStatusText: String {
        if !openingDone { return "Disponible tras la apertura" }
        if closingDone { return "Turno cerrado" }
        return "Camión cisterna o litros perdidos"
    }

    /// Pérdidas registradas hoy (con su razón), aunque todavía no haya reporte.
    var lossRows: [LossRow] {
        guard let branchID else { return [] }
        return repository.losses(for: branchID, on: Date())
            .map { LossRow(id: $0.id, fuel: $0.fuelType, liters: $0.liters, reason: $0.reason) }
    }

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
                loss: report.lossesByFuel[$0] ?? 0,
                isBalanced: report.isBalanced(for: $0)
            )
        }
    }
}
