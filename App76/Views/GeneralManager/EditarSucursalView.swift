import SwiftUI

/// 17 · Editar sucursal. Los tanques son de solo lectura.
struct EditarSucursalView: View {
    @StateObject private var vm: EditarSucursalViewModel
    @Environment(\.dismiss) private var dismiss

    init(sucursal: Sucursal, alGuardar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: EditarSucursalViewModel(
            sucursal: sucursal, servicio: Servicios.sucursales, alGuardar: alGuardar))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CampoTexto(titulo: "Nombre", texto: $vm.nombre, capitalizacion: .words, error: vm.errorNombre)
                CampoTexto(titulo: "Dirección", texto: $vm.direccion, error: vm.errorDireccion)
                Toggle("Activa", isOn: $vm.activa).tint(.gas76Orange)
                Toggle("Tiene tienda", isOn: $vm.tieneTienda).tint(.gas76Orange)
                Text("La tienda no se puede apagar si hay cajas abiertas. Una sucursal se desactiva, nunca se borra.")
                    .font(.footnote).foregroundColor(.secondary)

                Text("Tanques").font(.headline).foregroundColor(.gas76Blue).padding(.top, 8)
                CargaView(estado: vm.tanques, textoVacio: "Esta sucursal no tiene tanques.",
                          esVacio: { $0.isEmpty }, reintentar: { Task { await vm.cargarTanques() } }) { lista in
                    VStack(spacing: 8) {
                        ForEach(lista) { t in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.combustible.nombre).font(.subheadline.bold()).foregroundColor(t.combustible.color)
                                FilaDato(titulo: "Capacidad", valor: Formateadores.galones(t.capacidadGal))
                                FilaDato(titulo: "Nivel inicial", valor: Formateadores.galones(t.nivelInicialGal))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gas76Card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                MensajeError(texto: vm.error)
                BotonPrimario(titulo: "Guardar cambios", cargando: vm.guardando, habilitado: vm.esValido && vm.hayCambios) {
                    Task { await vm.guardar() }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gas76Background)
        .navigationTitle(vm.sucursal.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.cargarTanques() }
        .onChange(of: vm.nombre) { _, _ in vm.limpiarError() }
    }
}
