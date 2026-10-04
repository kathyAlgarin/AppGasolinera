import Foundation
import Supabase

/// Cliente único de Supabase para toda la app. Solo los servicios lo usan; las vistas y los ViewModels nunca.
enum ClienteSupabase {
    static let compartido = SupabaseClient(
        supabaseURL: Configuracion.urlSupabase,
        supabaseKey: Configuracion.clavePublishable,
        options: SupabaseClientOptions(
            db: .init(encoder: JSONSupabase.codificador, decoder: JSONSupabase.decodificador),
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}
