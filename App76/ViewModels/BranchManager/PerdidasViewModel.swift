import Foundation

/// 37 · Pérdidas del corte en curso.
@MainActor
final class PerdidasViewModel: ObservableObject {
    @Published private(set) var estado: Carga<[PerdidaCombustible]> = .inicial
    @Published private(set) var error: String?

    let corteId: UUID
    let tanques: [EstadoTanque]
    let bombas: [Bomba]
    private let servicio: LineasCorteService

    init(corteId: UUID, tanques: [EstadoTanque], bombas: [Bomba], servicio: LineasCorteService) {
        self.corteId = corteId
        self.tanques = tanques
        self.bombas = bombas.sorted { $0.numero < $1.numero }
        self.servicio = servicio
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            estado = .listo(try await servicio.perdidas(corteId: corteId))
        } catch {
            estado.registrarFallo(error)
        }
    }

    func combustible(de p: PerdidaCombustible) -> Combustible? { tanques.first { $0.tanqueId == p.tanqueId }?.combustible }
    func numeroBomba(de p: PerdidaCombustible) -> Int? { bombas.first { $0.id == p.bombaId }?.numero }

    /// Las generadas por un vaciado (origen vaciado) están bloqueadas.
    func esEditable(_ p: PerdidaCombustible) -> Bool { p.origen == .manual }

    func eliminar(_ p: PerdidaCombustible) async {
        error = nil
        do {
            try await servicio.eliminarPerdida(id: p.id)
            await cargar()
        } catch {
            self.error = mensajeDe(error)
        }
    }

    func limpiarError() { error = nil }
}

/// 38 · Nueva pérdida o edición. La bomba es opcional (una fuga ocurre en el tanque; un derrame, en una bomba).
@MainActor
final class PerdidaFormViewModel: ObservableObject {
    @Published var tipo: TipoPerdida
    @Published var tanqueId: UUID
    @Published var galones: String
    @Published var bombaId: UUID?
    @Published var nota: String
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let tanques: [EstadoTanque]
    let bombas: [Bomba]
    let perdida: PerdidaCombustible?
    private let corteId: UUID
    private let servicio: LineasCorteService
    private let alGuardar: () -> Void

    var esEdicion: Bool { perdida != nil }

    init(corteId: UUID, tanques: [EstadoTanque], bombas: [Bomba], perdida: PerdidaCombustible?,
         servicio: LineasCorteService, alGuardar: @escaping () -> Void) {
        self.corteId = corteId
        self.tanques = tanques.sorted { $0.combustible.orden < $1.combustible.orden }
        self.bombas = bombas.sorted { $0.numero < $1.numero }
        self.perdida = perdida
        self.servicio = servicio
        self.alGuardar = alGuardar
        tipo = perdida?.tipo ?? .merma
        tanqueId = perdida?.tanqueId ?? self.tanques.first?.tanqueId ?? UUID()
        galones = perdida.map { Formateadores.paraCampo($0.galones) } ?? ""
        bombaId = perdida?.bombaId
        nota = perdida?.nota ?? ""
    }

    var errorGalones: String? {
        guard let v = Validadores.decimal(galones), v > 0 else { return "Los galones deben ser mayores que 0." }
        return nil
    }
    var errorNota: String? {
        Validadores.textoLimpio(nota).count >= 3 ? nil : "La nota es obligatoria (mínimo 3 caracteres)."
    }
    var esValido: Bool { errorGalones == nil && errorNota == nil }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido, let g = Validadores.decimal(galones) else {
            error = "Revisa los campos marcados."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            if let perdida {
                try await servicio.editarPerdida(id: perdida.id, tipo: tipo, galones: g, bombaId: bombaId, nota: Validadores.textoLimpio(nota))
            } else {
                try await servicio.registrarPerdida(corteId: corteId, tanqueId: tanqueId, tipo: tipo, galones: g,
                                                    bombaId: bombaId, nota: Validadores.textoLimpio(nota))
            }
            alGuardar()
        } catch {
            self.error = mensajeDe(error)   // p. ej. «La pérdida supera el nivel estimado del tanque (N gal).»
        }
    }
}
