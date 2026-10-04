import Foundation

/// Validaciones de captura. Se aplican en la app **y** el servidor las vuelve a aplicar (CHECK y funciones).
enum Validadores {
    /// Deja solo dígitos y un punto decimal; la coma pasa a punto; recorta los decimales sobrantes.
    /// Descarta letras y signos (también el negativo) al escribir o pegar.
    static func filtrarDecimal(_ texto: String, maxDecimales: Int = 2) -> String {
        var resultado = ""
        var hayPunto = false
        var decimales = 0
        for caracter in texto {
            if caracter.isASCII, caracter.isNumber {
                if hayPunto {
                    guard decimales < maxDecimales else { continue }
                    decimales += 1
                }
                resultado.append(caracter)
            } else if (caracter == "." || caracter == ","), !hayPunto, maxDecimales > 0 {
                hayPunto = true
                resultado.append(".")
            }
        }
        return resultado
    }

    static func filtrarEntero(_ texto: String) -> String {
        String(texto.filter { $0.isASCII && $0.isNumber })
    }

    /// Texto → `Decimal`. `nil` si está vacío o no es un número válido.
    static func decimal(_ texto: String) -> Decimal? {
        let t = texto.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t != "." else { return nil }
        return Decimal(string: t, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func entero(_ texto: String) -> Int? {
        let t = texto.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : Int(t)
    }

    static func esCorreoValido(_ texto: String) -> Bool {
        let t = correo(texto)
        guard t.count <= 254, t.contains("@") else { return false }
        let partes = t.split(separator: "@", omittingEmptySubsequences: false)
        guard partes.count == 2, !partes[0].isEmpty, !partes[1].isEmpty else { return false }
        let dominio = partes[1]
        guard dominio.contains("."), !dominio.hasPrefix("."), !dominio.hasSuffix("."), !t.contains(" ") else { return false }
        return true
    }

    /// El correo se limpia de espacios y se pasa a minúsculas (el teclado suele agregar un espacio al autocompletar).
    static func correo(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func passwordValida(_ texto: String, minimo: Int = 8, maximo: Int = 72) -> Bool {
        texto.count >= minimo && texto.count <= maximo
    }

    static func textoLimpio(_ texto: String) -> String {
        texto.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
