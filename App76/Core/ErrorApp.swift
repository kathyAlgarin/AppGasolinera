import Foundation

/// Error con mensaje listo para mostrar al usuario (en español).
struct ErrorApp: LocalizedError {
    let mensaje: String
    var errorDescription: String? { mensaje }
}
