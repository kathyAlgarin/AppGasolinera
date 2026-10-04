import Foundation

/// 26 · Pérdidas y contaminaciones de todas las sucursales, filtrables por sucursal, tipo y fecha.
@MainActor
final class PerdidasGlobalesViewModel: ObservableObject {
    struct Datos: Equatable {
        var sucursales: [Sucursal]
        var tanques: [Tanque]
        var perdidas: [PerdidaCombustible]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published var sucursalId: UUID?
    @Published var tipo: TipoPerdida?
    @Published var usarFechas = false
    @Published var desde: Date
    @Published var hasta: Date

    private let reportes: ReportesService
    private let sucursalesServicio: SucursalesService

    init(reportes: ReportesService, sucursales: SucursalesService, ahora: Date = Date()) {
        self.reportes = reportes
        self.sucursalesServicio = sucursales
        desde = ahora.addingTimeInterval(-29 * 86_400)
        hasta = ahora
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            let d = usarFechas ? Fechas.diaISO(min(desde, hasta)) : nil
            let h = usarFechas ? Fechas.diaISO(max(desde, hasta)) : nil
            async let s = sucursalesServicio.listar()
            async let t = sucursalesServicio.tanques()
            async let p = reportes.perdidas(sucursalId: sucursalId, tipo: tipo, desde: d, hasta: h, limite: 200)
            let (suc, tan, per) = try await (s, t, p)
            estado = .listo(Datos(sucursales: suc.sorted { $0.nombre < $1.nombre }, tanques: tan, perdidas: per))
        } catch {
            estado.registrarFallo(error)
        }
    }

    func combustible(de p: PerdidaCombustible) -> Combustible? { estado.valor?.tanques.first { $0.id == p.tanqueId }?.combustible }
    func nombreSucursal(_ id: UUID) -> String { estado.valor?.sucursales.first { $0.id == id }?.nombre ?? "Sucursal" }
}
