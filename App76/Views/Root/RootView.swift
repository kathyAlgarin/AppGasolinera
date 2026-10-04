import SwiftUI

/// Enruta por sesión y rol: arranque → login → (cambio obligatorio de contraseña) → inicio del rol.
struct RootView: View {
    @StateObject private var sesion = SesionViewModel(auth: Servicios.auth)

    var body: some View {
        Group {
            if !Configuracion.estaConfigurada {
                avisoSinConfigurar
            } else {
                switch sesion.estado {
                case .iniciando:
                    pantallaCarga
                case .errorConexion(let mensaje):
                    pantallaError(mensaje)
                case .sinSesion:
                    LoginView(sesion: sesion)
                case .cambioObligatorio:
                    CambioObligatorioView(sesion: sesion)
                case .dentro(let perfil):
                    inicioDelRol(perfil)
                }
            }
        }
        .task { await sesion.iniciar() }
    }

    @ViewBuilder
    private func inicioDelRol(_ perfil: Perfil) -> some View {
        switch perfil.rol {
        case .gerenteGeneral:
            GeneralManagerTabView(perfil: perfil, sesion: sesion).id(perfil.id)
        case .gerenteSucursal:
            BranchManagerTabView(perfil: perfil, sesion: sesion).id(perfil.id)
        case .cajero:
            CashierTabView(perfil: perfil, sesion: sesion).id(perfil.id)
        }
    }

    private var pantallaCarga: some View {
        ZStack {
            Color.gas76Background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("Logo76").resizable().scaledToFit().frame(width: 96, height: 96)
                ProgressView()
            }
        }
    }

    private func pantallaError(_ mensaje: String) -> some View {
        ZStack {
            Color.gas76Background.ignoresSafeArea()
            VStack(spacing: 14) {
                Image("Logo76").resizable().scaledToFit().frame(width: 80, height: 80)
                Text(mensaje).multilineTextAlignment(.center).foregroundColor(.gas76Rojo)
                Button("Reintentar") { Task { await sesion.iniciar() } }
                    .buttonStyle(.borderedProminent).tint(.gas76Orange)
            }
            .padding(32)
        }
    }

    private var avisoSinConfigurar: some View {
        Text("Falta pegar la clave publishable en Core/Configuracion.swift.")
            .multilineTextAlignment(.center).foregroundColor(.gas76Rojo).padding(32)
    }
}
