import Foundation
import Supabase

struct SupabaseCatalogoService: CatalogoService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func listar() async throws -> [Articulo] {
        try await Traductor.ejecutar {
            try await cliente.from("articulos").select().order("nombre").execute().value
        }
    }

    private struct Nuevo: Encodable {
        let nombre: String
        let categoria: CategoriaArticulo
        let tipo: TipoArticulo
        let precioUsd: Decimal
        let activo: Bool
    }

    func crear(nombre: String, categoria: CategoriaArticulo, tipo: TipoArticulo, precioUsd: Decimal, activo: Bool) async throws {
        try await Traductor.ejecutar {
            try await cliente.from("articulos")
                .insert(Nuevo(nombre: nombre, categoria: categoria, tipo: tipo, precioUsd: precioUsd, activo: activo),
                        returning: .minimal)
                .execute()
        }
    }

    private struct Cambios: Encodable {
        let nombre: String
        let precioUsd: Decimal
        let activo: Bool
    }

    func editar(id: UUID, nombre: String, precioUsd: Decimal, activo: Bool) async throws {
        try await Traductor.ejecutar {
            try await cliente.from("articulos")
                .update(Cambios(nombre: nombre, precioUsd: precioUsd, activo: activo), returning: .minimal)
                .eq("id", value: id)
                .execute()
        }
    }
}
