import Foundation

/// Servicios reales (Supabase) que usan las vistas para armar sus ViewModels.
/// Los ViewModels reciben protocolos, así que las pruebas pasan servicios falsos.
enum Servicios {
    static let auth: AuthService = SupabaseAuthService()
    static let sucursales: SucursalesService = SupabaseSucursalesService()
    static let precios: PreciosService = SupabasePreciosService()
    static let usuarios: UsuariosService = SupabaseUsuariosService()
    static let catalogo: CatalogoService = SupabaseCatalogoService()
    static let corte: CorteService = SupabaseCorteService()
    static let lineas: LineasCorteService = SupabaseLineasCorteService()
    static let tanques: TanquesService = SupabaseTanquesService()
    static let reportes: ReportesService = SupabaseReportesService()
    static let dashboard: DashboardService = SupabaseDashboardService()
    static let tienda: TiendaService = SupabaseTiendaService()
    static let caja: CajaService = SupabaseCajaService()
    static let personal: PersonalService = SupabasePersonalService()
    static let almacenNiveles: AlmacenNiveles = AlmacenNivelesLocal()
}
