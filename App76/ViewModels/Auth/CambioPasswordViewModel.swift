import Foundation

/// Cambio de contraseña: obligatorio tras entrar con la temporal, o voluntario desde el perfil.
@MainActor
final class CambioPasswordViewModel: ObservableObject {
    @Published var nueva = ""
    @Published var confirmar = ""
    @Published private(set) var error: String?
    @Published private(set) var cargando = false

    let obligatorio: Bool
    private let auth: AuthService
    private let alTerminar: () -> Void

    init(auth: AuthService, obligatorio: Bool, alTerminar: @escaping () -> Void) {
        self.auth = auth
        self.obligatorio = obligatorio
        self.alTerminar = alTerminar
    }

    var puedeGuardar: Bool { Validadores.passwordValida(nueva) && nueva == confirmar && !cargando }

    func limpiarError() { error = nil }

    func guardar() async {
        guard Validadores.passwordValida(nueva) else {
            error = "La contraseña debe tener entre 8 y 72 caracteres."
            return
        }
        guard nueva == confirmar else {
            error = "Las contraseñas no coinciden."
            return
        }
        cargando = true
        error = nil
        defer { cargando = false }
        do {
            try await auth.cambiarPassword(nueva)
            if obligatorio { try await auth.marcarPasswordCambiada() }
            nueva = ""
            confirmar = ""
            alTerminar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
