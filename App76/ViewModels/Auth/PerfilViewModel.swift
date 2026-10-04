import Foundation

@MainActor
final class PerfilViewModel: ObservableObject {
    @Published private(set) var sucursal: Carga<String?> = .inicial
    let perfil: Perfil
    private let sucursales: SucursalesService

    init(perfil: Perfil, sucursales: SucursalesService) {
        self.perfil = perfil
        self.sucursales = sucursales
    }

    func cargar() async {
        guard let id = perfil.sucursalId else {
            sucursal = .listo(nil)
            return
        }
        sucursal = .cargando
        do {
            let todas = try await sucursales.listar()
            sucursal = .listo(todas.first { $0.id == id }?.nombre)
        } catch {
            sucursal.registrarFallo(error)
        }
    }
}
