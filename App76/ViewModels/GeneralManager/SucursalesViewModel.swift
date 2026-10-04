import Foundation

@MainActor
final class SucursalesViewModel: ObservableObject {
    @Published private(set) var estado: Carga<[Sucursal]> = .inicial
    private let servicio: SucursalesService

    init(servicio: SucursalesService) { self.servicio = servicio }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            // Las activas primero, por nombre.
            let todas = try await servicio.listar()
            estado = .listo(todas.sorted { ($0.activa ? 0 : 1, $0.nombre) < ($1.activa ? 0 : 1, $1.nombre) })
        } catch {
            estado.registrarFallo(error)
        }
    }
}
