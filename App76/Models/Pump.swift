import Foundation

/// Bomba (surtidor) de una sucursal. Cada bomba puede despachar
/// cualquiera de los tres tipos de combustible.
struct Pump: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var number: Int

    var name: String { "Bomba \(number)" }

    init(id: UUID = UUID(), number: Int) {
        self.id = id
        self.number = number
    }
}
