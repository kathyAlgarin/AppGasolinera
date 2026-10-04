import Foundation

/// 52 · Empleado: sin DUI ni otro documento (dato sensible innecesario). Se desactiva, nunca se borra.
@MainActor
final class EmpleadoFormViewModel: ObservableObject {
    @Published var nombre: String
    @Published var cargo: CargoEmpleado
    @Published var telefono: String
    @Published var tieneFechaIngreso: Bool
    @Published var fechaIngreso: Date
    @Published var activo: Bool
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let empleado: Empleado?
    private let sucursalId: UUID
    private let servicio: PersonalService
    private let alGuardar: () -> Void

    var esEdicion: Bool { empleado != nil }

    init(sucursalId: UUID, empleado: Empleado?, servicio: PersonalService, alGuardar: @escaping () -> Void) {
        self.sucursalId = sucursalId
        self.empleado = empleado
        self.servicio = servicio
        self.alGuardar = alGuardar
        nombre = empleado?.nombre ?? ""
        cargo = empleado?.cargo ?? .despachador
        telefono = empleado?.telefono ?? ""
        let fecha = empleado?.fechaIngreso.flatMap { Fechas.fecha(deDia: $0) }
        tieneFechaIngreso = fecha != nil
        fechaIngreso = fecha ?? Date()
        activo = empleado?.activo ?? true
    }

    var errorNombre: String? {
        (2...80).contains(Validadores.textoLimpio(nombre).count) ? nil : "El nombre debe tener entre 2 y 80 caracteres."
    }

    /// Mismo patrón que la base de datos: dígitos, +, paréntesis, espacios y guiones; de 7 a 20 caracteres.
    var errorTelefono: String? {
        let t = Validadores.textoLimpio(telefono)
        if t.isEmpty { return nil }
        let permitido = t.allSatisfy { "0123456789+() -".contains($0) }
        return permitido && (7...20).contains(t.count) ? nil : "El teléfono debe tener de 7 a 20 caracteres: números, +, ( ), espacios y guiones."
    }

    var esValido: Bool { errorNombre == nil && errorTelefono == nil }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido else {
            error = "Revisa los campos marcados."
            return
        }
        let tel = Validadores.textoLimpio(telefono)
        let ingreso = tieneFechaIngreso ? Fechas.diaISO(fechaIngreso) : nil
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            if let empleado {
                try await servicio.editarEmpleado(id: empleado.id, nombre: Validadores.textoLimpio(nombre), cargo: cargo,
                                                  telefono: tel.isEmpty ? nil : tel, fechaIngreso: ingreso, activo: activo)
            } else {
                try await servicio.crearEmpleado(sucursalId: sucursalId, nombre: Validadores.textoLimpio(nombre), cargo: cargo,
                                                 telefono: tel.isEmpty ? nil : tel, fechaIngreso: ingreso, activo: activo)
            }
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
