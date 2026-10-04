import Foundation

struct Perfil: Codable, Hashable, Identifiable {
    let id: UUID
    var correo: String
    var nombre: String
    var rol: RolUsuario
    var sucursalId: UUID?
    var activo: Bool
    var debeCambiarPassword: Bool
}

struct Sucursal: Codable, Hashable, Identifiable {
    let id: UUID
    var nombre: String
    var direccion: String
    var tieneTienda: Bool
    var activa: Bool
}

struct Tanque: Codable, Hashable, Identifiable {
    let id: UUID
    let sucursalId: UUID
    let combustible: Combustible
    let numero: Int
    var capacidadGal: Decimal
    var nivelInicialGal: Decimal
}

struct Bomba: Codable, Hashable, Identifiable {
    let id: UUID
    let sucursalId: UUID
    let numero: Int
}

struct Manguera: Codable, Hashable, Identifiable {
    let id: UUID
    let bombaId: UUID
    let sucursalId: UUID
    let combustible: Combustible
}

struct Precio: Codable, Hashable, Identifiable {
    let id: UUID
    let sucursalId: UUID
    let combustible: Combustible
    let precioGal: Decimal
    let vigenteDesde: Date
    let creadoPor: UUID?
}

/// Datos que el Gerente General captura por combustible al crear una sucursal.
struct TanqueNuevo: Codable, Hashable {
    let combustible: Combustible
    let capacidadGal: Decimal
    let nivelInicialGal: Decimal
}
