import Foundation

/// El corte en curso de una sucursal: lecturas por bomba, cambios de medidor, vista previa y cierre.
protocol CorteService {
    func corteEnCurso(sucursalId: UUID) async throws -> Corte
    func infraestructura(sucursalId: UUID) async throws -> Infraestructura
    /// Lecturas ya guardadas (borrador por bomba) del corte.
    func borradorLecturas(corteId: UUID) async throws -> [LecturaManguera]
    /// Lectura inicial de cada manguera derivada de la final efectiva del corte anterior (vacío en el primer corte).
    func inicialesDerivadas(corte: Corte) async throws -> [UUID: Decimal]
    func guardarLecturas(corteId: UUID, bombaId: UUID, lecturas: [LecturaCaptura]) async throws
    func cambiosMedidor(corteId: UUID) async throws -> [CambioMedidor]
    func registrarCambioMedidor(corteId: UUID, mangueraId: UUID, finalViejo: Decimal, inicialNuevo: Decimal, nota: String) async throws
    func eliminarCambioMedidor(corteId: UUID, mangueraId: UUID) async throws
    func resumenPrevio(corteId: UUID, niveles: [NivelMedido]) async throws -> [ResumenPrevio]
    func cerrar(corteId: UUID, niveles: [NivelMedido], tipoInicial: TipoCorte?) async throws -> ResultadoCierreCorte
}

/// Compras, pérdidas y vaciados del corte en curso.
protocol LineasCorteService {
    func compras(corteId: UUID) async throws -> [CompraCombustible]
    func registrarCompra(corteId: UUID, tanqueId: UUID, galones: Decimal, proveedor: String?) async throws
    func editarCompra(id: UUID, galones: Decimal, proveedor: String?) async throws
    func eliminarCompra(id: UUID) async throws

    func perdidas(corteId: UUID) async throws -> [PerdidaCombustible]
    func registrarPerdida(corteId: UUID, tanqueId: UUID, tipo: TipoPerdida, galones: Decimal, bombaId: UUID?, nota: String) async throws
    func editarPerdida(id: UUID, tipo: TipoPerdida, galones: Decimal, bombaId: UUID?, nota: String) async throws
    func eliminarPerdida(id: UUID) async throws

    func vaciados(corteId: UUID) async throws -> [VaciadoTanque]
    func registrarVaciado(corteId: UUID, tanqueId: UUID, motivo: MotivoVaciado, nivelMedido: Decimal,
                          combustibleErroneo: Combustible?, galonesErroneos: Decimal?, nota: String) async throws
}

protocol TanquesService {
    /// Nivel estimado, porcentaje, autonomía y estado (`v_estado_tanque`).
    func estado(sucursalId: UUID?) async throws -> [EstadoTanque]
}

/// Historial, reporte de un corte y ajustes.
protocol ReportesService {
    func historial(sucursalId: UUID?, limite: Int) async throws -> [Corte]
    func resumenes(corteIds: [UUID]) async throws -> [ResumenCorte]
    func corte(id: UUID) async throws -> Corte
    func reporte(corte: Corte) async throws -> ReporteCorte
    func registrarAjuste(corteId: UUID, mangueraId: UUID, valor: Decimal, motivo: String) async throws
    /// Pérdidas de cualquier corte, más recientes primero. `desde`/`hasta` son días "yyyy-MM-dd" (zona de El Salvador).
    func perdidas(sucursalId: UUID?, tipo: TipoPerdida?, desde: String?, hasta: String?, limite: Int) async throws -> [PerdidaCombustible]
}
