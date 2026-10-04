import Foundation

/// Inventario, entradas y bajas, ventas y cajas de la tienda (lado del Gerente de Sucursal).
protocol TiendaService {
    /// Cajas abiertas de la sucursal (bloquean el cierre del corte).
    func cajasAbiertas(sucursalId: UUID) async throws -> Int

    func inventario(sucursalId: UUID) async throws -> [InventarioSucursal]
    func entradas(corteId: UUID) async throws -> [EntradaInventario]
    func bajas(corteId: UUID) async throws -> [BajaInventario]
    func registrarEntrada(corteId: UUID, articuloId: UUID, cantidad: Int, proveedor: String?) async throws
    func eliminarEntrada(id: UUID) async throws
    func registrarBaja(corteId: UUID, articuloId: UUID, cantidad: Int, motivo: MotivoBaja, nota: String?) async throws
    func eliminarBaja(id: UUID) async throws
    func fijarStockMinimo(articuloId: UUID, minimo: Int) async throws

    func ventas(corteId: UUID) async throws -> [Venta]
    func lineas(ventaId: UUID) async throws -> [VentaLinea]
    func anularVenta(ventaId: UUID, motivo: String) async throws

    func cajas(corteId: UUID) async throws -> [CajaDelCorte]
    func cerrarCajaForzado(sesionId: UUID, contado: Decimal, motivo: String) async throws -> ResultadoCierreCaja
}

/// La caja y el POS del Cajero.
protocol CajaService {
    /// La caja abierta del cajero, si tiene una.
    func sesionAbierta() async throws -> SesionCaja?
    func abrir(fondo: Decimal) async throws
    /// Artículos activos con su stock en la sucursal.
    func catalogo() async throws -> [ArticuloPOS]
    func registrarVenta(sesionId: UUID, metodo: MetodoPago, recibido: Decimal?, lineas: [LineaVenta]) async throws -> ResultadoVenta
    func ventas(sesionId: UUID) async throws -> [Venta]
    func lineas(ventaId: UUID) async throws -> [VentaLinea]
    func cerrar(sesionId: UUID, contado: Decimal) async throws -> ResultadoCierreCaja
}
