import Foundation

/// Una sucursal de la gasolinera, con sus tanques de combustible.
struct Branch: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var tanks: [Tank]
    var isActive: Bool

    init(id: UUID = UUID(),
         name: String,
         address: String,
         tanks: [Tank],
         isActive: Bool = true) {
        self.id = id
        self.name = name
        self.address = address
        self.tanks = tanks
        self.isActive = isActive
    }
}
