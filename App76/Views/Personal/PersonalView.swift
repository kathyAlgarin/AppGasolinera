import SwiftUI

/// Pestaña «Personal» del Gerente de Sucursal. Con `soloLectura`, el Gerente General solo consulta.
struct PersonalView: View {
    let sucursalId: UUID
    let soloLectura: Bool
    @StateObject private var vm: PersonalViewModel

    init(sucursalId: UUID, soloLectura: Bool) {
        self.sucursalId = sucursalId
        self.soloLectura = soloLectura
        _vm = StateObject(wrappedValue: PersonalViewModel(sucursalId: sucursalId, soloLectura: soloLectura, servicio: Servicios.personal))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                QuienTrabajaAhoraView(vm: vm)
                enlace("Empleados", "person.3.fill", "Altas, cargos y estado") { EmpleadosView(vm: vm) }
                enlace("Turnos", "clock.fill", "Horas de inicio y fin") { TurnosView(vm: vm) }
                enlace("Horario semanal", "calendar", "Turnos por día de la semana") { HorarioSemanalView(vm: vm) }
                Text("Los turnos son solo informativos: no afectan cortes, pagos ni cajas.").font(.footnote).foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle("Personal")
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
    }

    private func enlace<D: View>(_ titulo: String, _ icono: String, _ detalle: String, @ViewBuilder destino: @escaping () -> D) -> some View {
        NavigationLink(destination: destino) { FilaSeccion(titulo: titulo, detalle: detalle, icono: icono) }.buttonStyle(.plain)
    }
}

/// 56 · Quién trabaja ahora.
struct QuienTrabajaAhoraView: View {
    @ObservedObject var vm: PersonalViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quién trabaja ahora").font(.headline).foregroundColor(.gas76Blue)
            CargaView(estado: vm.ahora, textoVacio: "Nadie en turno", iconoVacio: "moon.zzz",
                      esVacio: { $0.isEmpty }, reintentar: { Task { await vm.cargarAhora() } }) { lista in
                VStack(spacing: 8) {
                    ForEach(lista) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.nombre).font(.subheadline.bold())
                                Text(e.cargo.nombre).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(e.turnoNombre) · \(Fechas.hora(deTexto: e.horaInicio))–\(Fechas.hora(deTexto: e.horaFin))")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .tarjeta()
    }
}

/// 51 · Empleados.
struct EmpleadosView: View {
    @ObservedObject var vm: PersonalViewModel
    @State private var editando: Empleado?
    @State private var creando = false

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, textoVacio: "Aún no hay empleados.", iconoVacio: "person.3",
                      esVacio: { $0.empleados.isEmpty }, reintentar: { Task { await vm.cargar() } }) { d in
                LazyVStack(spacing: 10) {
                    ForEach(d.empleados) { e in
                        Button { if !vm.soloLectura { editando = e } } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(e.nombre).font(.headline).foregroundColor(.gas76Blue)
                                    HStack(spacing: 6) {
                                        Insignia(texto: e.cargo.nombre, color: .gas76Blue)
                                        if let t = vm.turno(de: e) { Insignia(texto: t.nombre, color: .gas76Gris) }
                                        if !e.activo { Insignia(texto: "Inactivo", color: .gas76Rojo) }
                                    }
                                }
                                Spacer()
                                if !vm.soloLectura { Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary) }
                            }
                            .tarjeta()
                            .opacity(e.activo ? 1 : 0.7)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Empleados")
        .toolbar {
            if !vm.soloLectura {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creando = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nuevo empleado")
                }
            }
        }
        .refreshable { await vm.cargar() }
        .sheet(isPresented: $creando) {
            EmpleadoFormView(sucursalId: vm.sucursalId, empleado: nil) { creando = false; Task { await vm.cargar() } } cerrar: { creando = false }
        }
        .sheet(item: $editando) { e in
            EmpleadoFormView(sucursalId: vm.sucursalId, empleado: e) { editando = nil; Task { await vm.cargar() } } cerrar: { editando = nil }
        }
    }
}

struct EmpleadoFormView: View {
    @StateObject private var vm: EmpleadoFormViewModel
    let cerrar: () -> Void
    @State private var intentado = false

    init(sucursalId: UUID, empleado: Empleado?, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: EmpleadoFormViewModel(sucursalId: sucursalId, empleado: empleado, servicio: Servicios.personal, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: vm.esEdicion ? "Editar empleado" : "Nuevo empleado", cerrar: cerrar) {
            CampoTexto(titulo: "Nombre completo", texto: $vm.nombre, capitalizacion: .words,
                       error: (intentado || !vm.nombre.isEmpty) ? vm.errorNombre : nil)
            VStack(alignment: .leading, spacing: 6) {
                Text("Cargo").font(.subheadline).foregroundColor(.secondary)
                Picker("Cargo", selection: $vm.cargo) { ForEach(CargoEmpleado.allCases) { Text($0.nombre).tag($0) } }.tint(.gas76Orange)
            }
            CampoTexto(titulo: "Teléfono (opcional)", texto: $vm.telefono, teclado: .phonePad, error: vm.errorTelefono)
            Toggle("Registrar fecha de ingreso", isOn: $vm.tieneFechaIngreso).tint(.gas76Orange)
            if vm.tieneFechaIngreso {
                DatePicker("Fecha de ingreso", selection: $vm.fechaIngreso, in: ...Date(), displayedComponents: .date)
            }
            Toggle("Activo", isOn: $vm.activo).tint(.gas76Orange)
            Text("No se guarda DUI ni otro documento. Un empleado se desactiva, nunca se borra.").font(.footnote).foregroundColor(.secondary)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) { intentado = true; Task { await vm.guardar() } }
        }
    }
}

/// 53 · Turnos.
struct TurnosView: View {
    @ObservedObject var vm: PersonalViewModel
    @State private var editando: Turno?
    @State private var creando = false

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, textoVacio: "Aún no hay turnos.", iconoVacio: "clock",
                      esVacio: { $0.turnos.isEmpty }, reintentar: { Task { await vm.cargar() } }) { d in
                LazyVStack(spacing: 10) {
                    ForEach(d.turnos) { t in
                        Button { if !vm.soloLectura { editando = t } } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t.nombre).font(.headline).foregroundColor(.gas76Blue)
                                    Text("\(Fechas.hora(deTexto: t.horaInicio)) – \(Fechas.hora(deTexto: t.horaFin))\(t.cruzaMedianoche ? " (día siguiente)" : "")")
                                        .font(.subheadline).foregroundColor(.secondary)
                                }
                                Spacer()
                                if !t.activo { Insignia(texto: "Inactivo", color: .gas76Rojo) }
                            }
                            .tarjeta()
                            .opacity(t.activo ? 1 : 0.7)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Turnos")
        .toolbar {
            if !vm.soloLectura {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { creando = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nuevo turno")
                }
            }
        }
        .refreshable { await vm.cargar() }
        .sheet(isPresented: $creando) {
            TurnoFormView(sucursalId: vm.sucursalId, turno: nil) { creando = false; Task { await vm.cargar() } } cerrar: { creando = false }
        }
        .sheet(item: $editando) { t in
            TurnoFormView(sucursalId: vm.sucursalId, turno: t) { editando = nil; Task { await vm.cargar() } } cerrar: { editando = nil }
        }
    }
}

struct TurnoFormView: View {
    @StateObject private var vm: TurnoFormViewModel
    let cerrar: () -> Void

    init(sucursalId: UUID, turno: Turno?, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: TurnoFormViewModel(sucursalId: sucursalId, turno: turno, servicio: Servicios.personal, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: vm.esEdicion ? "Editar turno" : "Nuevo turno", cerrar: cerrar) {
            CampoTexto(titulo: "Nombre", texto: $vm.nombre, capitalizacion: .words, error: vm.nombre.isEmpty ? nil : vm.errorNombre)
            DatePicker("Hora de inicio", selection: $vm.horaInicio, displayedComponents: .hourAndMinute)
            DatePicker("Hora de fin", selection: $vm.horaFin, displayedComponents: .hourAndMinute)
            if let e = vm.errorHoras { Text(e).font(.caption).foregroundColor(.gas76Rojo) }
            Text("Si el fin es menor que el inicio, el turno termina al día siguiente\(vm.cruzaMedianoche ? " (este lo hace)" : ""). Se permiten turnos que se solapan y huecos.")
                .font(.footnote).foregroundColor(.secondary)
            Toggle("Activo", isOn: $vm.activo).tint(.gas76Orange)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) { Task { await vm.guardar() } }
        }
    }
}

/// 55 · Horario semanal: cuadrícula turnos × días y asignación de cada empleado.
struct HorarioSemanalView: View {
    @ObservedObject var vm: PersonalViewModel
    @State private var asignando: Empleado?

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, textoVacio: "Crea turnos y empleados para armar el horario.", iconoVacio: "calendar",
                      esVacio: { $0.turnos.isEmpty }, reintentar: { Task { await vm.cargar() } }) { d in
                VStack(alignment: .leading, spacing: 16) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                            GridRow {
                                Text("Turno").font(.caption.bold())
                                ForEach(1...7, id: \.self) { Text(Fechas.letrasDias[$0]).font(.caption.bold()).frame(width: 64) }
                            }
                            ForEach(vm.turnosActivos) { t in
                                GridRow {
                                    VStack(alignment: .leading) {
                                        Text(t.nombre).font(.caption.bold())
                                        Text("\(Fechas.horaCorta(t.horaInicio))–\(Fechas.horaCorta(t.horaFin))").font(.caption2).foregroundColor(.secondary)
                                    }
                                    .frame(width: 70, alignment: .leading)
                                    ForEach(1...7, id: \.self) { dia in
                                        let gente = vm.empleados(en: t, dia: dia)
                                        VStack(spacing: 2) {
                                            if gente.isEmpty { Text("—").font(.caption2).foregroundColor(.secondary) }
                                            ForEach(gente) { Text($0.nombre.split(separator: " ").first.map(String.init) ?? $0.nombre).font(.caption2).lineLimit(1) }
                                        }
                                        .frame(width: 64, height: 48)
                                        .background(gente.isEmpty ? Color.gas76Card.opacity(0.5) : Color.gas76Orange.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                    if !vm.soloLectura {
                        Text("Asignar turno y días").font(.headline).foregroundColor(.gas76Blue)
                        ForEach(d.empleados.filter(\.activo)) { e in
                            Button { asignando = e } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.nombre).foregroundColor(.primary)
                                        if let a = vm.asignacion(de: e), let t = vm.turno(de: e) {
                                            Text("\(t.nombre) · \(vm.textoDias(a.dias))").font(.caption).foregroundColor(.secondary)
                                        } else {
                                            Text("Sin turno asignado").font(.caption).foregroundColor(.gas76Orange)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary)
                                }
                                .tarjeta(radio: 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Horario semanal")
        .refreshable { await vm.cargar() }
        .sheet(item: $asignando) { e in
            AsignacionTurnoView(sucursalId: vm.sucursalId, empleado: e, turnos: vm.datos?.turnos ?? [], existente: vm.asignacion(de: e)) {
                asignando = nil
                Task { await vm.cargar() }
            } cerrar: { asignando = nil }
        }
    }
}

struct AsignacionTurnoView: View {
    @StateObject private var vm: AsignacionTurnoViewModel
    let cerrar: () -> Void

    init(sucursalId: UUID, empleado: Empleado, turnos: [Turno], existente: AsignacionTurno?, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: AsignacionTurnoViewModel(sucursalId: sucursalId, empleado: empleado, turnos: turnos, existente: existente,
                                                                 servicio: Servicios.personal, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: vm.empleado.nombre, cerrar: cerrar) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Turno").font(.subheadline).foregroundColor(.secondary)
                Picker("Turno", selection: $vm.turnoId) {
                    Text("Elige un turno").tag(UUID?.none)
                    ForEach(vm.turnos) { Text("\($0.nombre) (\(Fechas.horaCorta($0.horaInicio))–\(Fechas.horaCorta($0.horaFin)))").tag(Optional($0.id)) }
                }
                .tint(.gas76Orange)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Días de la semana").font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { dia in
                        Button { vm.alternar(dia) } label: {
                            Text(Fechas.letrasDias[dia])
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(vm.dias.contains(dia) ? Color.gas76Orange : Color.gas76Card)
                                .foregroundColor(vm.dias.contains(dia) ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityLabel(Fechas.nombresDias[dia])
                    }
                }
            }
            Text("Cada empleado tiene un turno y los días que trabaja, sin rotaciones.").font(.footnote).foregroundColor(.secondary)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) { Task { await vm.guardar() } }
            if vm.tieneAsignacion {
                Button("Quitar turno", role: .destructive) { Task { await vm.quitar() } }.frame(maxWidth: .infinity)
            }
        }
    }
}

/// Resumen de personal en el detalle de sucursal del Gerente General (solo consulta).
struct PersonalSucursalResumenView: View {
    let sucursal: Sucursal
    @StateObject private var vm: PersonalViewModel

    init(sucursal: Sucursal) {
        self.sucursal = sucursal
        _vm = StateObject(wrappedValue: PersonalViewModel(sucursalId: sucursal.id, soloLectura: true, servicio: Servicios.personal))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personal").font(.headline).foregroundColor(.gas76Blue)
            if let d = vm.datos {
                FilaDato(titulo: "Empleados activos", valor: "\(d.empleados.filter(\.activo).count)")
                FilaDato(titulo: "Turnos activos", valor: "\(vm.turnosActivos.count)")
            }
            NavigationLink { PersonalView(sucursalId: sucursal.id, soloLectura: true) } label: {
                Label("Ver personal, turnos y horario", systemImage: "person.3").font(.subheadline)
            }
            .tint(.gas76Orange)
        }
        .tarjeta()
        .task { await vm.cargar() }
    }
}

/// 27 · Personal (Gerente General): elige una sucursal y consulta.
struct PersonalConsultaView: View {
    @StateObject private var sucursales = SucursalesViewModel(servicio: Servicios.sucursales)
    @State private var elegida: UUID?

    var body: some View {
        VStack(spacing: 0) {
            switch sucursales.estado {
            case .listo(let lista) where !lista.isEmpty:
                SelectorSucursal(sucursales: lista, seleccion: Binding(get: { elegida ?? lista.first?.id }, set: { elegida = $0 }), permitirTodas: false)
                    .padding()
                if let id = elegida ?? lista.first?.id {
                    PersonalView(sucursalId: id, soloLectura: true).id(id)
                }
            case .listo:
                Text("Aún no hay sucursales.").foregroundColor(.secondary).padding()
            case .error(let m):
                VStack { Text(m).foregroundColor(.gas76Rojo); Button("Reintentar") { Task { await sucursales.cargar() } } }.padding()
            default:
                ProgressView("Cargando…").padding()
            }
            Spacer(minLength: 0)
        }
        .background(Color.gas76Background)
        .navigationTitle("Personal")
        .navigationBarTitleDisplayMode(.inline)
        .task { await sucursales.cargar() }
    }
}
