import Foundation

/// Turno de un corte diario: cada sucursal registra 2 cortes por día.
enum CutShift: String, Codable, CaseIterable, Identifiable, Hashable {
    case morning = "Matutino"
    case evening = "Vespertino"

    var id: String { rawValue }
}

/// Motivo de una pérdida o daño de combustible.
enum LossReason: String, Codable, CaseIterable, Identifiable, Hashable {
    case shrinkage = "Merma"
    case leak = "Fuga"
    case technicalFailure = "Falla técnica"
    case spill = "Derrame"

    var id: String { rawValue }
}

/// Bombas (surtidores) de una sucursal. Cada sucursal tiene exactamente 6 y
/// cada bomba despacha los 3 tipos de combustible.
enum Pump {
    static let count = 6
}

/// Movimientos de UN combustible: las tres categorías del reporte.
struct FuelTotals: Codable, Equatable {
    var sales = 0.0       // litros vendidos
    var purchases = 0.0   // litros recibidos (compras / recepción)
    var losses = 0.0      // litros perdidos o dañados
    var lossReason: LossReason?

    mutating func add(_ other: FuelTotals) {
        sales += other.sales
        purchases += other.purchases
        losses += other.losses
    }
}

/// Información individual de una bomba dentro de un corte: los movimientos de cada combustible.
struct PumpReading: Identifiable, Codable, Equatable {
    let id: UUID
    var pumpNumber: Int
    var amounts: [FuelType: FuelTotals]

    init(id: UUID = UUID(), pumpNumber: Int, amounts: [FuelType: FuelTotals]) {
        self.id = id
        self.pumpNumber = pumpNumber
        self.amounts = amounts
    }

    var totalSales: Double { amounts.values.reduce(0) { $0 + $1.sales } }
}

/// Corte diario de una sucursal (matutino o vespertino). Se va llenando bomba por
/// bomba y queda cerrado cuando están registradas las 6.
struct FuelCut: Identifiable, Codable, Equatable {
    let id: UUID
    var branchID: UUID
    var shift: CutShift
    var date: Date
    var readings: [PumpReading]
    /// true cuando el gerente pulsó "Guardar corte": ya no se pueden editar las bombas.
    var isClosed: Bool

    init(id: UUID = UUID(),
         branchID: UUID,
         shift: CutShift,
         date: Date = Date(),
         readings: [PumpReading] = [],
         isClosed: Bool = false) {
        self.id = id
        self.branchID = branchID
        self.shift = shift
        self.date = date
        self.readings = readings
        self.isClosed = isClosed
    }

    /// Las 6 bombas ya tienen información: el corte se puede guardar (cerrar).
    var isComplete: Bool { readings.count == Pump.count }

    /// Consolidado automático de las bombas registradas para un tipo de combustible.
    func totals(for fuelType: FuelType) -> FuelTotals {
        var result = FuelTotals()
        readings.forEach { result.add($0.amounts[fuelType] ?? FuelTotals()) }
        return result
    }
}

/// Resumen de un día para un combustible (historial de ventas).
struct DayFuelSummary: Identifiable {
    let day: Date
    let totals: FuelTotals
    let revenue: Double
    let isPartial: Bool   // hay algún corte del día sin cerrar

    var id: Date { day }
}
