import Foundation

protocol ConexionService {
    /// Lanza `ErrorApp` si no se puede llegar al backend.
    func verificar() async throws
}

/// Pregunta al servicio de Auth de Supabase si está vivo (`/auth/v1/health`); no requiere sesión.
struct ConexionSupabaseService: ConexionService {
    func verificar() async throws {
        var peticion = URLRequest(url: Configuracion.urlSupabase.appendingPathComponent("auth/v1/health"))
        peticion.setValue(Configuracion.clavePublishable, forHTTPHeaderField: "apikey")
        peticion.timeoutInterval = 15
        do {
            let (_, respuesta) = try await URLSession.shared.data(for: peticion)
            guard let http = respuesta as? HTTPURLResponse, http.statusCode == 200 else {
                throw ErrorApp(mensaje: "El servidor respondió con un error. Intenta de nuevo.")
            }
        } catch let error as ErrorApp {
            throw error
        } catch {
            throw ErrorApp(mensaje: "No hay conexión con el servidor. Revisa tu internet.")
        }
    }
}
