import Foundation

/// Datos de un usuario en solo lectura, restablecer contraseña y activar/desactivar.
@MainActor
final class EditarUsuarioViewModel: ObservableObject {
    @Published private(set) var usuario: Perfil
    @Published var passwordTemporal = ""
    @Published var correoNuevo: String
    @Published private(set) var error: String?
    @Published private(set) var aviso: String?
    @Published private(set) var trabajando = false

    private let servicio: UsuariosService
    private let alCambiar: () -> Void

    init(usuario: Perfil, servicio: UsuariosService, alCambiar: @escaping () -> Void) {
        self.usuario = usuario
        self.correoNuevo = usuario.correo
        self.servicio = servicio
        self.alCambiar = alCambiar
    }

    var errorPassword: String? {
        Validadores.passwordValida(passwordTemporal) ? nil : "La contraseña temporal debe tener entre 8 y 72 caracteres."
    }

    var errorCorreo: String? { Validadores.esCorreoValido(correoNuevo) ? nil : "Escribe un correo válido." }
    var hayCambioCorreo: Bool { Validadores.correo(correoNuevo) != usuario.correo }

    func cambiarCorreo() async {
        guard errorCorreo == nil, hayCambioCorreo else { return }
        let nuevo = Validadores.correo(correoNuevo)
        trabajando = true
        limpiarMensajes()
        defer { trabajando = false }
        do {
            try await servicio.cambiarCorreo(usuarioId: usuario.id, correo: nuevo)
            usuario.correo = nuevo
            correoNuevo = nuevo
            aviso = "Correo actualizado. \(usuario.nombre) debe iniciar sesión con \(nuevo)."
            alCambiar()
        } catch {
            self.error = mensajeDe(error)
        }
    }

    func limpiarMensajes() {
        error = nil
        aviso = nil
    }

    func restablecer() async {
        guard errorPassword == nil else {
            error = errorPassword
            return
        }
        trabajando = true
        limpiarMensajes()
        defer { trabajando = false }
        do {
            try await servicio.restablecerPassword(usuarioId: usuario.id, passwordTemporal: passwordTemporal)
            passwordTemporal = ""
            aviso = "Contraseña restablecida. \(usuario.nombre) deberá cambiarla al iniciar sesión."
        } catch {
            self.error = mensajeDe(error)
        }
    }

    func cambiarActivo(_ activo: Bool) async {
        trabajando = true
        limpiarMensajes()
        defer { trabajando = false }
        do {
            try await servicio.cambiarEstado(usuarioId: usuario.id, activo: activo)
            usuario.activo = activo
            alCambiar()
        } catch {
            self.error = mensajeDe(error)   // el servidor impide desactivar al último Gerente General o a uno mismo
        }
    }
}
