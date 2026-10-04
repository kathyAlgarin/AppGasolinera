import Foundation

/// Solo para **mostrar** cantidades. La app nunca calcula totales, cuadres ni precios: los entrega el servidor.
enum Formateadores {
    private static func crear(decimales: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_SV")
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimales
        f.maximumFractionDigits = decimales
        return f
    }

    private static let dosDecimales = crear(decimales: 2)

    static func galones(_ valor: Decimal) -> String {
        "\(dosDecimales.string(from: valor as NSDecimalNumber) ?? "0.00") gal"
    }

    static func dolares(_ valor: Decimal) -> String {
        "$\(dosDecimales.string(from: valor as NSDecimalNumber) ?? "0.00")"
    }
}
