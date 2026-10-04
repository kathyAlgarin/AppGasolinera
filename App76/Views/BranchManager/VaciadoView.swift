import SwiftUI

/// 39 · Descarga errónea y vaciado de tanque (hoja).
struct VaciadoView: View {
    @StateObject private var vm: VaciadoViewModel
    let cerrar: () -> Void
    @State private var confirmando = false

    init(corteId: UUID, tanques: [EstadoTanque], alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: VaciadoViewModel(corteId: corteId, tanques: tanques, servicio: Servicios.lineas, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Descarga errónea y vaciado", cerrar: cerrar) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Motivo").font(.subheadline).foregroundColor(.secondary)
                Picker("Motivo", selection: $vm.motivo) {
                    ForEach(MotivoVaciado.allCases) { Text($0.nombre).tag($0) }
                }
                .pickerStyle(.menu).tint(.gas76Orange)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Tanque afectado").font(.subheadline).foregroundColor(.secondary)
                Picker("Tanque", selection: $vm.tanqueId) {
                    ForEach(vm.tanques) { Text($0.combustible.nombre).tag($0.tanqueId) }
                }
                .pickerStyle(.segmented)
            }
            if vm.esDescargaErronea {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Combustible que traía la cisterna").font(.subheadline).foregroundColor(.secondary)
                    Picker("Combustible", selection: $vm.combustibleErroneo) {
                        ForEach(vm.opcionesErroneo) { Text($0.nombre).tag(Optional($0)) }
                    }
                    .pickerStyle(.segmented)
                }
                CampoNumerico(titulo: "Galones descargados por error", texto: $vm.galonesErroneos, unidad: "gal",
                              error: vm.galonesErroneos.isEmpty ? nil : vm.errorGalonesErroneos)
            }
            CampoNumerico(titulo: "Nivel medido tras la descarga (varilla)", texto: $vm.nivelMedido, unidad: "gal",
                          ayuda: "Se usa el nivel medido con varilla, no el estimado: el estimado no incluye lo vendido desde el último corte, y así el cuadre queda correcto.",
                          error: vm.nivelMedido.isEmpty ? nil : vm.errorNivel)
            CampoNota(titulo: "Nota", texto: $vm.nota, obligatorio: true, error: vm.nota.isEmpty ? nil : vm.errorNota)

            if !vm.vistaPrevia.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Se registrarán").font(.subheadline.bold())
                    ForEach(vm.vistaPrevia, id: \.self) { Text("• \($0)").font(.footnote) }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gas76Orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Registrar y vaciar", cargando: vm.guardando, habilitado: vm.esValido, tint: .gas76Rojo) {
                confirmando = true
            }
        }
        .onChange(of: vm.nota) { _, _ in vm.limpiarError() }
        .alert("¿Registrar y vaciar el tanque?", isPresented: $confirmando) {
            Button("Cancelar", role: .cancel) {}
            Button("Registrar y vaciar", role: .destructive) { Task { await vm.registrar() } }
        } message: {
            Text("El tanque quedará en 0 hasta que entre una compra nueva. Esto no se puede deshacer.")
        }
    }
}
