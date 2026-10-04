import Foundation

/// Lecturas agregadas para los paneles. Solo cuentan cortes cerrados.
protocol DashboardService {
    /// Métricas por sucursal, día operativo y combustible. `desde`/`hasta` son días "yyyy-MM-dd" (incluidos).
    func combustible(desde: String, hasta: String, sucursalId: UUID?) async throws -> [DashboardCombustible]
    /// Cortes cerrados cuya fecha operativa cae en el periodo.
    func cortesCerrados(desde: String, hasta: String, sucursalId: UUID?) async throws -> [Corte]
    func tiendaIngresos(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaIngreso]
    func tiendaAnulaciones(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaAnulacion]
    func tiendaCajas(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaCaja]
    func stockBajo(sucursalId: UUID?) async throws -> [StockBajo]
}
