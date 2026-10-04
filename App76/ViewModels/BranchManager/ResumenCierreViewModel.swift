import Foundation

/// 41–43 · Resumen del corte con el cuadre (calculado por el servidor) y cierre.
@MainActor
final class ResumenCierreViewModel: ObservableObject {
    struct Datos: Equatable {
        var filas: [ResumenPrevio]
        var cajasAbiertas: Int
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published var tipoInicial: TipoCorte = .matutino
    @Published private(set) var error: String?
    @Published private(set) var cerrando = false
    @Published private(set) var resultado: ResultadoCierreCorte?

    let corte: Corte
    let niveles: [NivelMedido]
    let tieneTienda: Bool
    private let servicio: CorteService
    private let tienda: TiendaService
    private let alCerrar: () -> Void

    init(corte: Corte, niveles: [NivelMedido], tieneTienda: Bool, servicio: CorteService, tienda: TiendaService,
         alCerrar: @escaping () -> Void) {
        self.corte = corte
        self.niveles = niveles
        self.tieneTienda = tieneTienda
        self.servicio = servicio
        self.tienda = tienda
        self.alCerrar = alCerrar
    }

    var esPrimerCorte: Bool { corte.secuencia == 1 }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            async let filas = servicio.resumenPrevio(corteId: corte.id, niveles: niveles)
            async let cajas: Int = tieneTienda ? tienda.cajasAbiertas(sucursalId: corte.sucursalId) : 0
            let (f, c) = try await (filas, cajas)
            estado = .listo(Datos(filas: f.sorted { $0.combustible.orden < $1.combustible.orden }, cajasAbiertas: c))
        } catch {
            estado.registrarFallo(error)
        }
    }

    var filas: [ResumenPrevio] { estado.valor?.filas ?? [] }

    /// Combustibles de los que la sucursal no tiene precio vigente: bloquean el cierre.
    var combustiblesSinPrecio: [Combustible] { filas.filter { $0.precioGal == nil }.map(\.combustible) }
    var cajasAbiertas: Int { estado.valor?.cajasAbiertas ?? 0 }
    var hayDiferencias: Bool { filas.contains { $0.hayDiferencia == true } }

    /// Totales consolidados para mostrar (suma de las filas por combustible).
    var galonesTotales: Decimal { filas.reduce(0) { $0 + $1.galonesVendidos } }
    var ingresoTotal: Decimal { filas.reduce(0) { $0 + ($1.ingresoUsd ?? 0) } }

    /// Motivo por el que no se puede cerrar todavía (nil si se puede intentar).
    var motivoBloqueo: String? {
        if !combustiblesSinPrecio.isEmpty {
            return "La sucursal no tiene precio de \(combustiblesSinPrecio.map(\.nombre).joined(separator: ", ")). Pídele al Gerente General que lo fije."
        }
        if cajasAbiertas > 0 {
            return "Hay \(cajasAbiertas) \(cajasAbiertas == 1 ? "caja abierta" : "cajas abiertas"): cierra las cajas antes de cerrar el corte."
        }
        return nil
    }

    var puedeCerrar: Bool { estado.valor != nil && motivoBloqueo == nil && !cerrando && resultado == nil }

    func limpiarError() { error = nil }

    func cerrar() async {
        guard puedeCerrar else { return }
        cerrando = true
        error = nil
        defer { cerrando = false }
        do {
            resultado = try await servicio.cerrar(corteId: corte.id, niveles: niveles, tipoInicial: esPrimerCorte ? tipoInicial : nil)
            alCerrar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
