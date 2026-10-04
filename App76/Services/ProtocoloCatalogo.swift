import Foundation

protocol CatalogoService {
    /// El Gerente General ve todo el catálogo; los demás solo los activos.
    func listar() async throws -> [Articulo]
    func crear(nombre: String, categoria: CategoriaArticulo, tipo: TipoArticulo, precioUsd: Decimal, activo: Bool) async throws
    func editar(id: UUID, nombre: String, precioUsd: Decimal, activo: Bool) async throws
}
