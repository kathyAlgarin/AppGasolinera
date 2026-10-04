import SwiftUI

struct GeneralManagerTabView: View {
    let perfil: Perfil
    @ObservedObject var sesion: SesionViewModel

    var body: some View {
        TabView {
            NavigationStack { PanelView() }
                .tabItem { Label("Panel", systemImage: "chart.bar.xaxis") }
            NavigationStack { SucursalesView() }
                .tabItem { Label("Sucursales", systemImage: "building.2") }
            NavigationStack { PreciosView() }
                .tabItem { Label("Precios", systemImage: "dollarsign.circle") }
            NavigationStack { UsuariosView(perfil: perfil) }
                .tabItem { Label("Usuarios", systemImage: "person.2") }
            NavigationStack { MasGerenteGeneralView(perfil: perfil, sesion: sesion) }
                .tabItem { Label("Más", systemImage: "ellipsis.circle") }
        }
        .tint(.gas76Orange)
    }
}

/// Pestaña «Más» del Gerente General.
struct MasGerenteGeneralView: View {
    let perfil: Perfil
    @ObservedObject var sesion: SesionViewModel

    var body: some View {
        List {
            NavigationLink { CatalogoView() } label: { Label("Catálogo", systemImage: "shippingbox") }
            NavigationLink { PerdidasGlobalesView() } label: { Label("Pérdidas y contaminaciones", systemImage: "exclamationmark.triangle") }
            NavigationLink { TiendaYCajasView() } label: { Label("Tienda y cajas", systemImage: "bag") }
            NavigationLink { PersonalConsultaView() } label: { Label("Personal", systemImage: "person.3") }
            NavigationLink { PerfilView(perfil: perfil, sesion: sesion) } label: { Label("Perfil", systemImage: "person.crop.circle") }
        }
        .navigationTitle("Más")
    }
}
