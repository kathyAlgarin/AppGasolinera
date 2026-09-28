import Foundation

/// Estado operativo de un tanque según su nivel (alerta de reabastecimiento).
enum TankStatus: String {
    case critical = "Crítico"
    case medium = "Medio"
    case optimal = "Óptimo"
}

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

    var fillRatio: Double {
        guard capacity > 0 else { return 0 }
        return min(max(currentLevel / capacity, 0), 1)
    }

    /// Crítico ≤ 20 %, medio ≤ 50 %, óptimo por encima.
    var status: TankStatus {
        if fillRatio <= 0.20 { return .critical }
        if fillRatio <= 0.50 { return .medium }
        return .optimal
    }
}
