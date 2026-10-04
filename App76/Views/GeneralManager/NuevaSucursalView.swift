import SwiftUI

/// 16 · Nueva sucursal (hoja).
struct NuevaSucursalView: View {
    @StateObject private var vm: NuevaSucursalViewModel
    let cerrar: () -> Void

    init(alCrear: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: NuevaSucursalViewModel(servicio: Servicios.sucursales, alCrear: alCrear))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Nueva sucursal", cerrar: cerrar) {
            CampoTexto(titulo: "Nombre", texto: $vm.nombre, capitalizacion: .words,
                       error: vm.mostrar(vm.errorNombre, vacio: vm.nombre.isEmpty))
            CampoTexto(titulo: "Dirección", texto: $vm.direccion,
                       error: vm.mostrar(vm.errorDireccion, vacio: vm.direccion.isEmpty))
            Toggle("Tiene tienda", isOn: $vm.tieneTienda).tint(.gas76Orange)

            ForEach(Combustible.allCases) { c in
                VStack(alignment: .leading, spacing: 10) {
                    Label("Tanque de \(c.nombre)", systemImage: "fuelpump.fill")
                        .font(.headline).foregroundColor(c.color)
                    CampoNumerico(titulo: "Capacidad", texto: binding(\.capacidades, c), unidad: "gal",
                                  error: vm.mostrar(vm.errorCapacidad(c), vacio: (vm.capacidades[c] ?? "").isEmpty))
                    CampoNumerico(titulo: "Nivel inicial", texto: binding(\.niveles, c), unidad: "gal",
                                  error: vm.mostrar(vm.errorNivel(c), vacio: (vm.niveles[c] ?? "").isEmpty))
                }
                .padding()
                .background(Color.gas76Card.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text("Se crearán 6 bombas, 18 mangueras y 3 tanques.")
                .font(.footnote).foregroundColor(.secondary)
            if !vm.esValido {
                Text("Para crearla completa el nombre, la dirección y la capacidad de los tres tanques.")
                    .font(.footnote).foregroundColor(.secondary)
            }
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Crear sucursal", cargando: vm.guardando, habilitado: vm.esValido) {
                Task { await vm.crear() }
            }
        }
        .onChange(of: vm.nombre) { _, _ in vm.limpiarError() }
    }

    private func binding(_ clave: ReferenceWritableKeyPath<NuevaSucursalViewModel, [Combustible: String]>, _ c: Combustible) -> Binding<String> {
        Binding(get: { vm[keyPath: clave][c] ?? "" }, set: { vm[keyPath: clave][c] = $0 })
    }
}
