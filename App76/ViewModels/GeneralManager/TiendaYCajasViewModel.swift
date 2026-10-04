import Foundation

/// 28 · Tienda y cajas (Gerente General, solo consulta): cierres de caja, anulaciones y stock bajo.
@MainActor
final class TiendaYCajasViewModel: ObservableObject {
    struct Datos: Equatable {
        var sucursales: [Sucursal]
        var cajas: [TiendaCaja]
        var anulaciones: [TiendaAnulacion]
        var stockBajo: [StockBajo]
        var ingresos: [TiendaIngreso]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published var sucursalId: UUID?
    @Published var periodo: PeriodoFiltro = .sieteDias
    @Published var desdePersonalizado: Date
    @Published var hastaPersonalizado: Date

    private let dashboard: DashboardService
    private let sucursalesServicio: SucursalesService
    private let ahora: () -> Date

    init(dashboard: DashboardService, sucursales: SucursalesService, ahora: @escaping () -> Date = { Date() }) {
        self.dashboard = dashboard
        self.sucursalesServicio = sucursales
        self.ahora = ahora
        desdePersonalizado = ahora().addingTimeInterval(-6 * 86_400)
        hastaPersonalizado = ahora()
    }

    var rango: (desde: String, hasta: String) {
        periodo.rango(desdePersonalizado: desdePersonalizado, hastaPersonalizado: hastaPersonalizado, ahora: ahora())
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        let (d, h) = rango
        let filtro = sucursalId
        do {
            async let s = sucursalesServicio.listar()
            async let c = dashboard.tiendaCajas(desde: d, hasta: h, sucursalId: filtro)
            async let a = dashboard.tiendaAnulaciones(desde: d, hasta: h, sucursalId: filtro)
            async let b = dashboard.stockBajo(sucursalId: filtro)
            async let i = dashboard.tiendaIngresos(desde: d, hasta: h, sucursalId: filtro)
            let (suc, cajas, anul, stock, ing) = try await (s, c, a, b, i)
            estado = .listo(Datos(sucursales: suc.filter(\.tieneTienda).sorted { $0.nombre < $1.nombre }, cajas: cajas,
                                  anulaciones: anul, stockBajo: stock, ingresos: ing))
        } catch {
            estado.registrarFallo(error)
        }
    }

    func nombreSucursal(_ id: UUID) -> String { estado.valor?.sucursales.first { $0.id == id }?.nombre ?? "Sucursal" }

    var cajas: [TiendaCaja] { estado.valor?.cajas ?? [] }
    var cajasConDiferencia: Int { cajas.filter { ($0.diferenciaUsd ?? 0) != 0 }.count }
    var cajasForzadas: Int { cajas.filter(\.cierreForzado).count }
    var cajasAbiertas: Int { cajas.filter { $0.cerradaEn == nil }.count }

    /// Anulaciones por sucursal en el periodo.
    var anulacionesPorSucursal: [(sucursal: String, ventas: Int, total: Decimal)] {
        let agrupadas = Dictionary(grouping: estado.valor?.anulaciones ?? [], by: \.sucursalId)
        return agrupadas.map { id, filas in
            (nombreSucursal(id), filas.reduce(0) { $0 + $1.ventasAnuladas }, filas.reduce(0) { $0 + $1.totalUsd })
        }
        .sorted { $0.sucursal < $1.sucursal }
    }

    var ingresoTotal: Decimal { (estado.valor?.ingresos ?? []).reduce(0) { $0 + $1.ingresoUsd } }
}

/// Resumen de tienda en el detalle de sucursal (Gerente General).
@MainActor
final class TiendaSucursalResumenViewModel: ObservableObject {
    struct Datos: Equatable {
        var stockBajo: [StockBajo]
        var cajas: [TiendaCaja]
        var ingresos: [TiendaIngreso]
        var anulaciones: [TiendaAnulacion]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    private let sucursalId: UUID
    private let dashboard: DashboardService
    private let ahora: () -> Date

    init(sucursalId: UUID, dashboard: DashboardService, ahora: @escaping () -> Date = { Date() }) {
        self.sucursalId = sucursalId
        self.dashboard = dashboard
        self.ahora = ahora
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        let desde = Fechas.hace(dias: 29, desde: ahora()), hasta = Fechas.hoy(ahora: ahora())
        do {
            async let b = dashboard.stockBajo(sucursalId: sucursalId)
            async let c = dashboard.tiendaCajas(desde: desde, hasta: hasta, sucursalId: sucursalId)
            async let i = dashboard.tiendaIngresos(desde: desde, hasta: hasta, sucursalId: sucursalId)
            async let a = dashboard.tiendaAnulaciones(desde: desde, hasta: hasta, sucursalId: sucursalId)
            let (stock, cajas, ing, anul) = try await (b, c, i, a)
            estado = .listo(Datos(stockBajo: stock, cajas: cajas, ingresos: ing, anulaciones: anul))
        } catch {
            estado.registrarFallo(error)
        }
    }

    var ingreso30Dias: Decimal { (estado.valor?.ingresos ?? []).reduce(0) { $0 + $1.ingresoUsd } }
    var anuladas30Dias: Int { (estado.valor?.anulaciones ?? []).reduce(0) { $0 + $1.ventasAnuladas } }
    var cajasConDiferencia: Int { (estado.valor?.cajas ?? []).filter { ($0.diferenciaUsd ?? 0) != 0 }.count }
}
