import Foundation

/// Una sucursal de la gasolinera, con sus tanques de combustible y sus bombas.
struct Branch: Identifiable, Codable, Equatable, Hashable {
    static let pumpsPerBranch = 6

    static func makePumps() -> [Pump] {
        (1...pumpsPerBranch).map { Pump(number: $0) }
    }

    let id: UUID
    var name: String
    var address: String
    var tanks: [Tank]
    var pumps: [Pump]
    var isActive: Bool

    init(id: UUID = UUID(),
         name: String,
         address: String,
         tanks: [Tank],
         pumps: [Pump] = Branch.makePumps(),
         isActive: Bool = true) {
        self.id = id
        self.name = name
        self.address = address
        self.tanks = tanks
        self.pumps = pumps
        self.isActive = isActive
    }
}
