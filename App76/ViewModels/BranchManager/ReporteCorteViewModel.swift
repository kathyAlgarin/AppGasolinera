import Foundation

/// 13 · Reporte de un corte cerrado (lo ven ambos gerentes). 14 · Ajuste de una lectura (solo Gerente General).
@MainActor
final class ReporteCorteViewModel: ObservableObject {
    @Published private(set) var estado: Carga<ReporteCorte> = .inicial

    let corte: Corte
    let puedeAjustarPorRol: Bool
    private let servicio: ReportesService

    init(corte: Corte, esGerenteGeneral: Bool, servicio: ReportesService) {
        self.corte = corte
        self.puedeAjustarPorRol = esGerenteGeneral
        self.servicio = servicio
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            estado = .listo(try await servicio.reporte(corte: corte))
        } catch {
            estado.registrarFallo(error)
        }
    }

    var reporte: ReporteCorte? { estado.valor }

    /// Las 6 bombas con sus tres mangueras (inicial, final, galones).
    var bombas: [(numero: Int, lecturas: [LecturaEfectiva])] {
        guard let r = reporte else { return [] }
        return Dictionary(grouping: r.lecturas, by: \.bombaNumero)
            .map { (numero: $0.key, lecturas: $0.value.sorted { $0.combustible.orden < $1.combustible.orden }) }
            .sorted { $0.numero < $1.numero }
    }

    func precio(_ combustible: Combustible) -> Decimal? {
        reporte?.precios.first { $0.combustible == combustible }?.precioGal
    }

    /// USD de una manguera: galones × precio guardado en el corte (solo para mostrar por bomba; el total lo trae el servidor).
    func usd(_ lectura: LecturaEfectiva) -> Decimal? {
        precio(lectura.combustible).map { lectura.galones * $0 }
    }

    /// Solo el Gerente General, y solo si el corte siguiente aún no se cerró.
    var puedeAjustar: Bool { puedeAjustarPorRol && reporte.map { !$0.siguienteCerrado } == true }
    var esDefinitivo: Bool { puedeAjustarPorRol && reporte?.siguienteCerrado == true }

    func combustible(deTanque id: UUID) -> Combustible? {
        reporte?.resumen.first { $0.tanqueId == id }?.combustible
    }
}

@MainActor
final class AjustarLecturaViewModel: ObservableObject {
    @Published var mangueraId: UUID
    @Published var valor = ""
    @Published var motivo = ""
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let lecturas: [LecturaEfectiva]
    let corteId: UUID
    private let servicio: ReportesService
    private let alGuardar: () -> Void

    init(corteId: UUID, lecturas: [LecturaEfectiva], servicio: ReportesService, alGuardar: @escaping () -> Void) {
        self.corteId = corteId
        self.lecturas = lecturas.sorted { ($0.bombaNumero, $0.combustible.orden) < ($1.bombaNumero, $1.combustible.orden) }
        self.servicio = servicio
        self.alGuardar = alGuardar
        mangueraId = self.lecturas.first?.mangueraId ?? UUID()
    }

    var lecturaElegida: LecturaEfectiva? { lecturas.first { $0.mangueraId == mangueraId } }

    func etiqueta(_ l: LecturaEfectiva) -> String { "Bomba \(l.bombaNumero) · \(l.combustible.nombre)" }

    var errorValor: String? {
        guard let v = Validadores.decimal(valor) else { return "Escribe el valor correcto." }
        if let i = lecturaElegida?.lecturaInicialGal, v < i {
            return "No puede ser menor que la lectura inicial (\(Formateadores.numeroDosDecimales(i)))."
        }
        return nil
    }

    var errorMotivo: String? {
        Validadores.textoLimpio(motivo).count >= 3 ? nil : "El motivo es obligatorio (mínimo 3 caracteres)."
    }

    var esValido: Bool { errorValor == nil && errorMotivo == nil }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido, let v = Validadores.decimal(valor) else {
            error = "Revisa los campos marcados."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.registrarAjuste(corteId: corteId, mangueraId: mangueraId, valor: v, motivo: Validadores.textoLimpio(motivo))
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
