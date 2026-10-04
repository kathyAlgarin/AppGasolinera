import Foundation
import Supabase

struct SupabasePreciosService: PreciosService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func historial() async throws -> [Precio] {
        try await Traductor.ejecutar {
            try await cliente.from("precios").select().order("vigente_desde", ascending: false).execute().value
        }
    }

    private struct FijarParams: Encodable {
        let pSucursales: [UUID]
        let pCombustible: Combustible
        let pPrecio: Decimal
    }

    func fijar(sucursales: [UUID], combustible: Combustible, precio: Decimal) async throws -> Int {
        try await Traductor.ejecutar {
            try await cliente.rpc("fijar_precio", params: FijarParams(
                pSucursales: sucursales, pCombustible: combustible, pPrecio: precio
            )).execute().value
        }
    }
}
