import Foundation

/// 12 · Detalle de sucursal (solo consulta para el Gerente General).
@MainActor
final class DetalleSucursalViewModel: ObservableObject {
    struct Datos: Equatable {
        var gerente: Perfil?
        var tanques: [EstadoTanque]
        var cortes: [Corte]
        var perdidas: [PerdidaCombustible]
        var preciosVigentes: [Combustible: Precio]
        var infraestructura: [Tanque]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial

    let sucursal: Sucursal
    private let usuarios: UsuariosService
    private let tanquesServicio: TanquesService
    private let reportes: ReportesService
    private let precios: PreciosService
    private let sucursales: SucursalesService
    private let ahora: () -> Date

    init(sucursal: Sucursal, usuarios: UsuariosService, tanques: TanquesService, reportes: ReportesService,
         precios: PreciosService, sucursales: SucursalesService, ahora: @escaping () -> Date = { Date() }) {
        self.sucursal = sucursal
        self.usuarios = usuarios
        self.tanquesServicio = tanques
        self.reportes = reportes
        self.precios = precios
        self.sucursales = sucursales
        self.ahora = ahora
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        let id = sucursal.id
        do {
            async let u = usuarios.listar()
            async let t = tanquesServicio.estado(sucursalId: id)
            async let c = reportes.historial(sucursalId: id, limite: 8)
            async let p = reportes.perdidas(sucursalId: id, tipo: nil, desde: nil, hasta: nil, limite: 15)
            async let pr = precios.historial()
            async let ta = sucursales.tanques()
            let (usuarios, tanques, cortes, perdidas, historial, infra) = try await (u, t, c, p, pr, ta)
            let ahora = self.ahora()
            var vigentes: [Combustible: Precio] = [:]
            for fila in historial where fila.sucursalId == id && fila.vigenteDesde <= ahora {
                if let actual = vigentes[fila.combustible], actual.vigenteDesde >= fila.vigenteDesde { continue }
                vigentes[fila.combustible] = fila
            }
            estado = .listo(Datos(
                gerente: usuarios.first { $0.sucursalId == id && $0.rol == .gerenteSucursal && $0.activo },
                tanques: tanques.sorted { $0.combustible.orden < $1.combustible.orden },
                cortes: cortes, perdidas: perdidas, preciosVigentes: vigentes,
                infraestructura: infra.filter { $0.sucursalId == id }))
        } catch {
            estado.registrarFallo(error)
        }
    }

    func combustible(de p: PerdidaCombustible) -> Combustible? {
        estado.valor?.infraestructura.first { $0.id == p.tanqueId }?.combustible
    }
}
