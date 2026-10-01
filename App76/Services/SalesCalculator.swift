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
    let revenue: Double

    var totalLiters: Double { litersByFuel.values.reduce(0, +) }

    func liters(ofPump pumpID: UUID) -> Double {
        pumpSales[pumpID]?.values.reduce(0, +) ?? 0
    }

    /// Tanques − bombas. Positivo = salió más combustible del tanque que lo medido en bombas.
    func difference(for fuel: FuelType) -> Double {
        (tankLitersByFuel[fuel] ?? 0) - (litersByFuel[fuel] ?? 0)
    }

    func isBalanced(for fuel: FuelType) -> Bool {
        let pumped = litersByFuel[fuel] ?? 0
        return abs(difference(for: fuel)) <= max(pumped * SalesCalculator.toleranceRatio, 1)
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
                       prices: [FuelType: Double]) -> DailyReport {

        // 1) Ventas por bomba: contador de cierre − contador de apertura.
        var pumpSales: [UUID: [FuelType: Double]] = [:]
        for reading in closing.pumpReadings {
            guard let start = opening.meter(pumpID: reading.pumpID, fuelType: reading.fuelType) else { continue }
            pumpSales[reading.pumpID, default: [:]][reading.fuelType] = reading.meterLiters - start
        }

        var litersByFuel: [FuelType: Double] = [:]
        var tankLiters: [FuelType: Double] = [:]

        for fuel in FuelType.allCases {
            // 2) Consolidación de las bombas por combustible.
            litersByFuel[fuel] = pumpSales.values.reduce(0) { $0 + ($1[fuel] ?? 0) }

            // 3) Control por tanques.
            let received = receptions.filter { $0.fuelType == fuel }.reduce(0) { $0 + $1.quantity }
            tankLiters[fuel] = (opening.levels[fuel] ?? 0) + received - (closing.levels[fuel] ?? 0)
        }

        // 4) Ingresos: litros de bombas × precio de la sucursal.
        let revenue = FuelType.allCases.reduce(0) { $0 + (litersByFuel[$1] ?? 0) * (prices[$1] ?? 0) }

        return DailyReport(branchID: branchID,
                           pumpSales: pumpSales,
                           litersByFuel: litersByFuel,
                           tankLitersByFuel: tankLiters,
                           revenue: revenue)
    }
}
