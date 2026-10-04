import Foundation
import Supabase

struct SupabaseSucursalesService: SucursalesService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func listar() async throws -> [Sucursal] {
        try await Traductor.ejecutar {
            try await cliente.from("sucursales").select().order("nombre").execute().value
        }
    }

    func tanques() async throws -> [Tanque] {
        try await Traductor.ejecutar {
            try await cliente.from("tanques").select().order("numero").execute().value
        }
    }

    private struct CrearParams: Encodable {
        let pNombre: String
        let pDireccion: String
        let pTieneTienda: Bool
        let pTanques: [TanqueNuevo]
    }

    func crear(nombre: String, direccion: String, tieneTienda: Bool, tanques: [TanqueNuevo]) async throws -> UUID {
        try await Traductor.ejecutar {
            try await cliente.rpc("crear_sucursal", params: CrearParams(
                pNombre: nombre, pDireccion: direccion, pTieneTienda: tieneTienda, pTanques: tanques
            )).execute().value
        }
    }

    private struct EditarParams: Encodable {
        let pId: UUID
        let pNombre: String
        let pDireccion: String
    }

    func editar(id: UUID, nombre: String, direccion: String) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("editar_sucursal", params: EditarParams(pId: id, pNombre: nombre, pDireccion: direccion)).execute()
        }
    }

    private struct EstadoParams: Encodable {
        let pId: UUID
        let pActiva: Bool
    }

    func cambiarEstado(id: UUID, activa: Bool) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("cambiar_estado_sucursal", params: EstadoParams(pId: id, pActiva: activa)).execute()
        }
    }

    private struct TiendaParams: Encodable {
        let pId: UUID
        let pTieneTienda: Bool
    }

    func configurarTienda(id: UUID, tieneTienda: Bool) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("configurar_tienda", params: TiendaParams(pId: id, pTieneTienda: tieneTienda)).execute()
        }
    }
}
