import Foundation

/// Mini marco de pruebas para correr fuera de Xcode (macOS, solo Foundation): `tools/correr_pruebas.sh`.
enum Marco {
    nonisolated(unsafe) static var fallas = 0
    nonisolated(unsafe) static var total = 0
}

func verificar(_ condicion: @autoclosure () -> Bool, _ nombre: String, archivo: String = #fileID, linea: Int = #line) {
    Marco.total += 1
    if !condicion() {
        Marco.fallas += 1
        print("  ✗ FALLÓ: \(nombre)  (\(archivo):\(linea))")
    }
}

func igual<T: Equatable>(_ a: T, _ b: T, _ nombre: String, archivo: String = #fileID, linea: Int = #line) {
    Marco.total += 1
    if a != b {
        Marco.fallas += 1
        print("  ✗ FALLÓ: \(nombre): obtuve \(a), esperaba \(b)  (\(archivo):\(linea))")
    }
}

func grupo(_ nombre: String, _ cuerpo: () async throws -> Void) async {
    print("• \(nombre)")
    do { try await cuerpo() } catch {
        Marco.fallas += 1
        Marco.total += 1
        print("  ✗ EXCEPCIÓN en \(nombre): \(error)")
    }
}

func decodificar<T: Decodable>(_ tipo: T.Type, _ json: String) throws -> T {
    try JSONSupabase.decodificador.decode(T.self, from: Data(json.utf8))
}
