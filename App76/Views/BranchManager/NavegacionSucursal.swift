import SwiftUI

/// Rutas dentro de la pestaña «Corte» (permite volver al inicio del corte desde cualquier pantalla).
enum RutaCorte: Hashable {
    case bombas
    case bomba(UUID)
    case compras
    case perdidas
    case niveles
    case tienda
    case resumen
    case cerrado(ResultadoCierreCorte)
    case reporte(UUID)
}

enum PestanaSucursal: Hashable { case inicio, corte, tienda, personal, mas }

/// Estado de navegación compartido entre las pestañas del Gerente de Sucursal.
@MainActor
final class NavegacionSucursal: ObservableObject {
    @Published var pestana: PestanaSucursal = .inicio
    @Published var rutaCorte: [RutaCorte] = []

    func abrir(_ ruta: RutaCorte?) {
        pestana = .corte
        rutaCorte = ruta.map { [$0] } ?? []
    }
}
