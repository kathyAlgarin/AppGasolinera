import Foundation

/// Resultado del día de una sucursal.
struct DailyReport {
    let branchID: UUID
    /// Litros vendidos por bomba y por combustible (contador de cierre − apertura).
    let pumpSales: [UUID: [FuelType: Double]]
    /// Consolidación de las 6 bombas: litros por combustible.
    let litersByFuel: [FuelType: Double]
    /// Litros vendidos según tanques (apertura + recepciones − cierre). Solo control.
    let tankLitersByFuel: [FuelType: Double]
    /// Pérdidas registradas (litros) por combustible en el periodo.
    let lossesByFuel: [FuelType: Double]
    /// Datos con los que se calculó el control por tanques, para poder explicarlo.
    let openingLevels: [FuelType: Double]
    let receivedByFuel: [FuelType: Double]
    let closingLevels: [FuelType: Double]
    let revenue: Double

    var totalLiters: Double { litersByFuel.values.reduce(0, +) }

    func liters(ofPump pumpID: UUID) -> Double {
        pumpSales[pumpID]?.values.reduce(0, +) ?? 0
    }

    /// Tanques − bombas − pérdidas registradas. Positivo = salió del tanque más combustible
    /// del que explican las ventas de las bombas y las pérdidas registradas.
    func difference(for fuel: FuelType) -> Double {
        (tankLitersByFuel[fuel] ?? 0) - (litersByFuel[fuel] ?? 0) - (lossesByFuel[fuel] ?? 0)
    }

    /// Diferencia máxima aceptada: 1 % de lo vendido por bombas, mínimo 1 L.
    func tolerance(for fuel: FuelType) -> Double {
        max((litersByFuel[fuel] ?? 0) * SalesCalculator.toleranceRatio, 1)
    }

    func isBalanced(for fuel: FuelType) -> Bool {
        abs(difference(for: fuel)) <= tolerance(for: fuel)
    }

    var isBalanced: Bool {
        FuelType.allCases.allSatisfy { isBalanced(for: $0) }
    }
}

enum SalesCalculator {
    /// Tolerancia del cuadre bombas vs. tanques (1 %).
    static let toleranceRatio = 0.01

    static func report(branchID: UUID,
                       opening: FuelCut,
                       closing: FuelCut,
                       receptions: [Reception],
                       losses: [FuelLoss] = [],
                       prices: [FuelType: Double]) -> DailyReport {

        // 1) Ventas por bomba: litros registrados en el corte de cierre.
        var pumpSales: [UUID: [FuelType: Double]] = [:]
        for reading in closing.pumpReadings {
            pumpSales[reading.pumpID, default: [:]][reading.fuelType] = reading.liters
        }

        var litersByFuel: [FuelType: Double] = [:]
        var tankLiters: [FuelType: Double] = [:]
        var receivedByFuel: [FuelType: Double] = [:]
        var lossesByFuel: [FuelType: Double] = [:]

        for fuel in FuelType.allCases {
            // 2) Consolidación de las bombas por combustible.
            litersByFuel[fuel] = pumpSales.values.reduce(0) { $0 + ($1[fuel] ?? 0) }

            // 3) Control por tanques.
            let received = receptions.filter { $0.fuelType == fuel }.reduce(0) { $0 + $1.quantity }
            receivedByFuel[fuel] = received
            lossesByFuel[fuel] = losses.filter { $0.fuelType == fuel }.reduce(0) { $0 + $1.liters }
            tankLiters[fuel] = (opening.levels[fuel] ?? 0) + received - (closing.levels[fuel] ?? 0)
        }

        // 4) Ingresos: litros de bombas × precio de la sucursal.
        let revenue = FuelType.allCases.reduce(0) { $0 + (litersByFuel[$1] ?? 0) * (prices[$1] ?? 0) }

        return DailyReport(branchID: branchID,
                           pumpSales: pumpSales,
                           litersByFuel: litersByFuel,
                           tankLitersByFuel: tankLiters,
                           lossesByFuel: lossesByFuel,
                           openingLevels: opening.levels,
                           receivedByFuel: receivedByFuel,
                           closingLevels: closing.levels,
                           revenue: revenue)
    }
}
