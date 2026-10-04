import Foundation

struct Corte: Codable, Hashable, Identifiable {
    let id: UUID
    let sucursalId: UUID
    let secuencia: Int
    let estado: EstadoCorte
    let abiertoEn: Date
    let cerradoEn: Date?
    let cerradoPor: UUID?
    let tipo: TipoCorte?
    /// "yyyy-MM-dd"; solo existe cuando el corte está cerrado.
    let fechaOperativa: String?

    var estaCerrado: Bool { estado == .cerrado }
}

/// Fila de `lecturas_manguera`: el borrador de una manguera dentro del corte en curso.
struct LecturaManguera: Codable, Hashable, Identifiable {
    let id: UUID
    let corteId: UUID
    let mangueraId: UUID
    let lecturaInicialManualGal: Decimal?
    let lecturaFinalGal: Decimal
}

/// Fila de `v_lecturas_efectivas`: lectura inicial (derivada), final (con ajustes) y galones de una manguera.
struct LecturaEfectiva: Codable, Hashable, Identifiable {
    let corteId: UUID
    let sucursalId: UUID
    let mangueraId: UUID
    let bombaId: UUID
    let bombaNumero: Int
    let combustible: Combustible
    let lecturaInicialGal: Decimal?
    let finalOriginal: Decimal
    let lecturaFinalGal: Decimal
    let ajustada: Bool
    let cambioMedidor: Bool
    @DecimalOCero var galones: Decimal

    var id: UUID { mangueraId }
}

struct CambioMedidor: Codable, Hashable, Identifiable {
    let id: UUID
    let corteId: UUID
    let mangueraId: UUID
    let lecturaFinalViejoGal: Decimal
    let lecturaInicialNuevoGal: Decimal
    let nota: String
    let registradoPor: UUID?
    let creadoEn: Date
}

struct CompraCombustible: Codable, Hashable, Identifiable {
    let id: UUID
    let corteId: UUID
    let tanqueId: UUID
    let galones: Decimal
    let proveedor: String?
    let origen: OrigenLinea
    let vaciadoId: UUID?
    let creadoEn: Date
}

struct PerdidaCombustible: Codable, Hashable, Identifiable {
    let id: UUID
    let corteId: UUID
    let sucursalId: UUID
    let tanqueId: UUID
    let tipo: TipoPerdida
    let galones: Decimal
    let bombaId: UUID?
    let nota: String
    let origen: OrigenLinea
    let vaciadoId: UUID?
    let creadoEn: Date
}

struct VaciadoTanque: Codable, Hashable, Identifiable {
    let id: UUID
    let corteId: UUID
    let sucursalId: UUID
    let tanqueId: UUID
    let motivo: MotivoVaciado
    let combustibleErroneo: Combustible?
    let galonesErroneos: Decimal?
    let nivelMedidoGal: Decimal
    let nota: String
    let creadoEn: Date
}

struct AjusteLectura: Codable, Hashable, Identifiable {
    let id: UUID
    let corteId: UUID
    let mangueraId: UUID
    let valorCorrectoGal: Decimal
    let motivo: String
    let ajustadoPor: UUID?
    let creadoEn: Date
}

struct PrecioCorte: Codable, Hashable {
    let corteId: UUID
    let combustible: Combustible
    let precioGal: Decimal
}

// MARK: - Vistas

/// `v_estado_tanque`: nivel estimado, porcentaje, autonomía y estado de cada tanque.
struct EstadoTanque: Codable, Hashable, Identifiable {
    let tanqueId: UUID
    let sucursalId: UUID
    let combustible: Combustible
    let capacidadGal: Decimal
    @DecimalOCero var nivelEstimadoGal: Decimal
    @DecimalOCero var porcentaje: Decimal
    let nCompras: Int
    let nPerdidas: Int
    /// Momento del último corte cerrado en que se basa la estimación (nil si aún no hay cortes).
    let baseEn: Date?
    let autonomiaDias: Decimal?
    let autonomiaDisponible: Bool
    let estado: NivelAlerta

    var id: UUID { tanqueId }
}

/// `v_cuadre_tanque_corte`
struct CuadreTanque: Codable, Hashable, Identifiable {
    let corteId: UUID
    let sucursalId: UUID
    let tanqueId: UUID
    let combustible: Combustible
    @DecimalOCero var nivelInicialGal: Decimal
    @DecimalOCero var comprasGal: Decimal
    @DecimalOCero var galonesMedidor: Decimal
    @DecimalOCero var perdidasGal: Decimal
    @DecimalOCero var nivelMedidoGal: Decimal
    @DecimalOCero var nivelTeoricoGal: Decimal
    @DecimalOCero var diferenciaGal: Decimal
    let hayDiferencia: Bool

    var id: UUID { tanqueId }
}

/// `v_resumen_corte`: consolidado por combustible de un corte.
struct ResumenCorte: Codable, Hashable, Identifiable {
    let corteId: UUID
    let sucursalId: UUID
    let combustible: Combustible
    let tanqueId: UUID
    @DecimalOCero var galonesVendidos: Decimal
    @DecimalOCero var ingresoUsd: Decimal
    @DecimalOCero var comprasGal: Decimal
    @DecimalOCero var perdidasGal: Decimal
    @DecimalOCero var nivelInicialGal: Decimal
    @DecimalOCero var nivelTeoricoGal: Decimal
    @DecimalOCero var nivelMedidoGal: Decimal
    @DecimalOCero var diferenciaGal: Decimal
    let hayDiferencia: Bool
    let hayAjuste: Bool
    let hayCambioMedidor: Bool

    var id: String { "\(corteId.uuidString)-\(combustible.rawValue)" }
}

/// `v_dashboard_combustible`: métricas por sucursal, día operativo y combustible (solo cortes cerrados).
struct DashboardCombustible: Codable, Hashable, Identifiable {
    let sucursalId: UUID
    let fechaOperativa: String
    let combustible: Combustible
    @DecimalOCero var galonesVendidos: Decimal
    @DecimalOCero var ingresoUsd: Decimal
    @DecimalOCero var comprasGal: Decimal
    @DecimalOCero var perdidasGal: Decimal
    let cortesCerrados: Int
    let cortesConDiferencia: Int

    var id: String { "\(sucursalId.uuidString)-\(fechaOperativa)-\(combustible.rawValue)" }
}

/// Resultado de `cerrar_corte`.
struct ResultadoCierreCorte: Codable, Hashable {
    let corteId: UUID
    let tipo: TipoCorte
    let fechaOperativa: String
    let siguienteCorteId: UUID
}

/// Nivel medido de un tanque, tal como se envía a `cerrar_corte`.
struct NivelMedido: Codable, Hashable {
    let tanqueId: UUID
    let nivelMedidoGal: Decimal
}

// MARK: - Captura y reportes del corte

/// Una manguera de la bomba, tal como se envía a `guardar_lecturas_bomba`.
struct LecturaCaptura: Codable, Hashable {
    let combustible: Combustible
    let lecturaFinalGal: Decimal
    /// Solo en el primer corte de la sucursal.
    let lecturaInicialGal: Decimal?
}

/// Bombas y mangueras de una sucursal.
struct Infraestructura: Equatable {
    var bombas: [Bomba]
    var mangueras: [Manguera]

    func mangueras(de bomba: Bomba) -> [Manguera] {
        mangueras.filter { $0.bombaId == bomba.id }.sorted { $0.combustible.orden < $1.combustible.orden }
    }
}

/// Fila de `resumen_previo_corte`: el resumen del corte en curso antes de cerrarlo (lo calcula el servidor).
struct ResumenPrevio: Codable, Hashable, Identifiable {
    let combustible: Combustible
    let tanqueId: UUID
    @DecimalOCero var galonesVendidos: Decimal
    let precioGal: Decimal?
    let ingresoUsd: Decimal?
    @DecimalOCero var comprasGal: Decimal
    @DecimalOCero var perdidasGal: Decimal
    let nivelInicialGal: Decimal?
    @DecimalOCero var nivelTeoricoGal: Decimal
    let nivelMedidoGal: Decimal?
    let diferenciaGal: Decimal?
    let hayDiferencia: Bool?
    let hayCambioMedidor: Bool

    var id: UUID { tanqueId }
}

/// Todo lo que muestra el reporte de un corte cerrado.
struct ReporteCorte: Equatable {
    var corte: Corte
    var sucursalNombre: String
    var cerradoPorNombre: String?
    var lecturas: [LecturaEfectiva]
    var resumen: [ResumenCorte]
    var compras: [CompraCombustible]
    var perdidas: [PerdidaCombustible]
    var cambiosMedidor: [CambioMedidor]
    var ajustes: [AjusteLectura]
    var precios: [PrecioCorte]
    /// `true` si el corte siguiente ya se cerró: el corte es definitivo y no admite ajustes.
    var siguienteCerrado: Bool

    var hayAjuste: Bool { resumen.contains { $0.hayAjuste } }
    var hayCambioMedidor: Bool { resumen.contains { $0.hayCambioMedidor } }
    var hayDiferencia: Bool { resumen.contains { $0.hayDiferencia } }
}

extension Infraestructura {
    /// Bombas cuyas 3 mangueras ya tienen lectura guardada (borrador) en el corte.
    func bombasGuardadas(borrador: [LecturaManguera]) -> Set<UUID> {
        let conLectura = Set(borrador.map(\.mangueraId))
        return Set(bombas.filter { b in
            let ms = mangueras(de: b)
            return ms.count == 3 && ms.allSatisfy { conLectura.contains($0.id) }
        }.map(\.id))
    }
}
