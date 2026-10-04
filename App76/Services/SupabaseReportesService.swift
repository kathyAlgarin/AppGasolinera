import Foundation
import Supabase

struct SupabaseReportesService: ReportesService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func historial(sucursalId: UUID?, limite: Int) async throws -> [Corte] {
        try await Traductor.ejecutar {
            var consulta = cliente.from("cortes").select().eq("estado", value: "cerrado")
            if let sucursalId { consulta = consulta.eq("sucursal_id", value: sucursalId) }
            return try await consulta.order("cerrado_en", ascending: false).limit(limite).execute().value
        }
    }

    /// Se consulta por lotes: una lista muy larga de ids no cabe en la dirección de la petición.
    func resumenes(corteIds: [UUID]) async throws -> [ResumenCorte] {
        guard !corteIds.isEmpty else { return [] }
        let lotes = stride(from: 0, to: corteIds.count, by: 40).map { Array(corteIds[$0..<min($0 + 40, corteIds.count)]) }
        return try await Traductor.ejecutar {
            var todos: [ResumenCorte] = []
            for lote in lotes {
                let parte: [ResumenCorte] = try await cliente.from("v_resumen_corte").select().in("corte_id", values: lote).execute().value
                todos += parte
            }
            return todos
        }
    }

    func corte(id: UUID) async throws -> Corte {
        let cortes: [Corte] = try await Traductor.ejecutar {
            try await cliente.from("cortes").select().eq("id", value: id).limit(1).execute().value
        }
        guard let corte = cortes.first else { throw ErrorApp(mensaje: "No se encontró el corte.") }
        return corte
    }

    func reporte(corte: Corte) async throws -> ReporteCorte {
        try await Traductor.ejecutar {
            let id = corte.id
            async let lecturas: [LecturaEfectiva] = cliente.from("v_lecturas_efectivas").select().eq("corte_id", value: id)
                .order("bomba_numero").execute().value
            async let resumen: [ResumenCorte] = cliente.from("v_resumen_corte").select().eq("corte_id", value: id).execute().value
            async let compras: [CompraCombustible] = cliente.from("compras_combustible").select().eq("corte_id", value: id)
                .order("creado_en").execute().value
            async let perdidas: [PerdidaCombustible] = cliente.from("perdidas_combustible").select().eq("corte_id", value: id)
                .order("creado_en").execute().value
            async let cambios: [CambioMedidor] = cliente.from("cambios_medidor").select().eq("corte_id", value: id).execute().value
            async let ajustes: [AjusteLectura] = cliente.from("ajustes_lectura").select().eq("corte_id", value: id)
                .order("creado_en").execute().value
            async let precios: [PrecioCorte] = cliente.from("precios_corte").select().eq("corte_id", value: id).execute().value
            async let sucursales: [Sucursal] = cliente.from("sucursales").select().eq("id", value: corte.sucursalId).limit(1).execute().value
            async let siguiente: [Corte] = cliente.from("cortes").select()
                .eq("sucursal_id", value: corte.sucursalId).eq("secuencia", value: corte.secuencia + 1).limit(1).execute().value

            var nombreCierre: String?
            if let quien = corte.cerradoPor {
                let perfiles: [Perfil] = (try? await cliente.from("perfiles").select().eq("id", value: quien).limit(1).execute().value) ?? []
                nombreCierre = perfiles.first?.nombre
            }

            return try await ReporteCorte(
                corte: corte,
                sucursalNombre: sucursales.first?.nombre ?? "Sucursal",
                cerradoPorNombre: nombreCierre,
                lecturas: lecturas, resumen: resumen, compras: compras, perdidas: perdidas,
                cambiosMedidor: cambios, ajustes: ajustes, precios: precios,
                siguienteCerrado: siguiente.first?.estaCerrado ?? false)
        }
    }

    private struct AjusteParams: Encodable {
        let pCorte: UUID
        let pManguera: UUID
        let pValor: Decimal
        let pMotivo: String
    }

    func registrarAjuste(corteId: UUID, mangueraId: UUID, valor: Decimal, motivo: String) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("registrar_ajuste", params: AjusteParams(
                pCorte: corteId, pManguera: mangueraId, pValor: valor, pMotivo: motivo)).execute()
        }
    }

    func perdidas(sucursalId: UUID?, tipo: TipoPerdida?, desde: String?, hasta: String?, limite: Int) async throws -> [PerdidaCombustible] {
        try await Traductor.ejecutar {
            var q = cliente.from("perdidas_combustible").select()
            if let sucursalId { q = q.eq("sucursal_id", value: sucursalId) }
            if let tipo { q = q.eq("tipo", value: tipo.rawValue) }
            // Los días se interpretan en la zona de El Salvador (UTC−6): el día empieza a las 06:00 UTC.
            if let desde, let inicio = Fechas.fecha(deDia: desde) { q = q.gte("creado_en", value: Fechas.inicioDeDia(inicio)) }
            if let hasta, let fin = Fechas.fecha(deDia: hasta) {
                q = q.lt("creado_en", value: Fechas.inicioDeDia(fin).addingTimeInterval(86_400))
            }
            return try await q.order("creado_en", ascending: false).limit(limite).execute().value
        }
    }
}
