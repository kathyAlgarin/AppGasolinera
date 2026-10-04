import Foundation

/// 39 · Descarga errónea y vaciado de tanque. No existe un «vaciar» sin motivo.
@MainActor
final class VaciadoViewModel: ObservableObject {
    @Published var motivo: MotivoVaciado = .descargaErronea
    @Published var tanqueId: UUID {
        didSet {
            if combustibleErroneo == tanqueActual?.combustible { combustibleErroneo = opcionesErroneo.first }
        }
    }
    @Published var combustibleErroneo: Combustible?
    @Published var galonesErroneos = ""
    @Published var nivelMedido = ""
    @Published var nota = ""
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let tanques: [EstadoTanque]
    private let corteId: UUID
    private let servicio: LineasCorteService
    private let alGuardar: () -> Void

    init(corteId: UUID, tanques: [EstadoTanque], tanqueInicial: UUID? = nil, servicio: LineasCorteService, alGuardar: @escaping () -> Void) {
        self.corteId = corteId
        self.tanques = tanques.sorted { $0.combustible.orden < $1.combustible.orden }
        self.servicio = servicio
        self.alGuardar = alGuardar
        tanqueId = tanqueInicial ?? self.tanques.first?.tanqueId ?? UUID()
        combustibleErroneo = opcionesErroneo.first
    }

    var tanqueActual: EstadoTanque? { tanques.first { $0.tanqueId == tanqueId } }

    /// El combustible que traía la cisterna debe ser distinto al del tanque.
    var opcionesErroneo: [Combustible] {
        Combustible.allCases.filter { $0 != tanqueActual?.combustible }
    }

    var esDescargaErronea: Bool { motivo == .descargaErronea }

    var errorNivel: String? {
        guard let v = Validadores.decimal(nivelMedido) else { return "Escribe el nivel medido con la varilla (puede ser 0)." }
        if let t = tanqueActual, v > t.capacidadGal { return "No puede superar la capacidad (\(Formateadores.galones(t.capacidadGal)))." }
        return nil
    }

    var errorGalonesErroneos: String? {
        guard esDescargaErronea else { return nil }
        guard let g = Validadores.decimal(galonesErroneos), g > 0 else { return "Los galones descargados por error deben ser mayores que 0." }
        if let n = Validadores.decimal(nivelMedido), g > n { return "No pueden superar el nivel medido." }
        return nil
    }

    var errorNota: String? {
        Validadores.textoLimpio(nota).count >= 3 ? nil : "La nota es obligatoria (mínimo 3 caracteres)."
    }

    var esValido: Bool {
        errorNivel == nil && errorGalonesErroneos == nil && errorNota == nil && (!esDescargaErronea || combustibleErroneo != nil)
    }

    /// Vista previa de lo que se registrará. Es solo un adelanto: el servidor calcula y registra las líneas reales.
    var vistaPrevia: [String] {
        guard let t = tanqueActual, let nivel = Validadores.decimal(nivelMedido) else { return [] }
        var lineas: [String] = []
        if esDescargaErronea {
            guard let g = Validadores.decimal(galonesErroneos), g > 0, g <= nivel, let erroneo = combustibleErroneo else { return [] }
            lineas.append("Pérdida de \(Formateadores.galones(nivel - g)) de \(t.combustible.nombre) (contaminación)")
            lineas.append("Compra y pérdida de \(Formateadores.galones(g)) de \(erroneo.nombre) (contaminación)")
        } else {
            lineas.append("Pérdida de \(Formateadores.galones(nivel)) de \(t.combustible.nombre) (contaminación)")
        }
        lineas.append("El tanque de \(t.combustible.nombre) quedará en 0")
        return lineas
    }

    func limpiarError() { error = nil }

    func registrar() async {
        guard esValido, let nivel = Validadores.decimal(nivelMedido) else {
            error = "Revisa los campos marcados."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.registrarVaciado(
                corteId: corteId, tanqueId: tanqueId, motivo: motivo, nivelMedido: nivel,
                combustibleErroneo: esDescargaErronea ? combustibleErroneo : nil,
                galonesErroneos: esDescargaErronea ? Validadores.decimal(galonesErroneos) : nil,
                nota: Validadores.textoLimpio(nota))
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
