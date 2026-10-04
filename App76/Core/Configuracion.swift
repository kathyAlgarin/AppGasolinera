import Foundation

/// Datos públicos del proyecto Supabase `app_gasolinera`.
/// Solo va la clave **publishable** (pública por diseño). Nunca la `sb_secret_` ni contraseñas.
enum Configuracion {
    static let urlSupabase = URL(string: "https://kpzdedcztufqwsqoywdp.supabase.co")!

    /// Pegar aquí la clave que empieza con `sb_publishable_` (Supabase → Settings → API Keys).
    static let clavePublishable = "sb_publishable_z-xfFUDUgSb3uKYCGR96ng_xPQ5LCtY"

    static var estaConfigurada: Bool {
        clavePublishable.hasPrefix("sb_publishable_")
    }
}
