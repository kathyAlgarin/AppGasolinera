import Foundation

/// 10 · Panel del Gerente General: filtros de sucursal y periodo; todo sale de cortes cerrados.
@MainActor
final class PanelViewModel: ObservableObject {
    typealias Periodo = PeriodoFiltro

    struct Datos: Equatable {
        var sucursales: [Sucursal]
        var filas: [DashboardCombustible]
        var tanques: [EstadoTanque]
        var cortes: [Corte]
        var cortesHoy: [Corte]
        var cortesConDiferencia: Int
        var ingresosTienda: [TiendaIngreso]
        var anulaciones: [TiendaAnulacion]
        var cajas: [TiendaCaja]
        var stockBajo: [StockBajo]
    }

    struct TotalCombustible: Equatable, Identifiable {
        let combustible: Combustible
        var galones: Decimal
        var ingreso: Decimal
        var compras: Decimal
        var perdidas: Decimal
        var id: Combustible { combustible }
    }

    struct PuntoTendencia: Equatable, Identifiable {
        let dia: String
        let combustible: Combustible
        let galones: Decimal
        var id: String { "\(dia)-\(combustible.rawValue)" }
    }

    struct FilaRanking: Equatable, Identifiable {
        let sucursal: Sucursal
        var galones: Decimal
        var ingreso: Decimal
        var id: UUID { sucursal.id }
    }

    struct FilaSucursalCombustible: Equatable, Identifiable {
        let sucursal: Sucursal
        var galones: Decimal
        var compras: Decimal
        var perdidas: Decimal
        var tanque: EstadoTanque?
        var id: UUID { sucursal.id }
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published var sucursalId: UUID?
    @Published var periodo: Periodo = .hoy
    @Published var desdePersonalizado: Date
    @Published var hastaPersonalizado: Date

    private let sucursalesServicio: SucursalesService
    private let dashboard: DashboardService
    private let tanquesServicio: TanquesService
    private let reportes: ReportesService
    private let ahora: () -> Date

    init(sucursales: SucursalesService, dashboard: DashboardService, tanques: TanquesService, reportes: ReportesService,
         ahora: @escaping () -> Date = { Date() }) {
        self.sucursalesServicio = sucursales
        self.dashboard = dashboard
        self.tanquesServicio = tanques
        self.reportes = reportes
        self.ahora = ahora
        desdePersonalizado = ahora().addingTimeInterval(-6 * 86_400)
        hastaPersonalizado = ahora()
    }

    // MARK: Rango

    var hoy: String { Fechas.hoy(ahora: ahora()) }

    /// Días "yyyy-MM-dd" incluidos, según el periodo. El personalizado nunca llega al futuro ni se invierte.
    var rango: (desde: String, hasta: String) {
        periodo.rango(desdePersonalizado: desdePersonalizado, hastaPersonalizado: hastaPersonalizado, ahora: ahora())
    }

    var dias: [String] { PeriodoFiltro.dias(desde: rango.desde, hasta: rango.hasta) }

    // MARK: Carga

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        let (desde, hasta) = rango
        let filtro = sucursalId
        let dia = hoy
        do {
            async let sucursales = sucursalesServicio.listar()
            async let filas = dashboard.combustible(desde: desde, hasta: hasta, sucursalId: filtro)
            async let tanques = tanquesServicio.estado(sucursalId: filtro)
            async let cortes = dashboard.cortesCerrados(desde: desde, hasta: hasta, sucursalId: filtro)
            async let cortesHoy = dashboard.cortesCerrados(desde: dia, hasta: dia, sucursalId: filtro)
            async let ingresos = dashboard.tiendaIngresos(desde: desde, hasta: hasta, sucursalId: filtro)
            async let anulaciones = dashboard.tiendaAnulaciones(desde: desde, hasta: hasta, sucursalId: filtro)
            async let cajas = dashboard.tiendaCajas(desde: desde, hasta: hasta, sucursalId: filtro)
            async let stock = dashboard.stockBajo(sucursalId: filtro)
            let (s, f, t, c, ch, i, a, ca, sb) = try await (sucursales, filas, tanques, cortes, cortesHoy, ingresos, anulaciones, cajas, stock)
            let resumenes = try await reportes.resumenes(corteIds: c.map(\.id))
            let conDiferencia = Set(resumenes.filter(\.hayDiferencia).map(\.corteId)).count
            estado = .listo(Datos(sucursales: s.sorted { $0.nombre < $1.nombre }, filas: f, tanques: t, cortes: c, cortesHoy: ch,
                                  cortesConDiferencia: conDiferencia, ingresosTienda: i, anulaciones: a, cajas: ca, stockBajo: sb))
        } catch {
            estado.registrarFallo(error)
        }
    }

    // MARK: Derivados (agrupan lo que ya calculó el servidor; no recalculan reglas)

    var datos: Datos? { estado.valor }

    /// `true` cuando todavía no hay ninguna sucursal activa: no hay datos que mostrar (no es lo mismo que «sin cortes»).
    var sinSucursales: Bool { datos.map { !$0.sucursales.contains { $0.activa } } ?? false }

    var sucursalesActivasEnFiltro: [Sucursal] {
        (datos?.sucursales ?? []).filter { $0.activa && (sucursalId == nil || $0.id == sucursalId) }
    }

    var totales: [TotalCombustible] {
        Combustible.allCases.map { c in
            let filas = (datos?.filas ?? []).filter { $0.combustible == c }
            return TotalCombustible(combustible: c, galones: filas.reduce(0) { $0 + $1.galonesVendidos },
                                    ingreso: filas.reduce(0) { $0 + $1.ingresoUsd },
                                    compras: filas.reduce(0) { $0 + $1.comprasGal }, perdidas: filas.reduce(0) { $0 + $1.perdidasGal })
        }
    }

    var galonesTotales: Decimal { totales.reduce(0) { $0 + $1.galones } }
    var ingresoTotal: Decimal { totales.reduce(0) { $0 + $1.ingreso } }

    var tendencia: [PuntoTendencia] {
        let filas = datos?.filas ?? []
        return dias.flatMap { dia in
            Combustible.allCases.map { c in
                PuntoTendencia(dia: dia, combustible: c,
                               galones: filas.filter { $0.fechaOperativa == dia && $0.combustible == c }.reduce(0) { $0 + $1.galonesVendidos })
            }
        }
    }

    var ranking: [FilaRanking] {
        sucursalesActivasEnFiltro.map { s in
            let filas = (datos?.filas ?? []).filter { $0.sucursalId == s.id }
            return FilaRanking(sucursal: s, galones: filas.reduce(0) { $0 + $1.galonesVendidos }, ingreso: filas.reduce(0) { $0 + $1.ingresoUsd })
        }
        .sorted { ($0.galones, $1.sucursal.nombre) > ($1.galones, $0.sucursal.nombre) }
    }

    var tanquesCriticos: [EstadoTanque] {
        (datos?.tanques ?? []).filter { $0.estado == .critico }.sorted { $0.porcentaje < $1.porcentaje }
    }

    func nombreSucursal(_ id: UUID) -> String { datos?.sucursales.first { $0.id == id }?.nombre ?? "Sucursal" }

    var sucursalesSinCorteHoy: [Sucursal] {
        let conCorte = Set((datos?.cortesHoy ?? []).map(\.sucursalId))
        return sucursalesActivasEnFiltro.filter { !conCorte.contains($0.id) }
    }

    /// «Datos de N de M cortes»: cortes cerrados del periodo frente a los 2 diarios de cada sucursal activa.
    var cortesCerrados: Int { datos?.cortes.count ?? 0 }
    var cortesEsperados: Int { 2 * dias.count * sucursalesActivasEnFiltro.count }
    var sinCortesCerrados: Bool { cortesCerrados == 0 }

    var textoSinCortes: String { periodo == .hoy ? "Sin cortes cerrados hoy" : "Sin cortes cerrados en este periodo" }

    // MARK: Tienda y servicios (bloque aparte)

    var ingresoTienda: Decimal { (datos?.ingresosTienda ?? []).reduce(0) { $0 + $1.ingresoUsd } }

    var ingresoTiendaPorCategoria: [(categoria: CategoriaArticulo, unidades: Int, ingreso: Decimal)] {
        let filas = datos?.ingresosTienda ?? []
        return CategoriaArticulo.allCases.compactMap { c in
            let f = filas.filter { $0.categoria == c }
            guard !f.isEmpty else { return nil }
            return (c, f.reduce(0) { $0 + $1.unidades }, f.reduce(0) { $0 + $1.ingresoUsd })
        }
    }

    var ventasAnuladas: Int { (datos?.anulaciones ?? []).reduce(0) { $0 + $1.ventasAnuladas } }
    var totalAnulado: Decimal { (datos?.anulaciones ?? []).reduce(0) { $0 + $1.totalUsd } }
    var cajasConDiferencia: Int { (datos?.cajas ?? []).filter { ($0.diferenciaUsd ?? 0) != 0 }.count }
    var cajasForzadas: Int { (datos?.cajas ?? []).filter(\.cierreForzado).count }
    var hayActividadTienda: Bool { !(datos?.ingresosTienda.isEmpty ?? true) || !(datos?.cajas.isEmpty ?? true) || !(datos?.stockBajo.isEmpty ?? true) || ventasAnuladas > 0 }

    // MARK: Detalle de combustible (11)

    func detalle(de combustible: Combustible) -> [FilaSucursalCombustible] {
        sucursalesActivasEnFiltro.map { s in
            let filas = (datos?.filas ?? []).filter { $0.sucursalId == s.id && $0.combustible == combustible }
            return FilaSucursalCombustible(
                sucursal: s, galones: filas.reduce(0) { $0 + $1.galonesVendidos },
                compras: filas.reduce(0) { $0 + $1.comprasGal }, perdidas: filas.reduce(0) { $0 + $1.perdidasGal },
                tanque: (datos?.tanques ?? []).first { $0.sucursalId == s.id && $0.combustible == combustible })
        }
        .sorted { ($0.galones, $1.sucursal.nombre) > ($1.galones, $0.sucursal.nombre) }
    }
}
