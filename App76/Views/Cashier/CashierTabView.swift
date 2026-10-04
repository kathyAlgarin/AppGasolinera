import SwiftUI

struct CashierTabView: View {
    let perfil: Perfil
    @ObservedObject var sesion: SesionViewModel

    var body: some View {
        TabView {
            NavigationStack { CajaView() }
                .tabItem { Label("Caja", systemImage: "cart") }
            NavigationStack { MisVentasView() }
                .tabItem { Label("Ventas", systemImage: "receipt") }
            NavigationStack { PerfilView(perfil: perfil, sesion: sesion) }
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
        .tint(.gas76Orange)
    }
}
