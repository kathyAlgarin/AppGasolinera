import Foundation

struct Empleado: Codable, Hashable, Identifiable {
    let id: UUID
    let sucursalId: UUID
    var nombre: String
    var cargo: CargoEmpleado
    var telefono: String?
    /// "yyyy-MM-dd"
    var fechaIngreso: String?
    var activo: Bool
    let perfilId: UUID?
}

struct Turno: Codable, Hashable, Identifiable {
    let id: UUID
    let sucursalId: UUID
    var nombre: String
    /// "HH:mm:ss"
    var horaInicio: String
    var horaFin: String
    var activo: Bool

    /// Un fin menor que el inicio significa que el turno termina al día siguiente.
    var cruzaMedianoche: Bool { horaFin < horaInicio }
}

struct AsignacionTurno: Codable, Hashable, Identifiable {
    let empleadoId: UUID
    var turnoId: UUID
    let sucursalId: UUID
    /// 1 = lunes … 7 = domingo
    var dias: [Int]
    var id: UUID { empleadoId }
}

/// Resultado de `empleados_en_turno`.
struct EmpleadoEnTurno: Codable, Hashable, Identifiable {
    let empleadoId: UUID
    let nombre: String
    let cargo: CargoEmpleado
    let turnoId: UUID
    let turnoNombre: String
    let horaInicio: String
    let horaFin: String
    var id: UUID { empleadoId }
}
