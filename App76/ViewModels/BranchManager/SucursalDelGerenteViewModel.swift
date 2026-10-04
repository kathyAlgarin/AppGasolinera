import Foundation

/// Datos de la sucursal del Gerente de Sucursal que deciden qué pestañas ve (la tienda y los cajeros solo si hay tienda).
@MainActor
final class SucursalDelGerenteViewModel: ObservableObject {
    @Published private(set) var sucursal: Carga<Sucursal> = .inicial
    private let sucursalId: UUID
    private let servicio: SucursalesService

    init(sucursalId: UUID, servicio: SucursalesService) {
        self.sucursalId = sucursalId
        self.servicio = servicio
    }

    var tieneTienda: Bool { sucursal.valor?.tieneTienda ?? false }

    func cargar() async {
        if sucursal.valor == nil { sucursal = .cargando }
        do {
            guard let s = try await servicio.listar().first(where: { $0.id == sucursalId }) else {
                sucursal = .error("No se encontró tu sucursal.")
                return
            }
            sucursal = .listo(s)
        } catch {
            sucursal.registrarFallo(error)
        }
    }
}
