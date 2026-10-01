import Foundation

/// Tipo de corte diario: apertura (inicio de operaciones) o cierre (fin de día).
enum CutType: String, Codable, Hashable {
    case opening = "Apertura"
    case closing = "Cierre"
}

/// Lectura del contador acumulado de una bomba para un tipo de combustible.
struct PumpReading: Codable, Equatable, Hashable {
    var pumpID: UUID
    var fuelType: FuelType
    var meterLiters: Double
}

/// Corte de niveles de tanque y contadores de bomba, tomado manualmente por el
/// Gerente de Sucursal dos veces al día (apertura y cierre).
struct FuelCut: Identifiable, Codable, Equatable {
    let id: UUID
    var branchID: UUID
    var type: CutType
    var date: Date
    var levels: [FuelType: Double] // nivel leído en cada tanque al momento del corte
    var pumpReadings: [PumpReading]

    init(id: UUID = UUID(),
         branchID: UUID,
         type: CutType,
         date: Date = Date(),
         levels: [FuelType: Double],
         pumpReadings: [PumpReading] = []) {
        self.id = id
        self.branchID = branchID
        self.type = type
        self.date = date
        self.levels = levels
        self.pumpReadings = pumpReadings
    }

    func meter(pumpID: UUID, fuelType: FuelType) -> Double? {
        pumpReadings.first { $0.pumpID == pumpID && $0.fuelType == fuelType }?.meterLiters
    }
}
