import Foundation

protocol AuthService {
    /// El perfil del usuario con sesión guardada, o `nil` si no hay sesión.
    func perfilActual() async throws -> Perfil?
    func iniciarSesion(correo: String, password: String) async throws
    func cerrarSesion() async
    /// Envía el código de 6 dígitos al correo (plantilla «Reset password» con `{{ .Token }}`).
    func enviarCodigo(correo: String) async throws
    /// Verifica el código; deja una sesión abierta para poder definir la nueva contraseña.
    func verificarCodigo(correo: String, codigo: String) async throws
    func cambiarPassword(_ nueva: String) async throws
    func marcarPasswordCambiada() async throws
}
