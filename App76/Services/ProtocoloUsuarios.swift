import Foundation

protocol UsuariosService {
    /// Perfiles visibles (el Gerente General, todos; el de Sucursal, los de su sucursal).
    func listar() async throws -> [Perfil]
    func crear(correo: String, nombre: String, rol: RolUsuario, sucursalId: UUID?, passwordTemporal: String) async throws -> UUID
    func restablecerPassword(usuarioId: UUID, passwordTemporal: String) async throws
    func cambiarEstado(usuarioId: UUID, activo: Bool) async throws
    /// Cambia el correo de inicio de sesión y el del perfil (no sobre el propio usuario).
    func cambiarCorreo(usuarioId: UUID, correo: String) async throws
}
