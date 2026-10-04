import Foundation

protocol SucursalesService {
    /// Todas las que el usuario puede ver (el Gerente General, todas; el de Sucursal, la suya).
    func listar() async throws -> [Sucursal]
    func tanques() async throws -> [Tanque]
    func crear(nombre: String, direccion: String, tieneTienda: Bool, tanques: [TanqueNuevo]) async throws -> UUID
    func editar(id: UUID, nombre: String, direccion: String) async throws
    func cambiarEstado(id: UUID, activa: Bool) async throws
    func configurarTienda(id: UUID, tieneTienda: Bool) async throws
}
