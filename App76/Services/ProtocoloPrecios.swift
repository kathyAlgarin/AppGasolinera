import Foundation

protocol PreciosService {
    /// Todas las filas de `precios` (el historial completo); el vigente es el más reciente que ya empezó.
    func historial() async throws -> [Precio]
    /// Inserta un precio nuevo en cada sucursal indicada. Devuelve cuántas sucursales se actualizaron.
    func fijar(sucursales: [UUID], combustible: Combustible, precio: Decimal) async throws -> Int
}
