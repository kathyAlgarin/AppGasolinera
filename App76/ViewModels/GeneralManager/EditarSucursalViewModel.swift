import Foundation

@MainActor
final class EditarSucursalViewModel: ObservableObject {
    @Published var nombre: String
    @Published var direccion: String
    @Published var activa: Bool
    @Published var tieneTienda: Bool
    @Published private(set) var tanques: Carga<[Tanque]> = .inicial
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let sucursal: Sucursal
    private let servicio: SucursalesService
    private let alGuardar: () -> Void

    init(sucursal: Sucursal, servicio: SucursalesService, alGuardar: @escaping () -> Void) {
        self.sucursal = sucursal
        self.servicio = servicio
        self.alGuardar = alGuardar
        nombre = sucursal.nombre
        direccion = sucursal.direccion
        activa = sucursal.activa
        tieneTienda = sucursal.tieneTienda
    }

    var errorNombre: String? {
        (2...80).contains(Validadores.textoLimpio(nombre).count) ? nil : "El nombre debe tener entre 2 y 80 caracteres."
    }
    var errorDireccion: String? {
        (3...200).contains(Validadores.textoLimpio(direccion).count) ? nil : "La dirección debe tener entre 3 y 200 caracteres."
    }
    var esValido: Bool { errorNombre == nil && errorDireccion == nil }
    var hayCambios: Bool {
        Validadores.textoLimpio(nombre) != sucursal.nombre || Validadores.textoLimpio(direccion) != sucursal.direccion
            || activa != sucursal.activa || tieneTienda != sucursal.tieneTienda
    }

    func limpiarError() { error = nil }

    func cargarTanques() async {
        tanques = .cargando
        do {
            tanques = .listo(try await servicio.tanques().filter { $0.sucursalId == sucursal.id }
                .sorted { $0.combustible.orden < $1.combustible.orden })
        } catch {
            tanques.registrarFallo(error)
        }
    }

    func guardar() async {
        guard esValido else { return }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            let n = Validadores.textoLimpio(nombre), d = Validadores.textoLimpio(direccion)
            if n != sucursal.nombre || d != sucursal.direccion {
                try await servicio.editar(id: sucursal.id, nombre: n, direccion: d)
            }
            if tieneTienda != sucursal.tieneTienda {
                try await servicio.configurarTienda(id: sucursal.id, tieneTienda: tieneTienda)
            }
            if activa != sucursal.activa {
                try await servicio.cambiarEstado(id: sucursal.id, activa: activa)
            }
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
