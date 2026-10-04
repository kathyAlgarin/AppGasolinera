import SwiftUI
import UIKit

/// Paleta de colores inspirada en la identidad de Gasolinera 76:
/// naranja como color principal/de acento y azul oscuro como secundario.
extension Color {
    static let gas76Orange = Color(red: 0.94, green: 0.42, blue: 0.10)
    static let gas76Blue = Color(red: 0.08, green: 0.16, blue: 0.32)
    static let gas76Background = Color(UIColor.systemGroupedBackground)
    static let gas76Card = Color(UIColor.secondarySystemGroupedBackground)
}

extension Color {
    static let gas76Verde = Color(red: 0.13, green: 0.60, blue: 0.33)
    static let gas76Rojo = Color(red: 0.84, green: 0.18, blue: 0.18)
    static let gas76Amarillo = Color(red: 0.93, green: 0.65, blue: 0.05)
    static let gas76Gris = Color(UIColor.systemGray)
}

extension NivelAlerta {
    var color: Color {
        switch self {
        case .critico: return .gas76Rojo
        case .medio: return .gas76Orange
        case .optimo: return .gas76Verde
        }
    }
}

extension Combustible {
    var color: Color {
        switch self {
        case .superior: return .gas76Rojo
        case .regular: return .gas76Verde
        case .diesel: return .gas76Blue
        }
    }
}
