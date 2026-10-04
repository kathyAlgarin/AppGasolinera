import SwiftUI

struct BranchManagerTabView: View {
    let perfil: Perfil
    @ObservedObject var sesion: SesionViewModel
    @StateObject private var nav = NavegacionSucursal()
    @StateObject private var sucursal: SucursalDelGerenteViewModel

    init(perfil: Perfil, sesion: SesionViewModel) {
        self.perfil = perfil
        self.sesion = sesion
        _sucursal = StateObject(wrappedValue: SucursalDelGerenteViewModel(sucursalId: perfil.sucursalId ?? UUID(), servicio: Servicios.sucursales))
    }

    var body: some View {
        TabView(selection: $nav.pestana) {
            NavigationStack { InicioSucursalView(perfil: perfil, nav: nav) }
                .tabItem { Label("Inicio", systemImage: "house") }.tag(PestanaSucursal.inicio)
            CorteEnCursoView(perfil: perfil, nav: nav)
                .tabItem { Label("Corte", systemImage: "gauge.with.dots.needle.50percent") }.tag(PestanaSucursal.corte)
            if sucursal.tieneTienda {
                NavigationStack { InventarioSucursalView(perfil: perfil, corteId: nil) }
                    .tabItem { Label("Tienda", systemImage: "bag") }.tag(PestanaSucursal.tienda)
            }
            NavigationStack { PersonalView(sucursalId: perfil.sucursalId ?? UUID(), soloLectura: false) }
                .tabItem { Label("Personal", systemImage: "person.3") }.tag(PestanaSucursal.personal)
            NavigationStack { MasGerenteSucursalView(perfil: perfil, sesion: sesion, tieneTienda: sucursal.tieneTienda) }
                .tabItem { Label("Más", systemImage: "ellipsis.circle") }.tag(PestanaSucursal.mas)
        }
        .tint(.gas76Orange)
        .task { await sucursal.cargar() }
    }
}

/// Pestaña «Más» del Gerente de Sucursal: Historial, Cajeros (solo con tienda) y Perfil.
struct MasGerenteSucursalView: View {
    let perfil: Perfil
    @ObservedObject var sesion: SesionViewModel
    let tieneTienda: Bool

    var body: some View {
        List {
            NavigationLink { HistorialCortesView(sucursalId: perfil.sucursalId, esGerenteGeneral: false) } label: {
                Label("Historial de cortes", systemImage: "clock.arrow.circlepath")
            }
            if tieneTienda {
                NavigationLink { CajerosView(perfil: perfil) } label: { Label("Cajeros", systemImage: "person.badge.key") }
            }
            NavigationLink { PerfilView(perfil: perfil, sesion: sesion) } label: { Label("Perfil", systemImage: "person.crop.circle") }
        }
        .navigationTitle("Más")
    }
}
