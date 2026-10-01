import Foundation

/// Tipo de corte diario: apertura (inicio de operaciones) o cierre (fin de día).
enum CutType: String, Codable, Hashable {
    case opening = "Apertura"
    case closing = "Cierre"
}

/// Litros vendidos en el día por una bomba de un tipo de combustible
/// (se registra en el corte de cierre).
struct PumpReading: Codable, Equatable, Hashable {
    var pumpID: UUID
    var fuelType: FuelType
    var liters: Double
}

/// Corte diario del Gerente de Sucursal. La apertura registra los niveles de tanque;
/// el cierre registra además los litros vendidos por cada bomba.
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

    func liters(pumpID: UUID, fuelType: FuelType) -> Double? {
        pumpReadings.first { $0.pumpID == pumpID && $0.fuelType == fuelType }?.liters
    }
}
