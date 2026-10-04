import Foundation
import Supabase

struct SupabaseTanquesService: TanquesService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func estado(sucursalId: UUID?) async throws -> [EstadoTanque] {
        try await Traductor.ejecutar {
            var consulta = cliente.from("v_estado_tanque").select()
            if let sucursalId { consulta = consulta.eq("sucursal_id", value: sucursalId) }
            return try await consulta.execute().value
        }
    }
}
