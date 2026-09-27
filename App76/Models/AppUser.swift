import Foundation

/// Usuario del sistema. Puede ser Gerente General (sin sucursal asignada)
/// o Gerente de Sucursal (con una única sucursal asignada).
struct AppUser: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var email: String
    // NOTA: para una app en producción, nunca se debe guardar la contraseña
    // en texto plano. Aquí se simplifica porque es una demo sin backend real.
    var password: String
    var role: UserRole
    var branchID: UUID?
    var isActive: Bool

    init(id: UUID = UUID(),
         name: String,
         email: String,
         password: String,
         role: UserRole,
         branchID: UUID? = nil,
         isActive: Bool = true) {
        self.id = id
        self.name = name
        self.email = email
        self.password = password
        self.role = role
        self.branchID = branchID
        self.isActive = isActive
    }
}
