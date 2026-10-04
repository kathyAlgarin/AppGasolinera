import Foundation

/// 54 · Turno: nombre y horas. Un fin menor que el inicio significa «al día siguiente». Solo informativo.
@MainActor
final class TurnoFormViewModel: ObservableObject {
    @Published var nombre: String
    @Published var horaInicio: Date
    @Published var horaFin: Date
    @Published var activo: Bool
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let turno: Turno?
    private let sucursalId: UUID
    private let servicio: PersonalService
    private let alGuardar: () -> Void

    var esEdicion: Bool { turno != nil }

    init(sucursalId: UUID, turno: Turno?, servicio: PersonalService, alGuardar: @escaping () -> Void, base: Date = Date()) {
        self.sucursalId = sucursalId
        self.turno = turno
        self.servicio = servicio
        self.alGuardar = alGuardar
        nombre = turno?.nombre ?? ""
        horaInicio = turno.map { Fechas.fecha(deHora: $0.horaInicio, base: base) } ?? Fechas.fecha(deHora: "06:00:00", base: base)
        horaFin = turno.map { Fechas.fecha(deHora: $0.horaFin, base: base) } ?? Fechas.fecha(deHora: "14:00:00", base: base)
        activo = turno?.activo ?? true
    }

    var inicioTexto: String { Fechas.horaTexto(de: horaInicio) }
    var finTexto: String { Fechas.horaTexto(de: horaFin) }

    var errorNombre: String? {
        (2...40).contains(Validadores.textoLimpio(nombre).count) ? nil : "El nombre debe tener entre 2 y 40 caracteres."
    }
    var errorHoras: String? { inicioTexto == finTexto ? "La hora de inicio y la de fin no pueden ser iguales." : nil }
    var cruzaMedianoche: Bool { finTexto < inicioTexto }
    var esValido: Bool { errorNombre == nil && errorHoras == nil }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido else {
            error = "Revisa los campos marcados."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            if let turno {
                try await servicio.editarTurno(id: turno.id, nombre: Validadores.textoLimpio(nombre), horaInicio: inicioTexto, horaFin: finTexto, activo: activo)
            } else {
                try await servicio.crearTurno(sucursalId: sucursalId, nombre: Validadores.textoLimpio(nombre), horaInicio: inicioTexto, horaFin: finTexto, activo: activo)
            }
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
