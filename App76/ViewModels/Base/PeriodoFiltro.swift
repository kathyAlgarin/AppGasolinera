import Foundation

/// Periodos de los paneles: Hoy, 7 días, 30 días o un rango personalizado (nunca en el futuro).
enum PeriodoFiltro: String, CaseIterable, Identifiable {
    case hoy = "Hoy"
    case sieteDias = "7 días"
    case treintaDias = "30 días"
    case personalizado = "Fechas"
    var id: String { rawValue }

    /// Días "yyyy-MM-dd" incluidos; el personalizado se recorta a hoy y nunca se invierte.
    func rango(desdePersonalizado: Date, hastaPersonalizado: Date, ahora: Date) -> (desde: String, hasta: String) {
        let hoy = Fechas.hoy(ahora: ahora)
        switch self {
        case .hoy: return (hoy, hoy)
        case .sieteDias: return (Fechas.hace(dias: 6, desde: ahora), hoy)
        case .treintaDias: return (Fechas.hace(dias: 29, desde: ahora), hoy)
        case .personalizado:
            let h = min(Fechas.diaISO(hastaPersonalizado), hoy)
            let d = min(Fechas.diaISO(desdePersonalizado), h)
            return (d, h)
        }
    }

    static func dias(desde: String, hasta: String) -> [String] {
        var resultado: [String] = []
        var actual = Fechas.fecha(deDia: desde)
        let limite = Fechas.fecha(deDia: hasta)
        while let a = actual, let l = limite, a <= l, resultado.count < 400 {
            resultado.append(Fechas.diaISO(a))
            actual = Fechas.calendario.date(byAdding: .day, value: 1, to: a)
        }
        return resultado
    }
}
