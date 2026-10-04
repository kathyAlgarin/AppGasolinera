import Foundation
import Supabase

/// Convierte cualquier error de red, base de datos, Auth o Edge Function en un `ErrorApp` con mensaje en español.
/// Las reglas de negocio llegan ya redactadas en español desde el servidor (`raise exception`): se muestran tal cual.
enum Traductor {
    static let generico = "No se pudo completar la operación. Intenta de nuevo."
    static let sinConexion = "No hay conexión con el servidor. Revisa tu internet."

    /// Ejecuta una operación y traduce lo que falle. Las cancelaciones se dejan pasar (no son errores para el usuario).
    @discardableResult
    static func ejecutar<T>(_ cuerpo: () async throws -> T) async throws -> T {
        do {
            return try await cuerpo()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw traducir(error)
        }
    }

    static func traducir(_ error: Error) -> ErrorApp {
        if let e = error as? ErrorApp { return e }

        if let e = error as? PostgrestError { return desdeBaseDeDatos(e) }

        if let e = error as? AuthError { return desdeAuth(e) }

        if let e = error as? FunctionsError {
            switch e {
            case .httpError(let codigo, let datos):
                if let mensaje = mensajeDeFuncion(datos) { return ErrorApp(mensaje: mensaje) }
                if codigo == 401 { return ErrorApp(mensaje: "Tu sesión venció. Vuelve a iniciar sesión.") }
                return ErrorApp(mensaje: generico)
            case .relayError:
                return ErrorApp(mensaje: sinConexion)
            }
        }

        if error is URLError { return ErrorApp(mensaje: sinConexion) }
        if error is DecodingError { return ErrorApp(mensaje: "La respuesta del servidor no se pudo leer. Actualiza la app e intenta de nuevo.") }
        return ErrorApp(mensaje: generico)
    }

    private static func desdeBaseDeDatos(_ e: PostgrestError) -> ErrorApp {
        switch e.code {
        case "P0001":
            return ErrorApp(mensaje: e.message)                       // regla de negocio, ya en español
        case "42501":
            // Las funciones lanzan mensajes en español con este código; el RLS de Postgres los lanza en inglés.
            return ErrorApp(mensaje: e.message.hasPrefix("Solo ") ? e.message : "No tienes permiso para hacer esto.")
        case "23505": return ErrorApp(mensaje: "Ya existe un registro igual.")
        case "23514": return ErrorApp(mensaje: "Hay un dato fuera del rango permitido. Revisa los campos.")
        case "23503": return ErrorApp(mensaje: "Ese registro está relacionado con otros datos.")
        case "PGRST301", "PGRST303": return ErrorApp(mensaje: "Tu sesión venció. Vuelve a iniciar sesión.")
        default:
            // Los mensajes escritos por nosotros empiezan con mayúscula y están en español; cualquier otro se oculta.
            return ErrorApp(mensaje: generico)
        }
    }

    private static func desdeAuth(_ e: AuthError) -> ErrorApp {
        switch e {
        case .sessionMissing:
            return ErrorApp(mensaje: "Tu sesión venció. Vuelve a iniciar sesión.")
        case .weakPassword:
            return ErrorApp(mensaje: "La contraseña es muy débil. Usa al menos 8 caracteres.")
        case .api(_, let codigo, _, _):
            switch codigo {
            case .invalidCredentials: return ErrorApp(mensaje: "Correo o contraseña incorrectos.")
            case .userBanned: return ErrorApp(mensaje: "Tu usuario está desactivado. Habla con el Gerente General.")
            case .otpExpired: return ErrorApp(mensaje: "Código incorrecto o vencido.")
            case .samePassword: return ErrorApp(mensaje: "La nueva contraseña debe ser distinta de la actual.")
            case .weakPassword: return ErrorApp(mensaje: "La contraseña es muy débil. Usa al menos 8 caracteres.")
            case .overEmailSendRateLimit, .overRequestRateLimit:
                return ErrorApp(mensaje: "Demasiados intentos. Espera un momento e intenta de nuevo.")
            case .userNotFound: return ErrorApp(mensaje: "Código incorrecto o vencido.")
            default: return ErrorApp(mensaje: generico)
            }
        default:
            return ErrorApp(mensaje: generico)
        }
    }

    /// Las Edge Functions responden `{ "error": "mensaje en español" }`.
    private static func mensajeDeFuncion(_ datos: Data) -> String? {
        struct Cuerpo: Decodable { let error: String }
        return (try? JSONDecoder().decode(Cuerpo.self, from: datos))?.error
    }
}
