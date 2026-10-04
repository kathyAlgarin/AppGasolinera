import Foundation

/// 30 · Inicio del Gerente de Sucursal: tanques, corte en curso y lo vendido hoy en cortes cerrados.
@MainActor
final class InicioSucursalViewModel: ObservableObject {
    struct Datos: Equatable {
        var tanques: [EstadoTanque]
        var corte: Corte
        var bombasGuardadas: Int
        var compras: Int
        var perdidas: Int
        var hoy: [DashboardCombustible]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial

    let sucursalId: UUID
    private let tanquesServicio: TanquesService
    private let corteServicio: CorteService
    private let lineasServicio: LineasCorteService
    private let dashboard: DashboardService
    private let ahora: () -> Date

    init(sucursalId: UUID, tanques: TanquesService, corte: CorteService, lineas: LineasCorteService,
         dashboard: DashboardService, ahora: @escaping () -> Date = { Date() }) {
        self.sucursalId = sucursalId
        self.tanquesServicio = tanques
        self.corteServicio = corte
        self.lineasServicio = lineas
        self.dashboard = dashboard
        self.ahora = ahora
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            let dia = Fechas.hoy(ahora: ahora())
            async let t = tanquesServicio.estado(sucursalId: sucursalId)
            async let c = corteServicio.corteEnCurso(sucursalId: sucursalId)
            async let i = corteServicio.infraestructura(sucursalId: sucursalId)
            async let d = dashboard.combustible(desde: dia, hasta: dia, sucursalId: sucursalId)
            let (tanques, corte, infra, hoy) = try await (t, c, i, d)
            async let borrador = corteServicio.borradorLecturas(corteId: corte.id)
            async let compras = lineasServicio.compras(corteId: corte.id)
            async let perdidas = lineasServicio.perdidas(corteId: corte.id)
            let (b, co, pe) = try await (borrador, compras, perdidas)
            estado = .listo(Datos(
                tanques: tanques.sorted { $0.combustible.orden < $1.combustible.orden },
                corte: corte,
                bombasGuardadas: infra.bombasGuardadas(borrador: b).count,
                compras: co.count, perdidas: pe.count,
                hoy: hoy.sorted { $0.combustible.orden < $1.combustible.orden }))
        } catch {
            estado.registrarFallo(error)
        }
    }

    // MARK: Resumen de hoy (solo cortes cerrados)

    /// Suma de los combustibles del día para mostrar un total consolidado.
    var galonesHoy: Decimal { (estado.valor?.hoy ?? []).reduce(0) { $0 + $1.galonesVendidos } }
    var ingresoHoy: Decimal { (estado.valor?.hoy ?? []).reduce(0) { $0 + $1.ingresoUsd } }
    var cortesCerradosHoy: Int { (estado.valor?.hoy ?? []).map(\.cortesCerrados).max() ?? 0 }
    var sinCortesCerradosHoy: Bool { cortesCerradosHoy == 0 }
}
