import Foundation

/// Tipo de corte diario: apertura (inicio de operaciones) o cierre (fin de día).
enum CutType: String, Codable, Hashable {
    case opening = "Apertura"
    case closing = "Cierre"
}

/// Corte de niveles de tanque, tomado manualmente por el Gerente de Sucursal
/// dos veces al día (apertura y cierre).
struct FuelCut: Identifiable, Codable, Equatable {
    let id: UUID
    var branchID: UUID
    var type: CutType
    var date: Date
    var levels: [FuelType: Double] // nivel leído en cada tanque al momento del corte

    init(id: UUID = UUID(),
         branchID: UUID,
         type: CutType,
         date: Date = Date(),
         levels: [FuelType: Double]) {
        self.id = id
        self.branchID = branchID
        self.type = type
        self.date = date
        self.levels = levels
    }
}
