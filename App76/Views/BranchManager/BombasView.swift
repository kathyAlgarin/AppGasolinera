import SwiftUI

/// 32 · Lista de las 6 bombas (Pendiente / Guardada).
struct BombasListView: View {
    @ObservedObject var vm: CorteEnCursoViewModel

    var body: some View {
        List {
            if let d = vm.datos {
                Section {
                    ForEach(d.infra.bombas) { b in
                        let guardada = vm.bombasGuardadas.contains(b.id)
                        NavigationLink(value: RutaCorte.bomba(b.id)) {
                            HStack {
                                Image(systemName: guardada ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(guardada ? .gas76Verde : .secondary)
                                Text("Bomba \(b.numero)")
                                Spacer()
                                Text(guardada ? "Guardada" : "Pendiente").font(.caption).foregroundColor(guardada ? .gas76Verde : .secondary)
                            }
                        }
                    }
                } footer: {
                    Text("\(vm.bombasGuardadas.count) de 6 bombas. Cada bomba guardada se puede editar hasta cerrar el corte.")
                }
            }
        }
        .navigationTitle("Bombas")
        .refreshable { await vm.cargar() }
    }
}

/// 33 · Lecturas de una bomba (3 mangueras). 34 · Cambio de medidor.
struct BombaFormView: View {
    @ObservedObject var vm: CorteEnCursoViewModel
    let bombaId: UUID

    var body: some View {
        if let d = vm.datos, let bomba = d.infra.bombas.first(where: { $0.id == bombaId }) {
            ContenidoBomba(vm: vm, bomba: bomba, datos: d)
        } else {
            ProgressView().navigationTitle("Bomba")
        }
    }
}

private struct ContenidoBomba: View {
    @ObservedObject var vm: CorteEnCursoViewModel
    let bomba: Bomba
    let datos: CorteEnCursoViewModel.Datos
    @StateObject private var form: BombaFormViewModel
    @State private var cambiandoMedidor: UUID?
    @Environment(\.dismiss) private var dismiss

    init(vm: CorteEnCursoViewModel, bomba: Bomba, datos: CorteEnCursoViewModel.Datos) {
        self.vm = vm
        self.bomba = bomba
        self.datos = datos
        _form = StateObject(wrappedValue: BombaFormViewModel(
            bomba: bomba, mangueras: datos.infra.mangueras(de: bomba), corte: datos.corte, borrador: datos.borrador,
            iniciales: datos.iniciales, cambios: datos.cambios, servicio: Servicios.corte,
            alGuardar: {}))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if form.esPrimerCorte {
                    HStack(spacing: 4) {
                        Text("Primer corte: captura también la lectura inicial.").font(.callout)
                        AyudaBoton(texto: "Solo se pide una vez: es lo que marcaba cada manguera al empezar a usar el sistema. Desde el segundo corte, la inicial es la final del corte anterior.")
                    }
                    .foregroundColor(.secondary)
                }
                ForEach($form.lineas) { $linea in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(linea.manguera.combustible.nombre, systemImage: "fuelpump.fill")
                                .font(.headline).foregroundColor(linea.manguera.combustible.color)
                            Spacer()
                            if form.cambio(de: linea) != nil { Insignia(texto: "Cambio de medidor", color: .gas76Blue) }
                        }
                        if form.esPrimerCorte {
                            CampoNumerico(titulo: "Lectura inicial", texto: $linea.inicial, unidad: "gal",
                                          error: linea.inicial.isEmpty ? nil : form.errorInicial(linea))
                        } else if let i = form.iniciales[linea.manguera.id] {
                            FilaDato(titulo: "Lectura inicial", valor: Formateadores.galones(i))
                        } else {
                            Text("Sin lectura inicial: el corte anterior no tiene lectura de esta manguera.")
                                .font(.caption).foregroundColor(.gas76Rojo)
                        }
                        CampoNumerico(titulo: "Lectura final", texto: $linea.final, unidad: "gal",
                                      error: linea.final.isEmpty ? nil : form.errorFinal(linea))
                        Button(form.cambio(de: linea) == nil ? "El medidor se cambió" : "Ver cambio de medidor") {
                            cambiandoMedidor = linea.manguera.id
                        }
                        .font(.footnote).tint(.gas76Orange)
                    }
                    .padding()
                    .background(Color.gas76Card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                MensajeError(texto: form.error)
                BotonPrimario(titulo: "Guardar bomba", cargando: form.guardando, habilitado: form.esValido) {
                    Task {
                        await form.guardar()
                        if form.error == nil {
                            await vm.cargar()
                            dismiss()
                        }
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gas76Background)
        .navigationTitle("Bomba \(bomba.numero)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(get: { cambiandoMedidor.map(Identificado.init) }, set: { cambiandoMedidor = $0?.id })) { item in
            CambioMedidorView(corte: datos.corte, mangueras: datos.infra.mangueras(de: bomba), mangueraInicial: item.id,
                              borrador: datos.borrador, iniciales: datos.iniciales, existentes: datos.cambios) {
                cambiandoMedidor = nil
                Task { await vm.cargar() }
            } cerrar: { cambiandoMedidor = nil }
        }
    }
}

struct Identificado: Identifiable { let id: UUID }

struct CambioMedidorView: View {
    @StateObject private var vm: CambioMedidorViewModel
    let cerrar: () -> Void

    init(corte: Corte, mangueras: [Manguera], mangueraInicial: UUID, borrador: [LecturaManguera], iniciales: [UUID: Decimal],
         existentes: [CambioMedidor], alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: CambioMedidorViewModel(
            corte: corte, mangueras: mangueras, mangueraInicial: mangueraInicial, borrador: borrador, iniciales: iniciales,
            existentes: existentes, servicio: Servicios.corte, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Cambio de medidor", cerrar: cerrar) {
            Text("Si se cambió físicamente el totalizador de una manguera (el contador nuevo marca 0 o un valor bajo), regístralo aquí. Guarda primero las lecturas de la bomba.")
                .font(.callout).foregroundColor(.secondary)
            Picker("Manguera", selection: $vm.mangueraId) {
                ForEach(vm.mangueras) { Text($0.combustible.nombre).tag($0.id) }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.mangueraId) { _, nuevo in vm.precargar(nuevo) }

            CampoNumerico(titulo: "Lectura final del medidor viejo", texto: $vm.finalViejo, unidad: "gal",
                          error: vm.finalViejo.isEmpty ? nil : vm.errorFinalViejo)
            CampoNumerico(titulo: "Lectura inicial del medidor nuevo", texto: $vm.inicialNuevo, unidad: "gal",
                          error: vm.errorInicialNuevo)
            CampoNota(titulo: "Nota", texto: $vm.nota, obligatorio: true, error: vm.nota.isEmpty ? nil : vm.errorNota)

            Text("Galones de la manguera = (final del viejo − inicial) + (final − inicial del nuevo).")
                .font(.footnote).foregroundColor(.secondary)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) { Task { await vm.guardar() } }
            if vm.existente != nil {
                Button("Quitar el cambio de medidor", role: .destructive) { Task { await vm.eliminar() } }
                    .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: vm.nota) { _, _ in vm.limpiarError() }
    }
}
