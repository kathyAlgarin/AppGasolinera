import Foundation

/// Roles disponibles dentro del sistema.
enum UserRole: String, Codable, Hashable {
    case generalManager = "Gerente General"
    case branchManager = "Gerente de Sucursal"
}
