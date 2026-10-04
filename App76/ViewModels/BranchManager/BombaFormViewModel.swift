import Foundation

/// 33 · Lecturas de una bomba (3 mangueras). En el primer corte también se teclea la inicial.
@MainActor
final class BombaFormViewModel: ObservableObject {
    struct Linea: Identifiable, Equatable {
        let manguera: Manguera
        var inicial: String
        var final: String
        var id: UUID { manguera.id }
    }

    @Published var lineas: [Linea]
    @Published private(set) var error: String?
    @Published private(set) var guardando = false
    @Published private(set) var cambios: [CambioMedidor]

    let bomba: Bomba
    let corte: Corte
    let iniciales: [UUID: Decimal]
    private let servicio: CorteService
    private let alGuardar: () -> Void

    init(bomba: Bomba, mangueras: [Manguera], corte: Corte, borrador: [LecturaManguera], iniciales: [UUID: Decimal],
         cambios: [CambioMedidor], servicio: CorteService, alGuardar: @escaping () -> Void) {
        self.bomba = bomba
        self.corte = corte
        self.iniciales = iniciales
        self.cambios = cambios
        self.servicio = servicio
        self.alGuardar = alGuardar
        lineas = mangueras.sorted { $0.combustible.orden < $1.combustible.orden }.map { m in
            let guardada = borrador.first { $0.mangueraId == m.id }
            return Linea(manguera: m,
                         inicial: guardada?.lecturaInicialManualGal.map(Formateadores.paraCampo) ?? "",
                         final: guardada.map { Formateadores.paraCampo($0.lecturaFinalGal) } ?? "")
        }
    }

    var esPrimerCorte: Bool { corte.secuencia == 1 }

    /// Lectura inicial efectiva de una manguera: la tecleada (primer corte) o la derivada del corte anterior.
    func inicial(de linea: Linea) -> Decimal? {
        esPrimerCorte ? Validadores.decimal(linea.inicial) : iniciales[linea.manguera.id]
    }

    func cambio(de linea: Linea) -> CambioMedidor? {
        cambios.first { $0.mangueraId == linea.manguera.id }
    }

    func errorInicial(_ linea: Linea) -> String? {
        guard esPrimerCorte else { return nil }
        if linea.inicial.isEmpty { return "Escribe la lectura inicial." }
        return Validadores.decimal(linea.inicial) == nil ? "Escribe un número válido." : nil
    }

    func errorFinal(_ linea: Linea) -> String? {
        guard !linea.final.isEmpty else { return "Escribe la lectura final." }
        guard let f = Validadores.decimal(linea.final) else { return "Escribe un número válido." }
        // Con cambio de medidor, la final se compara con la inicial del medidor nuevo.
        if let c = cambio(de: linea) {
            return f < c.lecturaInicialNuevoGal ? "La lectura final no puede ser menor que la inicial del medidor nuevo (\(Formateadores.numeroDosDecimales(c.lecturaInicialNuevoGal)))." : nil
        }
        if let i = inicial(de: linea), f < i {
            return "La lectura final no puede ser menor que la inicial (\(Formateadores.numeroDosDecimales(i)))."
        }
        if !esPrimerCorte && iniciales[linea.manguera.id] == nil {
            return "No hay lectura inicial para esta manguera: el corte anterior no la tiene."
        }
        return nil
    }

    var esValido: Bool { lineas.allSatisfy { errorInicial($0) == nil && errorFinal($0) == nil } }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido else {
            error = "Revisa las lecturas marcadas."
            return
        }
        let capturas = lineas.compactMap { l -> LecturaCaptura? in
            guard let f = Validadores.decimal(l.final) else { return nil }
            return LecturaCaptura(combustible: l.manguera.combustible, lecturaFinalGal: f,
                                  lecturaInicialGal: esPrimerCorte ? Validadores.decimal(l.inicial) : nil)
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.guardarLecturas(corteId: corte.id, bombaId: bomba.id, lecturas: capturas)
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
