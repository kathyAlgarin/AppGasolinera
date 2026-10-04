import Foundation
import Supabase

struct SupabaseAuthService: AuthService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func perfilActual() async throws -> Perfil? {
        let usuario: User
        do {
            usuario = try await cliente.auth.session.user
        } catch is AuthError {
            // Sin sesión, vencida o revocada (p. ej. usuario desactivado): se limpia la sesión local y se va al login.
            try? await cliente.auth.signOut(scope: .local)
            return nil
        } catch {
            throw Traductor.traducir(error)   // sin red: se muestra el error con «Reintentar»
        }
        return try await Traductor.ejecutar {
            let perfiles: [Perfil] = try await cliente.from("perfiles")
                .select()
                .eq("id", value: usuario.id)
                .limit(1)
                .execute().value
            return perfiles.first
        }
    }

    func iniciarSesion(correo: String, password: String) async throws {
        try await Traductor.ejecutar {
            try await cliente.auth.signIn(email: correo, password: password)
        }
    }

    func cerrarSesion() async {
        try? await cliente.auth.signOut()
    }

    func enviarCodigo(correo: String) async throws {
        try await Traductor.ejecutar {
            try await cliente.auth.resetPasswordForEmail(correo)
        }
    }

    func verificarCodigo(correo: String, codigo: String) async throws {
        try await Traductor.ejecutar {
            _ = try await cliente.auth.verifyOTP(email: correo, token: codigo, type: .recovery)
        }
    }

    func cambiarPassword(_ nueva: String) async throws {
        try await Traductor.ejecutar {
            _ = try await cliente.auth.update(user: UserAttributes(password: nueva))
        }
    }

    func marcarPasswordCambiada() async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("marcar_password_cambiada").execute()
        }
    }
}
