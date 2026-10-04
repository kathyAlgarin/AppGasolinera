import Foundation
import Supabase

struct SupabaseLineasCorteService: LineasCorteService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    // MARK: Compras

    func compras(corteId: UUID) async throws -> [CompraCombustible] {
        try await Traductor.ejecutar {
            try await cliente.from("compras_combustible").select().eq("corte_id", value: corteId)
                .order("creado_en", ascending: false).execute().value
        }
    }

    private struct CompraParams: Encodable {
        let pCorte: UUID
        let pTanque: UUID
        let pGalones: Decimal
        let pProveedor: String?
        // El proveedor opcional va como `null` explícito.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pCorte, forKey: .pCorte)
            try c.encode(pTanque, forKey: .pTanque)
            try c.encode(pGalones, forKey: .pGalones)
            try c.encode(pProveedor, forKey: .pProveedor)
        }
        enum CodingKeys: String, CodingKey { case pCorte = "p_corte", pTanque = "p_tanque", pGalones = "p_galones", pProveedor = "p_proveedor" }
    }

    func registrarCompra(corteId: UUID, tanqueId: UUID, galones: Decimal, proveedor: String?) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("registrar_compra",
                                  params: CompraParams(pCorte: corteId, pTanque: tanqueId, pGalones: galones, pProveedor: proveedor)).execute()
        }
    }

    private struct EditarCompraParams: Encodable {
        let pId: UUID
        let pGalones: Decimal
        let pProveedor: String?
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pId, forKey: .pId)
            try c.encode(pGalones, forKey: .pGalones)
            try c.encode(pProveedor, forKey: .pProveedor)
        }
        enum CodingKeys: String, CodingKey { case pId = "p_id", pGalones = "p_galones", pProveedor = "p_proveedor" }
    }

    func editarCompra(id: UUID, galones: Decimal, proveedor: String?) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("editar_compra", params: EditarCompraParams(pId: id, pGalones: galones, pProveedor: proveedor)).execute()
        }
    }

    private struct IdParams: Encodable { let pId: UUID }

    func eliminarCompra(id: UUID) async throws {
        try await Traductor.ejecutar { try await cliente.rpc("eliminar_compra", params: IdParams(pId: id)).execute() }
    }

    // MARK: Pérdidas

    func perdidas(corteId: UUID) async throws -> [PerdidaCombustible] {
        try await Traductor.ejecutar {
            try await cliente.from("perdidas_combustible").select().eq("corte_id", value: corteId)
                .order("creado_en", ascending: false).execute().value
        }
    }

    private struct PerdidaParams: Encodable {
        let pCorte: UUID
        let pTanque: UUID
        let pTipo: TipoPerdida
        let pGalones: Decimal
        let pBomba: UUID?
        let pNota: String
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pCorte, forKey: .pCorte)
            try c.encode(pTanque, forKey: .pTanque)
            try c.encode(pTipo, forKey: .pTipo)
            try c.encode(pGalones, forKey: .pGalones)
            try c.encode(pBomba, forKey: .pBomba)
            try c.encode(pNota, forKey: .pNota)
        }
        enum CodingKeys: String, CodingKey {
            case pCorte = "p_corte", pTanque = "p_tanque", pTipo = "p_tipo", pGalones = "p_galones", pBomba = "p_bomba", pNota = "p_nota"
        }
    }

    func registrarPerdida(corteId: UUID, tanqueId: UUID, tipo: TipoPerdida, galones: Decimal, bombaId: UUID?, nota: String) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("registrar_perdida", params: PerdidaParams(
                pCorte: corteId, pTanque: tanqueId, pTipo: tipo, pGalones: galones, pBomba: bombaId, pNota: nota)).execute()
        }
    }

    private struct EditarPerdidaParams: Encodable {
        let pId: UUID
        let pTipo: TipoPerdida
        let pGalones: Decimal
        let pBomba: UUID?
        let pNota: String
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pId, forKey: .pId)
            try c.encode(pTipo, forKey: .pTipo)
            try c.encode(pGalones, forKey: .pGalones)
            try c.encode(pBomba, forKey: .pBomba)
            try c.encode(pNota, forKey: .pNota)
        }
        enum CodingKeys: String, CodingKey { case pId = "p_id", pTipo = "p_tipo", pGalones = "p_galones", pBomba = "p_bomba", pNota = "p_nota" }
    }

    func editarPerdida(id: UUID, tipo: TipoPerdida, galones: Decimal, bombaId: UUID?, nota: String) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("editar_perdida", params: EditarPerdidaParams(
                pId: id, pTipo: tipo, pGalones: galones, pBomba: bombaId, pNota: nota)).execute()
        }
    }

    func eliminarPerdida(id: UUID) async throws {
        try await Traductor.ejecutar { try await cliente.rpc("eliminar_perdida", params: IdParams(pId: id)).execute() }
    }

    // MARK: Vaciados

    func vaciados(corteId: UUID) async throws -> [VaciadoTanque] {
        try await Traductor.ejecutar {
            try await cliente.from("vaciados_tanque").select().eq("corte_id", value: corteId)
                .order("creado_en", ascending: false).execute().value
        }
    }

    private struct VaciadoParams: Encodable {
        let pCorte: UUID
        let pTanque: UUID
        let pMotivo: MotivoVaciado
        let pNivelMedido: Decimal
        let pCombustibleErroneo: Combustible?
        let pGalonesErroneos: Decimal?
        let pNota: String
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pCorte, forKey: .pCorte)
            try c.encode(pTanque, forKey: .pTanque)
            try c.encode(pMotivo, forKey: .pMotivo)
            try c.encode(pNivelMedido, forKey: .pNivelMedido)
            try c.encode(pCombustibleErroneo, forKey: .pCombustibleErroneo)
            try c.encode(pGalonesErroneos, forKey: .pGalonesErroneos)
            try c.encode(pNota, forKey: .pNota)
        }
        enum CodingKeys: String, CodingKey {
            case pCorte = "p_corte", pTanque = "p_tanque", pMotivo = "p_motivo", pNivelMedido = "p_nivel_medido"
            case pCombustibleErroneo = "p_combustible_erroneo", pGalonesErroneos = "p_galones_erroneos", pNota = "p_nota"
        }
    }

    func registrarVaciado(corteId: UUID, tanqueId: UUID, motivo: MotivoVaciado, nivelMedido: Decimal,
                          combustibleErroneo: Combustible?, galonesErroneos: Decimal?, nota: String) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("registrar_vaciado", params: VaciadoParams(
                pCorte: corteId, pTanque: tanqueId, pMotivo: motivo, pNivelMedido: nivelMedido,
                pCombustibleErroneo: combustibleErroneo, pGalonesErroneos: galonesErroneos, pNota: nota)).execute()
        }
    }
}
