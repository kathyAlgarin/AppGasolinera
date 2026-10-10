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
                        Text("Primer corte: captura también el contador inicial.").font(.callout)
                        AyudaBoton(texto: "Solo se pide una vez: es lo que marcaba cada manguera al empezar a usar el sistema. Desde el segundo corte, el contador inicial es el final del corte anterior.")
                    }
                    .foregroundColor(.secondary)
                }

                ForEach($form.lineas) { $linea in
                    TarjetaManguera(form: form, linea: $linea) {
                        cambiandoMedidor = linea.manguera.id
                    }
                }

                TarjetaResumenBomba(form: form, bombaNumero: bomba.numero)

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

private struct TarjetaManguera: View {
    @ObservedObject var form: BombaFormViewModel
    @Binding var linea: BombaFormViewModel.Linea
    let alCambiarMedidor: () -> Void

    var body: some View {
        let combustible = linea.manguera.combustible
        let despachados = form.galonesDespachados(de: linea)

        VStack(alignment: .leading, spacing: 12) {
            // 1. Identificación del combustible
            HStack(alignment: .center) {
                Label {
                    Text(combustible.nombre)
                        .font(.headline)
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemName: "fuelpump.fill")
                        .foregroundColor(combustible.color)
                }
                Spacer()
                if form.cambio(de: linea) != nil {
                    Insignia(texto: "Cambio de medidor", color: .gas76Blue)
                }
            }

            // 2. Destacado: Volumen despachado durante este corte
            VStack(alignment: .leading, spacing: 4) {
                Text("Galones despachados en este corte")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    if let g = despachados {
                        Text(Formateadores.galones(g))
                            .font(.title2.bold())
                            .foregroundColor(combustible.color)
                    } else {
                        Text("— gal")
                            .font(.title2.bold())
                            .foregroundColor(.secondary.opacity(0.5))
                        if !linea.final.isEmpty && form.errorFinal(linea) != nil {
                            Text("Dato no válido")
                                .font(.caption)
                                .foregroundColor(.gas76Rojo)
                        } else {
                            Text("Pendiente de contador final")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "drop.fill")
                        .font(.callout)
                        .foregroundColor(despachados != nil ? combustible.color : .secondary.opacity(0.25))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(despachados != nil
                          ? combustible.color.opacity(0.08)
                          : Color(UIColor.tertiarySystemGroupedBackground))
            )

            // 3. Contadores agrupados (inicial y final)
            VStack(alignment: .leading, spacing: 10) {
                if form.esPrimerCorte {
                    CampoNumerico(titulo: "Contador inicial",
                                  texto: $linea.inicial,
                                  unidad: "gal",
                                  error: linea.inicial.isEmpty ? nil : form.errorInicial(linea))
                } else if let i = form.iniciales[linea.manguera.id] {
                    FilaDato(titulo: "Contador inicial", valor: Formateadores.galones(i))
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                } else {
                    Text("Sin contador inicial: el corte anterior no tiene lectura de esta manguera.")
                        .font(.caption)
                        .foregroundColor(.gas76Rojo)
                }

                CampoNumerico(titulo: "Contador final",
                              texto: $linea.final,
                              unidad: "gal",
                              error: linea.final.isEmpty ? nil : form.errorFinal(linea))
            }
            .padding(10)
            .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // 4. Cambio de medidor
            Button(form.cambio(de: linea) == nil ? "El medidor se cambió" : "Ver cambio de medidor", action: alCambiarMedidor)
                .font(.footnote)
                .tint(.gas76Orange)
        }
        .padding()
        .background(Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct TarjetaResumenBomba: View {
    @ObservedObject var form: BombaFormViewModel
    let bombaNumero: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Encabezado
            HStack {
                Label("Resumen de Bomba \(bombaNumero)", systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .font(.headline)
                    .foregroundColor(.gas76Blue)
                Spacer()
                if form.totalBombaCompleto {
                    Insignia(texto: "Completo", color: .gas76Verde, conAyuda: false)
                } else if form.totalBombaParcial {
                    Insignia(texto: "Parcial", color: .gas76Orange, conAyuda: false)
                } else {
                    Insignia(texto: "Pendiente", color: .gas76Gris, conAyuda: false)
                }
            }

            // Volumen total despachado por esta bomba
            VStack(alignment: .leading, spacing: 3) {
                Text(form.totalBombaParcial ? "Total parcial despachado en este corte" : "Total despachado en este corte")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let total = form.totalGalonesBomba {
                    Text(Formateadores.galones(total))
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                } else {
                    Text("— gal")
                        .font(.title2.bold())
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }

            Divider()

            // Desglose por combustible de esta bomba
            VStack(spacing: 8) {
                ForEach(form.lineas) { linea in
                    HStack {
                        Circle()
                            .fill(linea.manguera.combustible.color)
                            .frame(width: 8, height: 8)
                        Text(linea.manguera.combustible.nombre)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        if let g = form.galonesDespachados(de: linea) {
                            Text(Formateadores.galones(g))
                                .font(.subheadline.monospacedDigit())
                                .fontWeight(.medium)
                        } else {
                            Text("Pendiente")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Nota contextual sobre la bomba
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(form.totalBombaParcial ? .gas76Orange : .secondary)
                Group {
                    if form.totalBombaCompleto {
                        Text("Suma de las \(form.lineas.count) mangueras de la Bomba \(bombaNumero). No incluye otras bombas ni inventario de tanques.")
                    } else if form.totalBombaParcial {
                        Text("Cálculo parcial (\(form.manguerasCompletasConteo) de \(form.lineas.count) mangueras). Faltan contadores para el total definitivo.")
                    } else {
                        Text("Introduce el contador final de cada manguera para calcular el total despachado por esta bomba.")
                    }
                }
                .font(.caption)
                .foregroundColor(form.totalBombaParcial ? .gas76Orange : .secondary)
            }
        }
        .padding()
        .background(Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
