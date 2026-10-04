import Foundation

/// Empleados (sin usuario en la app), turnos y su asignación semanal. Los administra el Gerente de Sucursal.
protocol PersonalService {
    func empleados(sucursalId: UUID) async throws -> [Empleado]
    func turnos(sucursalId: UUID) async throws -> [Turno]
    func asignaciones(sucursalId: UUID) async throws -> [AsignacionTurno]

    func crearEmpleado(sucursalId: UUID, nombre: String, cargo: CargoEmpleado, telefono: String?, fechaIngreso: String?, activo: Bool) async throws
    func editarEmpleado(id: UUID, nombre: String, cargo: CargoEmpleado, telefono: String?, fechaIngreso: String?, activo: Bool) async throws

    func crearTurno(sucursalId: UUID, nombre: String, horaInicio: String, horaFin: String, activo: Bool) async throws
    func editarTurno(id: UUID, nombre: String, horaInicio: String, horaFin: String, activo: Bool) async throws

    /// Un turno por empleado: crea o reemplaza su asignación.
    func asignar(empleadoId: UUID, turnoId: UUID, sucursalId: UUID, dias: [Int]) async throws
    func quitarAsignacion(empleadoId: UUID) async throws

    /// Empleados activos cuyo turno incluye el momento (considera días y turnos que cruzan la medianoche).
    func enTurno(sucursalId: UUID, momento: Date) async throws -> [EmpleadoEnTurno]
}
