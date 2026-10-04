import Foundation
import Supabase

struct SupabaseCorteService: CorteService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func corteEnCurso(sucursalId: UUID) async throws -> Corte {
        let cortes: [Corte] = try await Traductor.ejecutar {
            try await cliente.from("cortes").select()
                .eq("sucursal_id", value: sucursalId).eq("estado", value: "en_curso").limit(1)
                .execute().value
        }
        guard let corte = cortes.first else { throw ErrorApp(mensaje: "Esta sucursal no tiene un corte en curso.") }
        return corte
    }

    func infraestructura(sucursalId: UUID) async throws -> Infraestructura {
        try await Traductor.ejecutar {
            async let b: [Bomba] = cliente.from("bombas").select().eq("sucursal_id", value: sucursalId).order("numero").execute().value
            async let m: [Manguera] = cliente.from("mangueras").select().eq("sucursal_id", value: sucursalId).execute().value
            return try await Infraestructura(bombas: b, mangueras: m)
        }
    }

    func borradorLecturas(corteId: UUID) async throws -> [LecturaManguera] {
        try await Traductor.ejecutar {
            try await cliente.from("lecturas_manguera").select().eq("corte_id", value: corteId).execute().value
        }
    }

    func inicialesDerivadas(corte: Corte) async throws -> [UUID: Decimal] {
        guard corte.secuencia > 1 else { return [:] }
        return try await Traductor.ejecutar {
            let previos: [Corte] = try await cliente.from("cortes").select()
                .eq("sucursal_id", value: corte.sucursalId).eq("secuencia", value: corte.secuencia - 1).limit(1)
                .execute().value
            guard let previo = previos.first else { return [:] }
            let lecturas: [LecturaEfectiva] = try await cliente.from("v_lecturas_efectivas").select()
                .eq("corte_id", value: previo.id).execute().value
            return Dictionary(uniqueKeysWithValues: lecturas.map { ($0.mangueraId, $0.lecturaFinalGal) })
        }
    }

    private struct GuardarParams: Encodable {
        let pCorte: UUID
        let pBomba: UUID
        let pLecturas: [LecturaCaptura]
    }

    func guardarLecturas(corteId: UUID, bombaId: UUID, lecturas: [LecturaCaptura]) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("guardar_lecturas_bomba",
                                  params: GuardarParams(pCorte: corteId, pBomba: bombaId, pLecturas: lecturas)).execute()
        }
    }

    func cambiosMedidor(corteId: UUID) async throws -> [CambioMedidor] {
        try await Traductor.ejecutar {
            try await cliente.from("cambios_medidor").select().eq("corte_id", value: corteId).execute().value
        }
    }

    private struct CambioParams: Encodable {
        let pCorte: UUID
        let pManguera: UUID
        let pFinalViejo: Decimal
        let pInicialNuevo: Decimal
        let pNota: String
    }

    func registrarCambioMedidor(corteId: UUID, mangueraId: UUID, finalViejo: Decimal, inicialNuevo: Decimal, nota: String) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("registrar_cambio_medidor", params: CambioParams(
                pCorte: corteId, pManguera: mangueraId, pFinalViejo: finalViejo, pInicialNuevo: inicialNuevo, pNota: nota)).execute()
        }
    }

    private struct EliminarCambioParams: Encodable {
        let pCorte: UUID
        let pManguera: UUID
    }

    func eliminarCambioMedidor(corteId: UUID, mangueraId: UUID) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("eliminar_cambio_medidor", params: EliminarCambioParams(pCorte: corteId, pManguera: mangueraId)).execute()
        }
    }

    private struct PrevioParams: Encodable {
        let pCorte: UUID
        let pNiveles: [NivelMedido]
    }

    func resumenPrevio(corteId: UUID, niveles: [NivelMedido]) async throws -> [ResumenPrevio] {
        try await Traductor.ejecutar {
            try await cliente.rpc("resumen_previo_corte", params: PrevioParams(pCorte: corteId, pNiveles: niveles)).execute().value
        }
    }

    private struct CerrarParams: Encodable {
        let pCorte: UUID
        let pNiveles: [NivelMedido]
        let pTipoInicial: TipoCorte?
    }

    func cerrar(corteId: UUID, niveles: [NivelMedido], tipoInicial: TipoCorte?) async throws -> ResultadoCierreCorte {
        try await Traductor.ejecutar {
            try await cliente.rpc("cerrar_corte", params: CerrarParams(pCorte: corteId, pNiveles: niveles, pTipoInicial: tipoInicial))
                .execute().value
        }
    }
}
