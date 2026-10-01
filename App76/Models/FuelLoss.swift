import Foundation

/// Pérdida de combustible (fuga, derrame, evaporación…) registrada con su razón.
struct FuelLoss: Identifiable, Codable, Equatable {
    let id: UUID
    var branchID: UUID
    var fuelType: FuelType
    var liters: Double
    var reason: String
    var date: Date

    init(id: UUID = UUID(),
         branchID: UUID,
         fuelType: FuelType,
         liters: Double,
         reason: String,
         date: Date = Date()) {
        self.id = id
        self.branchID = branchID
        self.fuelType = fuelType
        self.liters = liters
        self.reason = reason
        self.date = date
    }
}
