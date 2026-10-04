import Foundation

/// Fechas "del día" y filtros: siempre en la zona horaria de El Salvador (UTC−6, sin horario de verano).
enum Fechas {
    static let zona = TimeZone(identifier: "America/El_Salvador") ?? TimeZone(secondsFromGMT: -6 * 3600)!
    static let locale = Locale(identifier: "es_SV")

    static let calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zona
        c.locale = locale
        c.firstWeekday = 2
        return c
    }()

    private static func formato(_ patron: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = zona
        f.dateFormat = patron
        return f
    }

    private static let diaISO = formato("yyyy-MM-dd")
    private static let diaLargo = formato("d MMM yyyy")
    private static let diaCorto = formato("d MMM")
    private static let diaSemanaLargo = formato("EEEE d MMM")
    private static let fechaHoraF = formato("d MMM yyyy, h:mm a")
    private static let horaF = formato("h:mm a")

    // MARK: Cadenas de día (yyyy-MM-dd), como las entrega el servidor en `fecha_operativa`

    static func diaISO(_ fecha: Date) -> String { diaISO.string(from: fecha) }

    static func hoy(ahora: Date = Date()) -> String { diaISO(ahora) }

    static func hace(dias: Int, desde ahora: Date = Date()) -> String {
        diaISO(calendario.date(byAdding: .day, value: -dias, to: ahora) ?? ahora)
    }

    static func fecha(deDia dia: String) -> Date? { diaISO.date(from: dia) }

    // MARK: Para mostrar

    static func dia(_ dia: String) -> String {
        guard let f = fecha(deDia: dia) else { return dia }
        return diaLargo.string(from: f)
    }

    static func diaCorto(_ dia: String) -> String {
        guard let f = fecha(deDia: dia) else { return dia }
        return diaCorto.string(from: f)
    }

    static func diaConSemana(_ dia: String) -> String {
        guard let f = fecha(deDia: dia) else { return dia }
        return diaSemanaLargo.string(from: f).capitalized(with: locale)
    }

    static func fechaHora(_ fecha: Date) -> String { fechaHoraF.string(from: fecha) }
    static func hora(_ fecha: Date) -> String { horaF.string(from: fecha) }

    /// "06:00:00" → "6:00 a. m."
    static func hora(deTexto texto: String) -> String {
        let partes = texto.split(separator: ":")
        guard partes.count >= 2, let h = Int(partes[0]), let m = Int(partes[1]) else { return texto }
        var c = DateComponents()
        c.hour = h
        c.minute = m
        guard let f = calendario.date(from: c) else { return texto }
        return horaF.string(from: f)
    }

    /// Día de la semana ISO (1 = lunes … 7 = domingo) de una fecha, en la zona de El Salvador.
    static func diaIso(_ fecha: Date) -> Int {
        let w = calendario.component(.weekday, from: fecha) // 1 = domingo
        return w == 1 ? 7 : w - 1
    }

    static let nombresDias = ["", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    static let letrasDias = ["", "L", "M", "X", "J", "V", "S", "D"]

    // MARK: Lectura de timestamptz que entrega Postgres

    private static let isoFraccion: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoSimple = ISO8601DateFormatter()

    /// Acepta "2026-10-04T04:31:21.123456+00:00", con o sin fracción de segundo.
    static func parsearTimestamp(_ texto: String) -> Date? {
        if let punto = texto.firstIndex(of: ".") {
            var fin = texto.index(after: punto)
            while fin < texto.endIndex, texto[fin].isNumber { fin = texto.index(after: fin) }
            let digitos = texto[texto.index(after: punto)..<fin]
            let milis = String(digitos.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
            let normal = String(texto[..<punto]) + "." + milis + String(texto[fin...])
            return isoFraccion.date(from: normal)
        }
        return isoSimple.date(from: texto)
    }

    /// Inicio de un día (en El Salvador) como `Date`, para comparar.
    static func inicioDeDia(_ fecha: Date) -> Date { calendario.startOfDay(for: fecha) }
}

extension Fechas {
    /// Un `Date` (de un selector de hora) → "HH:mm:00" en la zona de El Salvador, como lo espera la columna `time`.
    static func horaTexto(de fecha: Date) -> String {
        let c = calendario.dateComponents([.hour, .minute], from: fecha)
        return String(format: "%02d:%02d:00", c.hour ?? 0, c.minute ?? 0)
    }

    /// "22:00:00" → un `Date` de hoy a esa hora, para precargar un selector de hora.
    static func fecha(deHora texto: String, base: Date = Date()) -> Date {
        let partes = texto.split(separator: ":")
        var c = calendario.dateComponents([.year, .month, .day], from: base)
        c.hour = partes.count > 0 ? Int(partes[0]) ?? 0 : 0
        c.minute = partes.count > 1 ? Int(partes[1]) ?? 0 : 0
        return calendario.date(from: c) ?? base
    }

    /// "06:00:00" → "06:00" (comparable y corto).
    static func horaCorta(_ texto: String) -> String { String(texto.prefix(5)) }
}
