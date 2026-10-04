import Foundation

/// 55 · Asignar a un empleado un turno y los días de la semana que trabaja (sin rotaciones).
@MainActor
final class AsignacionTurnoViewModel: ObservableObject {
    @Published var turnoId: UUID?
    @Published var dias: Set<Int>
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let empleado: Empleado
    let turnos: [Turno]
    private let existente: AsignacionTurno?
    private let sucursalId: UUID
    private let servicio: PersonalService
    private let alGuardar: () -> Void

    init(sucursalId: UUID, empleado: Empleado, turnos: [Turno], existente: AsignacionTurno?, servicio: PersonalService, alGuardar: @escaping () -> Void) {
        self.sucursalId = sucursalId
        self.empleado = empleado
        self.turnos = turnos.filter(\.activo)
        self.existente = existente
        self.servicio = servicio
        self.alGuardar = alGuardar
        turnoId = existente?.turnoId
        dias = Set(existente?.dias ?? [])
    }

    var tieneAsignacion: Bool { existente != nil }
    var esValido: Bool { turnoId != nil && !dias.isEmpty }

    func alternar(_ dia: Int) {
        if dias.contains(dia) { dias.remove(dia) } else { dias.insert(dia) }
    }

    func limpiarError() { error = nil }

    func guardar() async {
        guard let turnoId, !dias.isEmpty else {
            error = "Elige un turno y al menos un día."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.asignar(empleadoId: empleado.id, turnoId: turnoId, sucursalId: sucursalId, dias: dias.sorted())
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }

    func quitar() async {
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.quitarAsignacion(empleadoId: empleado.id)
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
