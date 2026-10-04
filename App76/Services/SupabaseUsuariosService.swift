import Foundation
import Supabase

struct SupabaseUsuariosService: UsuariosService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func listar() async throws -> [Perfil] {
        try await Traductor.ejecutar {
            try await cliente.from("perfiles").select().order("nombre").execute().value
        }
    }

    /// Cuerpo de la Edge Function `gestionar-usuarios` (ver docs/BASE_DE_DATOS.md).
    private struct Cuerpo: Encodable {
        let accion: String
        var correo: String?
        var nombre: String?
        var rol: RolUsuario?
        var sucursalId: UUID?
        var passwordTemporal: String?
        var usuarioId: UUID?
        var activo: Bool?
    }

    private struct Respuesta: Decodable { let id: UUID? }

    private func llamar(_ cuerpo: Cuerpo) async throws -> Respuesta {
        try await Traductor.ejecutar {
            try await cliente.functions.invoke(
                "gestionar-usuarios",
                options: FunctionInvokeOptions(body: cuerpo, encoder: JSONSupabase.codificador),
                decoder: JSONSupabase.decodificador
            )
        }
    }

    func crear(correo: String, nombre: String, rol: RolUsuario, sucursalId: UUID?, passwordTemporal: String) async throws -> UUID {
        let r = try await llamar(Cuerpo(accion: "crear", correo: correo, nombre: nombre, rol: rol,
                                        sucursalId: sucursalId, passwordTemporal: passwordTemporal))
        guard let id = r.id else { throw ErrorApp(mensaje: Traductor.generico) }
        return id
    }

    func restablecerPassword(usuarioId: UUID, passwordTemporal: String) async throws {
        _ = try await llamar(Cuerpo(accion: "restablecer_password", passwordTemporal: passwordTemporal, usuarioId: usuarioId))
    }

    func cambiarCorreo(usuarioId: UUID, correo: String) async throws {
        _ = try await llamar(Cuerpo(accion: "cambiar_correo", correo: correo, usuarioId: usuarioId))
    }

    func cambiarEstado(usuarioId: UUID, activo: Bool) async throws {
        _ = try await llamar(Cuerpo(accion: "cambiar_estado", usuarioId: usuarioId, activo: activo))
    }
}
