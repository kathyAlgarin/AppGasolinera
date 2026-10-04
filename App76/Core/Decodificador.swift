import Foundation

/// Cómo se leen y escriben los JSON del servidor (PostgREST): `snake_case`, fechas con zona y decimales exactos.
enum JSONSupabase {
    static let decodificador: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let texto = try decoder.singleValueContainer().decode(String.self)
            if let fecha = Fechas.parsearTimestamp(texto) { return fecha }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Fecha no válida: \(texto)"))
        }
        return d
    }()

    static let codificador: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

/// Columna numérica que puede venir `null` en una vista (p. ej. sin cortes cerrados): se lee como 0.
@propertyWrapper
struct DecimalOCero: Codable, Hashable {
    var wrappedValue: Decimal

    init(wrappedValue: Decimal) { self.wrappedValue = wrappedValue }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        wrappedValue = c.decodeNil() ? 0 : try c.decode(Decimal.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    /// Si la columna falta del todo, también vale 0.
    func decode(_ type: DecimalOCero.Type, forKey key: Key) throws -> DecimalOCero {
        try decodeIfPresent(type, forKey: key) ?? DecimalOCero(wrappedValue: 0)
    }
}
