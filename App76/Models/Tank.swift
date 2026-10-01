import Foundation

/// Un tanque de combustible dentro de una sucursal.
struct Tank: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var fuelType: FuelType
    var capacity: Double      // litros
    var currentLevel: Double  // litros actuales

    init(id: UUID = UUID(), fuelType: FuelType, capacity: Double, currentLevel: Double) {
        self.id = id
        self.fuelType = fuelType
        self.capacity = capacity
        self.currentLevel = currentLevel
    }

    /// Proporción de llenado entre 0 y 1.
    var fillRatio: Double {
        guard capacity > 0 else { return 0 }
        return min(currentLevel / capacity, 1)
    }
}
