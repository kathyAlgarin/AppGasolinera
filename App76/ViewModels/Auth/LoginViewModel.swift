import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var correo = ""
    @Published var password = ""
    @Published private(set) var error: String?
    @Published private(set) var cargando = false

    private let auth: AuthService
    private let alEntrar: (Perfil) -> Void

    init(auth: AuthService, alEntrar: @escaping (Perfil) -> Void) {
        self.auth = auth
        self.alEntrar = alEntrar
    }

    var puedeIngresar: Bool { !correo.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !cargando }

    func limpiarError() { error = nil }

    func ingresar() async {
        guard puedeIngresar else { return }
        let correoLimpio = Validadores.correo(correo)
        guard Validadores.esCorreoValido(correoLimpio) else {
            error = "Escribe un correo válido."
            return
        }
        cargando = true
        error = nil
        defer { cargando = false }
        do {
            try await auth.iniciarSesion(correo: correoLimpio, password: password)
            guard let perfil = try await auth.perfilActual() else {
                error = "No se encontró tu perfil. Habla con el Gerente General."
                await auth.cerrarSesion()
                return
            }
            guard perfil.activo else {
                await auth.cerrarSesion()
                error = "Tu usuario está desactivado. Habla con el Gerente General."
                return
            }
            password = ""
            alEntrar(perfil)
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
