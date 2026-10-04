import Foundation

@MainActor
final class CatalogoViewModel: ObservableObject {
    @Published private(set) var estado: Carga<[Articulo]> = .inicial
    private let servicio: CatalogoService

    init(servicio: CatalogoService) { self.servicio = servicio }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            estado = .listo(try await servicio.listar().sorted { ($0.activo ? 0 : 1, $0.nombre) < ($1.activo ? 0 : 1, $1.nombre) })
        } catch {
            estado.registrarFallo(error)
        }
    }
}
