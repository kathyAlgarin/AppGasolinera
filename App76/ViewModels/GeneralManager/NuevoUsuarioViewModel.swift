import Foundation

/// Alta de usuarios. El Gerente General crea cualquier rol; el Gerente de Sucursal solo cajeros de su sucursal.
@MainActor
final class NuevoUsuarioViewModel: ObservableObject {
    @Published var nombre = ""
    @Published var correo = ""
    @Published var passwordTemporal = ""
    @Published var rol: RolUsuario {
        didSet { if !rolRequiereSucursal { sucursalId = nil } }
    }
    @Published var sucursalId: UUID?
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    /// Roles que quien crea puede elegir.
    let rolesPermitidos: [RolUsuario]
    /// Sucursales entre las que se puede elegir (para el Cajero, solo con tienda).
    private let sucursalesTodas: [Sucursal]
    /// Sucursal fija cuando quien crea es un Gerente de Sucursal.
    private let sucursalFija: UUID?
    private let servicio: UsuariosService
    private let alCrear: () -> Void

    init(creador: Perfil, sucursales: [Sucursal], servicio: UsuariosService, alCrear: @escaping () -> Void) {
        self.servicio = servicio
        self.alCrear = alCrear
        self.sucursalesTodas = sucursales
        if creador.rol == .gerenteGeneral {
            rolesPermitidos = [.gerenteGeneral, .gerenteSucursal, .cajero]
            sucursalFija = nil
            rol = .gerenteSucursal
        } else {
            rolesPermitidos = [.cajero]
            sucursalFija = creador.sucursalId
            rol = .cajero
            sucursalId = creador.sucursalId
        }
    }

    var rolRequiereSucursal: Bool { rol != .gerenteGeneral }

    var sucursalesElegibles: [Sucursal] {
        let activas = sucursalesTodas.filter { $0.activa }
        return rol == .cajero ? activas.filter { $0.tieneTienda } : activas
    }

    var esSucursalFija: Bool { sucursalFija != nil }

    var errorNombre: String? {
        (2...80).contains(Validadores.textoLimpio(nombre).count) ? nil : "El nombre debe tener entre 2 y 80 caracteres."
    }
    var errorCorreo: String? { Validadores.esCorreoValido(correo) ? nil : "Escribe un correo válido." }
    var errorPassword: String? {
        Validadores.passwordValida(passwordTemporal) ? nil : "La contraseña temporal debe tener entre 8 y 72 caracteres."
    }
    var errorSucursal: String? {
        rolRequiereSucursal && sucursalId == nil ? "Elige una sucursal." : nil
    }

    var esValido: Bool { errorNombre == nil && errorCorreo == nil && errorPassword == nil && errorSucursal == nil }
    var puedeGuardar: Bool { esValido && !guardando }

    func limpiarError() { error = nil }

    func crear() async {
        guard esValido else {
            error = "Revisa los campos marcados."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            _ = try await servicio.crear(correo: Validadores.correo(correo), nombre: Validadores.textoLimpio(nombre), rol: rol,
                                         sucursalId: rolRequiereSucursal ? (sucursalFija ?? sucursalId) : nil,
                                         passwordTemporal: passwordTemporal)
            alCrear()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
