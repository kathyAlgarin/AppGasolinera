import Foundation

/// Decide qué ve la app: arranque, login, cambio obligatorio de contraseña o el inicio del rol.
@MainActor
final class SesionViewModel: ObservableObject {
    enum Estado: Equatable {
        case iniciando
        case sinSesion
        case cambioObligatorio(Perfil)
        case dentro(Perfil)
        case errorConexion(String)
    }

    @Published private(set) var estado: Estado = .iniciando
    /// Aviso que se muestra una vez en el login (contraseña actualizada, usuario desactivado…).
    @Published var aviso: String?

    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    func iniciar() async {
        estado = .iniciando
        do {
            guard let perfil = try await auth.perfilActual() else {
                estado = .sinSesion
                return
            }
            await aplicar(perfil)
        } catch {
            guard let mensaje = mensajeDe(error) else { return }
            estado = .errorConexion(mensaje)
        }
    }

    /// Tras un login correcto.
    func entrar(_ perfil: Perfil) {
        aviso = nil
        estado = perfil.debeCambiarPassword ? .cambioObligatorio(perfil) : .dentro(perfil)
    }

    func cerrarSesion() async {
        await auth.cerrarSesion()
        estado = .sinSesion
    }

    /// El usuario terminó el cambio obligatorio: se vuelve a leer su perfil.
    func passwordCambiada() async {
        await iniciar()
    }

    /// Para la recuperación de contraseña: vuelve al login con un mensaje.
    func volverAlLogin(aviso: String?) {
        self.aviso = aviso
        estado = .sinSesion
    }

    private func aplicar(_ perfil: Perfil) async {
        if !perfil.activo {
            await auth.cerrarSesion()
            aviso = "Tu usuario está desactivado. Habla con el Gerente General."
            estado = .sinSesion
            return
        }
        estado = perfil.debeCambiarPassword ? .cambioObligatorio(perfil) : .dentro(perfil)
    }
}
