import Foundation

/// Tipos de combustible que maneja la gasolinera.
enum FuelType: String, CaseIterable, Codable, Identifiable, Hashable {
    case regular = "Regular"
    case premium = "Súper"
    case diesel = "Diésel"

    var id: String { rawValue }

    /// Ícono SF Symbols asociado a cada tipo de combustible.
    var symbolName: String {
        switch self {
        case .regular: return "fuelpump"
        case .premium: return "fuelpump.fill"
        case .diesel: return "fuelpump.circle"
        }
    }
}
