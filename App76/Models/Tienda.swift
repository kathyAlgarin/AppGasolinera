import Foundation

struct Articulo: Codable, Hashable, Identifiable {
    let id: UUID
    var nombre: String
    var categoria: CategoriaArticulo
    var tipo: TipoArticulo
    var precioUsd: Decimal
    var activo: Bool
}

struct InventarioSucursal: Codable, Hashable, Identifiable {
    let sucursalId: UUID
    let articuloId: UUID
    let stock: Int
    let stockMinimo: Int

    var id: UUID { articuloId }
    var stockBajo: Bool { stock <= stockMinimo }
}

struct EntradaInventario: Codable, Hashable, Identifiable {
    let id: UUID
    let corteId: UUID
    let articuloId: UUID
    let cantidad: Int
    let proveedor: String?
    let creadoEn: Date
}

struct BajaInventario: Codable, Hashable, Identifiable {
    let id: UUID
    let corteId: UUID
    let articuloId: UUID
    let cantidad: Int
    let motivo: MotivoBaja
    let nota: String?
    let creadoEn: Date
}

struct SesionCaja: Codable, Hashable, Identifiable {
    let id: UUID
    let sucursalId: UUID
    let cajeroId: UUID
    let corteId: UUID
    let fondoInicialUsd: Decimal
    let abiertaEn: Date
    let cerradaEn: Date?
    let efectivoContadoUsd: Decimal?
    let efectivoEsperadoUsd: Decimal?
    let diferenciaUsd: Decimal?
    let cierreForzado: Bool
    let motivoCierreForzado: String?

    var estaAbierta: Bool { cerradaEn == nil }
}

struct Venta: Codable, Hashable, Identifiable {
    let id: UUID
    let sucursalId: UUID
    let sesionCajaId: UUID
    let corteId: UUID
    let cajeroId: UUID
    let numero: Int
    let totalUsd: Decimal
    let metodoPago: MetodoPago
    let recibidoUsd: Decimal?
    let vueltoUsd: Decimal?
    let estado: EstadoVenta
    let anuladaEn: Date?
    let motivoAnulacion: String?
    let creadoEn: Date
}

struct VentaLinea: Codable, Hashable, Identifiable {
    let id: UUID
    let ventaId: UUID
    let articuloId: UUID
    let cantidad: Int
    let precioUnitarioUsd: Decimal
    let subtotalUsd: Decimal
}

struct LineaVenta: Codable, Hashable {
    let articuloId: UUID
    let cantidad: Int
}

/// Resultado de `registrar_venta`: total y vuelto los calcula el servidor.
struct ResultadoVenta: Codable, Hashable {
    let ventaId: UUID
    let numero: Int
    let totalUsd: Decimal
    let recibidoUsd: Decimal?
    let vueltoUsd: Decimal?
}

/// Resultado de `cerrar_caja` y `cerrar_caja_forzado`.
struct ResultadoCierreCaja: Codable, Hashable {
    let esperadoUsd: Decimal
    let contadoUsd: Decimal
    let diferenciaUsd: Decimal
}

/// `v_tienda_ingresos`
struct TiendaIngreso: Codable, Hashable, Identifiable {
    let sucursalId: UUID
    let fechaOperativa: String
    let categoria: CategoriaArticulo
    let unidades: Int
    @DecimalOCero var ingresoUsd: Decimal
    var id: String { "\(sucursalId.uuidString)-\(fechaOperativa)-\(categoria.rawValue)" }
}

/// `v_tienda_anulaciones`
struct TiendaAnulacion: Codable, Hashable, Identifiable {
    let sucursalId: UUID
    let fechaOperativa: String
    let ventasAnuladas: Int
    @DecimalOCero var totalUsd: Decimal
    var id: String { "\(sucursalId.uuidString)-\(fechaOperativa)" }
}

/// `v_tienda_cajas`: cada cierre (o apertura) de caja.
struct TiendaCaja: Codable, Hashable, Identifiable {
    let sesionId: UUID
    let sucursalId: UUID
    let cajeroId: UUID
    let cajeroNombre: String
    let fechaOperativa: String?
    let abiertaEn: Date
    let cerradaEn: Date?
    @DecimalOCero var fondoInicialUsd: Decimal
    let efectivoEsperadoUsd: Decimal?
    let efectivoContadoUsd: Decimal?
    let diferenciaUsd: Decimal?
    let cierreForzado: Bool
    var id: UUID { sesionId }
}

/// `v_stock_bajo`
struct StockBajo: Codable, Hashable, Identifiable {
    let sucursalId: UUID
    let articuloId: UUID
    let nombre: String
    let categoria: CategoriaArticulo
    let stock: Int
    let stockMinimo: Int
    var id: String { "\(sucursalId.uuidString)-\(articuloId.uuidString)" }
}

/// Una caja del corte con el nombre de su cajero.
struct CajaDelCorte: Hashable, Identifiable {
    let sesion: SesionCaja
    let cajeroNombre: String
    var id: UUID { sesion.id }
}

/// Artículo del POS con su stock en la sucursal (`nil` en los servicios, que no llevan inventario).
struct ArticuloPOS: Hashable, Identifiable {
    let articulo: Articulo
    let stock: Int?
    var id: UUID { articulo.id }
    var disponible: Bool { stock.map { $0 > 0 } ?? true }
}
