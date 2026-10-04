import Foundation

/// Empleados, turnos y asignaciones de una sucursal, más «Quién trabaja ahora».
@MainActor
final class PersonalViewModel: ObservableObject {
    struct Datos: Equatable {
        var empleados: [Empleado]
        var turnos: [Turno]
        var asignaciones: [AsignacionTurno]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published private(set) var ahora: Carga<[EmpleadoEnTurno]> = .inicial

    let sucursalId: UUID
    let soloLectura: Bool
    private let servicio: PersonalService
    private let reloj: () -> Date

    init(sucursalId: UUID, soloLectura: Bool, servicio: PersonalService, reloj: @escaping () -> Date = { Date() }) {
        self.sucursalId = sucursalId
        self.soloLectura = soloLectura
        self.servicio = servicio
        self.reloj = reloj
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            async let e = servicio.empleados(sucursalId: sucursalId)
            async let t = servicio.turnos(sucursalId: sucursalId)
            async let a = servicio.asignaciones(sucursalId: sucursalId)
            let (emp, tur, asig) = try await (e, t, a)
            estado = .listo(Datos(empleados: emp.sorted { ($0.activo ? 0 : 1, $0.nombre) < ($1.activo ? 0 : 1, $1.nombre) },
                                  turnos: tur.sorted { $0.horaInicio < $1.horaInicio }, asignaciones: asig))
        } catch {
            estado.registrarFallo(error)
        }
        await cargarAhora()
    }

    func cargarAhora() async {
        if ahora.valor == nil { ahora = .cargando }
        do {
            ahora = .listo(try await servicio.enTurno(sucursalId: sucursalId, momento: reloj()).sorted { $0.nombre < $1.nombre })
        } catch {
            ahora.registrarFallo(error)
        }
    }

    var datos: Datos? { estado.valor }
    var turnosActivos: [Turno] { (datos?.turnos ?? []).filter(\.activo) }

    func asignacion(de empleado: Empleado) -> AsignacionTurno? { datos?.asignaciones.first { $0.empleadoId == empleado.id } }
    func turno(de empleado: Empleado) -> Turno? {
        guard let a = asignacion(de: empleado) else { return nil }
        return datos?.turnos.first { $0.id == a.turnoId }
    }

    /// Empleados activos asignados a un turno en un día de la semana (1 = lunes … 7 = domingo).
    func empleados(en turno: Turno, dia: Int) -> [Empleado] {
        (datos?.empleados ?? []).filter { e in
            guard e.activo, let a = asignacion(de: e) else { return false }
            return a.turnoId == turno.id && a.dias.contains(dia)
        }
    }

    func textoDias(_ dias: [Int]) -> String {
        dias.sorted().map { Fechas.letrasDias[$0] }.joined(separator: " ")
    }
}
