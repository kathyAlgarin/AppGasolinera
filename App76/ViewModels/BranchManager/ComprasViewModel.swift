import Foundation

/// 35 · Compras (descargas de cisterna) del corte en curso.
@MainActor
final class ComprasViewModel: ObservableObject {
    @Published private(set) var estado: Carga<[CompraCombustible]> = .inicial
    @Published private(set) var error: String?

    let corteId: UUID
    let tanques: [EstadoTanque]
    private let servicio: LineasCorteService

    init(corteId: UUID, tanques: [EstadoTanque], servicio: LineasCorteService) {
        self.corteId = corteId
        self.tanques = tanques
        self.servicio = servicio
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            estado = .listo(try await servicio.compras(corteId: corteId))
        } catch {
            estado.registrarFallo(error)
        }
    }

    func combustible(de compra: CompraCombustible) -> Combustible? {
        tanques.first { $0.tanqueId == compra.tanqueId }?.combustible
    }

    /// Las compras generadas por un vaciado no se editan ni se eliminan.
    func esEditable(_ compra: CompraCombustible) -> Bool { compra.origen == .manual }

    func eliminar(_ compra: CompraCombustible) async {
        error = nil
        do {
            try await servicio.eliminarCompra(id: compra.id)
            await cargar()
        } catch {
            self.error = mensajeDe(error)
        }
    }

    func limpiarError() { error = nil }
}

/// 36 · Nueva compra o edición.
@MainActor
final class CompraFormViewModel: ObservableObject {
    @Published var tanqueId: UUID
    @Published var galones: String
    @Published var proveedor: String
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let tanques: [EstadoTanque]
    let compra: CompraCombustible?
    private let corteId: UUID
    private let servicio: LineasCorteService
    private let alGuardar: () -> Void

    var esEdicion: Bool { compra != nil }

    init(corteId: UUID, tanques: [EstadoTanque], compra: CompraCombustible?, servicio: LineasCorteService, alGuardar: @escaping () -> Void) {
        self.corteId = corteId
        self.tanques = tanques.sorted { $0.combustible.orden < $1.combustible.orden }
        self.compra = compra
        self.servicio = servicio
        self.alGuardar = alGuardar
        tanqueId = compra?.tanqueId ?? self.tanques.first?.tanqueId ?? UUID()
        galones = compra.map { Formateadores.paraCampo($0.galones) } ?? ""
        proveedor = compra?.proveedor ?? ""
    }

    var errorGalones: String? {
        guard let v = Validadores.decimal(galones), v > 0 else { return "Los galones deben ser mayores que 0." }
        return nil
    }
    var errorProveedor: String? {
        Validadores.textoLimpio(proveedor).count <= 80 ? nil : "El proveedor admite hasta 80 caracteres."
    }
    var esValido: Bool { errorGalones == nil && errorProveedor == nil }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido, let g = Validadores.decimal(galones) else {
            error = "Revisa los campos marcados."
            return
        }
        let prov = Validadores.textoLimpio(proveedor)
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            if let compra {
                try await servicio.editarCompra(id: compra.id, galones: g, proveedor: prov.isEmpty ? nil : prov)
            } else {
                try await servicio.registrarCompra(corteId: corteId, tanqueId: tanqueId, galones: g, proveedor: prov.isEmpty ? nil : prov)
            }
            alGuardar()
        } catch {
            self.error = mensajeDe(error)   // p. ej. «La compra excede el espacio libre del tanque (libre: N gal).»
        }
    }
}
