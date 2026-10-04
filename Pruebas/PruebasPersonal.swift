import Foundation

@MainActor
func pruebasPersonal() async {
    let sid = Ejemplo.sucursalId
    func emp(_ n: String, _ c: CargoEmpleado = .despachador, activo: Bool = true) -> Empleado {
        Empleado(id: UUID(), sucursalId: sid, nombre: n, cargo: c, telefono: nil, fechaIngreso: nil, activo: activo, perfilId: nil)
    }
    func turno(_ n: String, _ i: String, _ f: String, activo: Bool = true) -> Turno {
        Turno(id: UUID(), sucursalId: sid, nombre: n, horaInicio: i, horaFin: f, activo: activo)
    }

    await grupo("PersonalViewModel: horario semanal") {
        let p = PersonalFalso()
        let ana = emp("Ana"), beto = emp("Beto"), carla = emp("Carla", activo: false), dani = emp("Dani")
        let dia = turno("Día", "06:00:00", "14:00:00"), noche = turno("Noche", "22:00:00", "06:00:00")
        p.emp = [carla, dani, beto, ana]
        p.tur = [noche, dia]
        p.asig = [AsignacionTurno(empleadoId: ana.id, turnoId: dia.id, sucursalId: sid, dias: [1, 2, 3]),
                  AsignacionTurno(empleadoId: beto.id, turnoId: dia.id, sucursalId: sid, dias: [3, 4]),
                  AsignacionTurno(empleadoId: carla.id, turnoId: dia.id, sucursalId: sid, dias: [1]),
                  AsignacionTurno(empleadoId: dani.id, turnoId: noche.id, sucursalId: sid, dias: [1, 7])]
        let vm = PersonalViewModel(sucursalId: sid, soloLectura: false, servicio: p)
        await vm.cargar()
        igual(vm.datos?.empleados.map(\.nombre) ?? [], ["Ana", "Beto", "Dani", "Carla"], "activos primero, por nombre")
        igual(vm.datos?.turnos.map(\.nombre) ?? [], ["Día", "Noche"], "turnos por hora de inicio")
        igual(vm.empleados(en: dia, dia: 3).map(\.nombre).sorted(), ["Ana", "Beto"], "miércoles de día")
        igual(vm.empleados(en: dia, dia: 1).map(\.nombre), ["Ana"], "los inactivos no aparecen en el horario")
        igual(vm.empleados(en: noche, dia: 7).map(\.nombre), ["Dani"], "domingo de noche")
        verificar(vm.empleados(en: noche, dia: 2).isEmpty, "martes de noche nadie")
        igual(vm.turno(de: ana)?.nombre, "Día", "turno de Ana")
        igual(vm.textoDias([3, 1, 7]), "L X D", "días en letras")
        igual(vm.turnosActivos.count, 2, "turnos activos")
    }

    await grupo("PersonalViewModel: quién trabaja ahora") {
        let p = PersonalFalso()
        let reloj = Date(timeIntervalSince1970: 1_700_000_000)
        let vm = PersonalViewModel(sucursalId: sid, soloLectura: true, servicio: p, reloj: { reloj })
        await vm.cargar()
        igual(vm.ahora.valor?.count ?? -1, 0, "en un hueco: nadie en turno")
        igual(p.momentoConsultado, reloj, "consulta el momento actual")
        p.turnoAhora = [EmpleadoEnTurno(empleadoId: UUID(), nombre: "Zoe", cargo: .cajero, turnoId: UUID(), turnoNombre: "Día", horaInicio: "06:00:00", horaFin: "14:00:00"),
                        EmpleadoEnTurno(empleadoId: UUID(), nombre: "Ana", cargo: .despachador, turnoId: UUID(), turnoNombre: "Día", horaInicio: "06:00:00", horaFin: "14:00:00")]
        await vm.cargarAhora()
        igual(vm.ahora.valor?.map(\.nombre) ?? [], ["Ana", "Zoe"], "ordenados por nombre")
        verificar(vm.soloLectura, "el Gerente General solo consulta")
    }

    await grupo("EmpleadoFormViewModel") {
        let p = PersonalFalso()
        var ok = false
        let vm = EmpleadoFormViewModel(sucursalId: sid, empleado: nil, servicio: p) { ok = true }
        verificar(!vm.esValido, "sin nombre")
        vm.nombre = "Luis Pérez"
        vm.cargo = .supervisor
        vm.telefono = "abc"
        verificar(vm.errorTelefono != nil, "teléfono con letras")
        vm.telefono = "123"
        verificar(vm.errorTelefono != nil, "teléfono muy corto")
        vm.telefono = "+503 7777-1234"
        verificar(vm.errorTelefono == nil, "teléfono válido")
        vm.tieneFechaIngreso = true
        vm.fechaIngreso = Fechas.fecha(deDia: "2026-09-15")!
        await vm.guardar()
        verificar(ok, "creó")
        igual(p.llamadas, ["crearEmpleado:Luis Pérez:supervisor:+503 7777-1234:2026-09-15:true"], "alta sin DUI")

        let existente = Empleado(id: UUID(), sucursalId: sid, nombre: "Ana", cargo: .cajero, telefono: "77771234", fechaIngreso: "2026-01-02", activo: true, perfilId: nil)
        let ed = EmpleadoFormViewModel(sucursalId: sid, empleado: existente, servicio: p) {}
        igual(ed.telefono, "77771234", "precarga")
        verificar(ed.tieneFechaIngreso, "precarga la fecha de ingreso")
        ed.telefono = ""
        ed.activo = false
        await ed.guardar()
        igual(p.llamadas.last, "editarEmpleado:Ana:nil:false", "al vaciar el teléfono se envía nulo; se desactiva, no se borra")
    }

    await grupo("TurnoFormViewModel") {
        let p = PersonalFalso()
        let base = Fechas.fecha(deDia: "2026-10-05")!
        var ok = false
        let vm = TurnoFormViewModel(sucursalId: sid, turno: nil, servicio: p, alGuardar: { ok = true }, base: base)
        verificar(!vm.esValido, "sin nombre")
        vm.nombre = "Noche"
        vm.horaInicio = Fechas.fecha(deHora: "22:00:00", base: base)
        vm.horaFin = Fechas.fecha(deHora: "22:00:00", base: base)
        verificar(vm.errorHoras != nil, "inicio igual a fin no vale")
        vm.horaFin = Fechas.fecha(deHora: "06:00:00", base: base)
        verificar(vm.cruzaMedianoche, "22:00–06:00 cruza la medianoche")
        igual(vm.inicioTexto, "22:00:00", "formato de hora")
        await vm.guardar()
        verificar(ok, "creó")
        igual(p.llamadas, ["crearTurno:Noche:22:00:00:06:00:00"], "turno nocturno")
        let diurno = TurnoFormViewModel(sucursalId: sid, turno: turno("Día", "06:00:00", "14:00:00"), servicio: p, alGuardar: {}, base: base)
        verificar(!diurno.cruzaMedianoche, "06:00–14:00 no cruza")
        igual(diurno.nombre, "Día", "precarga")
    }

    await grupo("AsignacionTurnoViewModel") {
        let p = PersonalFalso()
        let ana = emp("Ana")
        let dia = turno("Día", "06:00:00", "14:00:00"), viejo = turno("Viejo", "01:00:00", "02:00:00", activo: false)
        var ok = false
        let vm = AsignacionTurnoViewModel(sucursalId: sid, empleado: ana, turnos: [dia, viejo], existente: nil, servicio: p) { ok = true }
        igual(vm.turnos.count, 1, "solo turnos activos")
        verificar(!vm.esValido, "sin turno ni días")
        vm.turnoId = dia.id
        verificar(!vm.esValido, "sin días")
        vm.alternar(1); vm.alternar(3); vm.alternar(5); vm.alternar(3)
        igual(vm.dias, [1, 5], "alternar días")
        await vm.guardar()
        verificar(ok, "asignó")
        igual(p.llamadas, ["asignar:[1, 5]"], "días ordenados")
        let con = AsignacionTurnoViewModel(sucursalId: sid, empleado: ana, turnos: [dia], existente: AsignacionTurno(empleadoId: ana.id, turnoId: dia.id, sucursalId: sid, dias: [2, 4]),
                                           servicio: p) {}
        verificar(con.tieneAsignacion && con.dias == [2, 4], "precarga la asignación")
        await con.quitar()
        igual(p.llamadas.last, "quitar", "quita la asignación")
    }
}
