import Foundation

/// 34 · El medidor (totalizador) de una manguera se cambió físicamente durante el corte.
@MainActor
final class CambioMedidorViewModel: ObservableObject {
    @Published var mangueraId: UUID
    @Published var finalViejo = ""
    @Published var inicialNuevo = "0"
    @Published var nota = ""
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let mangueras: [Manguera]
    let corte: Corte
    let iniciales: [UUID: Decimal]
    let borrador: [LecturaManguera]
    private let existentes: [CambioMedidor]
    private let servicio: CorteService
    private let alGuardar: () -> Void

    init(corte: Corte, mangueras: [Manguera], mangueraInicial: UUID? = nil, borrador: [LecturaManguera], iniciales: [UUID: Decimal],
         existentes: [CambioMedidor], servicio: CorteService, alGuardar: @escaping () -> Void) {
        self.corte = corte
        self.mangueras = mangueras.sorted { $0.combustible.orden < $1.combustible.orden }
        self.borrador = borrador
        self.iniciales = iniciales
        self.existentes = existentes
        self.servicio = servicio
        self.alGuardar = alGuardar
        let elegida = mangueraInicial ?? self.mangueras.first!.id
        mangueraId = elegida
        precargar(elegida)
    }

    /// Cambio ya registrado para la manguera elegida.
    var existente: CambioMedidor? { existentes.first { $0.mangueraId == mangueraId } }

    func precargar(_ id: UUID) {
        if let c = existentes.first(where: { $0.mangueraId == id }) {
            finalViejo = Formateadores.paraCampo(c.lecturaFinalViejoGal)
            inicialNuevo = Formateadores.paraCampo(c.lecturaInicialNuevoGal)
            nota = c.nota
        } else {
            finalViejo = ""
            inicialNuevo = "0"
            nota = ""
        }
    }

    /// Lectura inicial de la manguera en este corte (para comparar con la final del medidor viejo).
    var inicialDeLaManguera: Decimal? {
        corte.secuencia == 1
            ? borrador.first { $0.mangueraId == mangueraId }?.lecturaInicialManualGal
            : iniciales[mangueraId]
    }

    var errorFinalViejo: String? {
        guard !finalViejo.isEmpty else { return "Escribe la lectura final del medidor viejo." }
        guard let f = Validadores.decimal(finalViejo) else { return "Escribe un número válido." }
        if let i = inicialDeLaManguera, f < i {
            return "No puede ser menor que la inicial (\(Formateadores.numeroDosDecimales(i)))."
        }
        return nil
    }

    var errorInicialNuevo: String? {
        guard !inicialNuevo.isEmpty, Validadores.decimal(inicialNuevo) != nil else { return "Escribe la lectura inicial del medidor nuevo (normalmente 0)." }
        return nil
    }

    var errorNota: String? {
        Validadores.textoLimpio(nota).count >= 3 ? nil : "La nota es obligatoria (mínimo 3 caracteres)."
    }

    var esValido: Bool { errorFinalViejo == nil && errorInicialNuevo == nil && errorNota == nil }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido, let f = Validadores.decimal(finalViejo), let n = Validadores.decimal(inicialNuevo) else {
            error = "Revisa los campos marcados."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.registrarCambioMedidor(corteId: corte.id, mangueraId: mangueraId, finalViejo: f,
                                                      inicialNuevo: n, nota: Validadores.textoLimpio(nota))
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }

    func eliminar() async {
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.eliminarCambioMedidor(corteId: corte.id, mangueraId: mangueraId)
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
