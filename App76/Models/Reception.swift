import Foundation

/// Registro de recepción de combustible (llegada de camión cisterna).
struct Reception: Identifiable, Codable, Equatable {
    let id: UUID
    var branchID: UUID
    var fuelType: FuelType
    var quantity: Double // litros recibidos
    var date: Date

    init(id: UUID = UUID(),
         branchID: UUID,
         fuelType: FuelType,
         quantity: Double,
         date: Date = Date()) {
        self.id = id
        self.branchID = branchID
        self.fuelType = fuelType
        self.quantity = quantity
        self.date = date
    }
}
