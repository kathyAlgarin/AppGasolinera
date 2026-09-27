import Foundation

/// Precio vigente por litro para un tipo de combustible en una sucursal.
/// El precio puede variar entre sucursales.
struct FuelPrice: Identifiable, Codable, Equatable {
    let id: UUID
    var branchID: UUID
    var fuelType: FuelType
    var pricePerLiter: Double
    var updatedAt: Date

    init(id: UUID = UUID(),
         branchID: UUID,
         fuelType: FuelType,
         pricePerLiter: Double,
         updatedAt: Date = Date()) {
        self.id = id
        self.branchID = branchID
        self.fuelType = fuelType
        self.pricePerLiter = pricePerLiter
        self.updatedAt = updatedAt
    }
}

/// Registro histórico de cambios de precio (auditoría).
struct PriceHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var branchID: UUID
    var fuelType: FuelType
    var oldPrice: Double
    var newPrice: Double
    var changedAt: Date

    init(id: UUID = UUID(),
         branchID: UUID,
         fuelType: FuelType,
         oldPrice: Double,
         newPrice: Double,
         changedAt: Date = Date()) {
        self.id = id
        self.branchID = branchID
        self.fuelType = fuelType
        self.oldPrice = oldPrice
        self.newPrice = newPrice
        self.changedAt = changedAt
    }
}
