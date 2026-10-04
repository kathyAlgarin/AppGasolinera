import Foundation

/// Los cuatro estados de toda pantalla con datos: cargando, error (con reintento), vacío y contenido.
/// «Vacío» lo decide la vista según el contenido (una lista sin elementos).
enum Carga<Valor> {
    case inicial
    case cargando
    case error(String)
    case listo(Valor)

    var valor: Valor? {
        if case .listo(let v) = self { return v }
        return nil
    }

    var estaCargando: Bool {
        switch self {
        case .inicial, .cargando: return true
        default: return false
        }
    }

    var mensajeError: String? {
        if case .error(let m) = self { return m }
        return nil
    }
}

extension Carga: Equatable where Valor: Equatable {}

/// Mensaje de un error para mostrarlo; las cancelaciones no se muestran.
func mensajeDe(_ error: Error) -> String? {
    if error is CancellationError { return nil }
    return error.localizedDescription
}

extension Carga {
    /// Si una recarga falla y ya había datos en pantalla, se conservan; si no había, se muestra el error con «Reintentar».
    mutating func registrarFallo(_ error: Error) {
        guard let mensaje = mensajeDe(error) else { return }
        if valor == nil { self = .error(mensaje) }
    }
}
