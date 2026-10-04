import Foundation
import Supabase

struct SupabasePersonalService: PersonalService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func empleados(sucursalId: UUID) async throws -> [Empleado] {
        try await Traductor.ejecutar {
            try await cliente.from("empleados").select().eq("sucursal_id", value: sucursalId).order("nombre").execute().value
        }
    }

    func turnos(sucursalId: UUID) async throws -> [Turno] {
        try await Traductor.ejecutar {
            try await cliente.from("turnos").select().eq("sucursal_id", value: sucursalId).order("hora_inicio").execute().value
        }
    }

    func asignaciones(sucursalId: UUID) async throws -> [AsignacionTurno] {
        try await Traductor.ejecutar {
            try await cliente.from("asignaciones_turno").select().eq("sucursal_id", value: sucursalId).execute().value
        }
    }

    // Los campos opcionales se envían como `null` explícito para poder borrarlos al editar.
    private struct EmpleadoCuerpo: Encodable {
        var sucursalId: UUID?
        let nombre: String
        let cargo: CargoEmpleado
        let telefono: String?
        let fechaIngreso: String?
        let activo: Bool

        enum CodingKeys: String, CodingKey { case sucursalId = "sucursal_id", nombre, cargo, telefono, fechaIngreso = "fecha_ingreso", activo }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(sucursalId, forKey: .sucursalId)
            try c.encode(nombre, forKey: .nombre)
            try c.encode(cargo, forKey: .cargo)
            try c.encode(telefono, forKey: .telefono)
            try c.encode(fechaIngreso, forKey: .fechaIngreso)
            try c.encode(activo, forKey: .activo)
        }
    }

    func crearEmpleado(sucursalId: UUID, nombre: String, cargo: CargoEmpleado, telefono: String?, fechaIngreso: String?, activo: Bool) async throws {
        try await Traductor.ejecutar {
            try await cliente.from("empleados").insert(
                EmpleadoCuerpo(sucursalId: sucursalId, nombre: nombre, cargo: cargo, telefono: telefono, fechaIngreso: fechaIngreso, activo: activo),
                returning: .minimal).execute()
        }
    }

    func editarEmpleado(id: UUID, nombre: String, cargo: CargoEmpleado, telefono: String?, fechaIngreso: String?, activo: Bool) async throws {
        try await Traductor.ejecutar {
            try await cliente.from("empleados").update(
                EmpleadoCuerpo(sucursalId: nil, nombre: nombre, cargo: cargo, telefono: telefono, fechaIngreso: fechaIngreso, activo: activo),
                returning: .minimal).eq("id", value: id).execute()
        }
    }

    private struct TurnoCuerpo: Encodable {
        var sucursalId: UUID?
        let nombre: String
        let horaInicio: String
        let horaFin: String
        let activo: Bool
    }

    func crearTurno(sucursalId: UUID, nombre: String, horaInicio: String, horaFin: String, activo: Bool) async throws {
        try await Traductor.ejecutar {
            try await cliente.from("turnos").insert(
                TurnoCuerpo(sucursalId: sucursalId, nombre: nombre, horaInicio: horaInicio, horaFin: horaFin, activo: activo),
                returning: .minimal).execute()
        }
    }

    func editarTurno(id: UUID, nombre: String, horaInicio: String, horaFin: String, activo: Bool) async throws {
        try await Traductor.ejecutar {
            try await cliente.from("turnos").update(
                TurnoCuerpo(sucursalId: nil, nombre: nombre, horaInicio: horaInicio, horaFin: horaFin, activo: activo),
                returning: .minimal).eq("id", value: id).execute()
        }
    }

    private struct AsignacionCuerpo: Encodable {
        let empleadoId: UUID
        let turnoId: UUID
        let sucursalId: UUID
        let dias: [Int]
    }

    func asignar(empleadoId: UUID, turnoId: UUID, sucursalId: UUID, dias: [Int]) async throws {
        try await Traductor.ejecutar {
            try await cliente.from("asignaciones_turno").upsert(
                AsignacionCuerpo(empleadoId: empleadoId, turnoId: turnoId, sucursalId: sucursalId, dias: dias.sorted()),
                onConflict: "empleado_id", returning: .minimal).execute()
        }
    }

    func quitarAsignacion(empleadoId: UUID) async throws {
        try await Traductor.ejecutar {
            try await cliente.from("asignaciones_turno").delete().eq("empleado_id", value: empleadoId).execute()
        }
    }

    private struct EnTurnoParams: Encodable {
        let pSucursal: UUID
        let pMomento: Date
    }

    func enTurno(sucursalId: UUID, momento: Date) async throws -> [EmpleadoEnTurno] {
        try await Traductor.ejecutar {
            try await cliente.rpc("empleados_en_turno", params: EnTurnoParams(pSucursal: sucursalId, pMomento: momento)).execute().value
        }
    }
}
