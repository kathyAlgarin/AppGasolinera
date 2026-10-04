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

extension Formateadores {
    private static func numero(_ decimales: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_SV")
        f.numberStyle = .decimal
        f.minimumFractionDigits = decimales
        f.maximumFractionDigits = decimales
        return f
    }
    private static let unDecimal = numero(1)
    private static let sinDecimales = numero(0)
    private static let dos = numero(2)

    /// 1234.5 → "1,234.50"
    static func numeroDosDecimales(_ valor: Decimal) -> String {
        dos.string(from: valor as NSDecimalNumber) ?? "0.00"
    }

    static func porcentaje(_ valor: Decimal) -> String {
        "\(unDecimal.string(from: valor as NSDecimalNumber) ?? "0.0") %"
    }

    static func entero(_ valor: Int) -> String {
        sinDecimales.string(from: NSNumber(value: valor)) ?? "\(valor)"
    }

    static func dias(_ valor: Decimal) -> String {
        "\(unDecimal.string(from: valor as NSDecimalNumber) ?? "0.0") días"
    }

    /// Con signo explícito, para diferencias: "+1.20 gal", "−0.50 gal".
    static func galonesConSigno(_ valor: Decimal) -> String {
        let signo = valor > 0 ? "+" : (valor < 0 ? "−" : "")
        let absoluto = valor < 0 ? -valor : valor
        return "\(signo)\(numeroDosDecimales(absoluto)) gal"
    }

    static func dolaresConSigno(_ valor: Decimal) -> String {
        let signo = valor > 0 ? "+" : (valor < 0 ? "−" : "")
        let absoluto = valor < 0 ? -valor : valor
        return "\(signo)$\(numeroDosDecimales(absoluto))"
    }

    /// Para precargar un campo de texto con un valor del servidor ("12.5" → "12.50").
    static func paraCampo(_ valor: Decimal) -> String {
        var v = valor
        var r = Decimal()
        NSDecimalRound(&r, &v, 2, .plain)
        return NSDecimalNumber(decimal: r).stringValue
    }
}
