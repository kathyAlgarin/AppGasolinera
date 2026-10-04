import SwiftUI

/// 35 · Compras del corte en curso. 36 · Nueva compra / edición.
struct ComprasView: View {
    @ObservedObject var vm: CorteEnCursoViewModel

    var body: some View {
        if let d = vm.datos {
            ContenidoCompras(hub: vm, datos: d)
        }
    }
}

private struct ContenidoCompras: View {
    @ObservedObject var hub: CorteEnCursoViewModel
    let datos: CorteEnCursoViewModel.Datos
    @StateObject private var vm: ComprasViewModel
    @State private var formulario: CompraCombustible?
    @State private var nueva = false

    init(hub: CorteEnCursoViewModel, datos: CorteEnCursoViewModel.Datos) {
        self.hub = hub
        self.datos = datos
        _vm = StateObject(wrappedValue: ComprasViewModel(corteId: datos.corte.id, tanques: datos.tanques, servicio: Servicios.lineas))
    }

    var body: some View {
        List {
            if let e = vm.error { Section { MensajeError(texto: e) } }
            switch vm.estado {
            case .inicial, .cargando:
                ProgressView("Cargando…").frame(maxWidth: .infinity)
            case .error(let m):
                VStack { Text(m).foregroundColor(.gas76Rojo); Button("Reintentar") { Task { await vm.cargar() } } }
            case .listo(let compras):
                if compras.isEmpty {
                    Text("Sin compras registradas en este corte.").foregroundColor(.secondary)
                }
                ForEach(compras) { c in
                    FilaCompra(compra: c, combustible: vm.combustible(de: c), editable: vm.esEditable(c))
                        .swipeActions {
                            if vm.esEditable(c) {
                                Button("Eliminar", role: .destructive) { Task { await vm.eliminar(c); await hub.cargar() } }
                                Button("Editar") { formulario = c }.tint(.gas76Orange)
                            }
                        }
                        .onTapGesture { if vm.esEditable(c) { formulario = c } }
                }
            }
        }
        .navigationTitle("Compras")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { nueva = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nueva compra")
            }
        }
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
        .sheet(isPresented: $nueva) {
            CompraFormView(corteId: datos.corte.id, tanques: datos.tanques, compra: nil) {
                nueva = false
                Task { await vm.cargar(); await hub.cargar() }
            } cerrar: { nueva = false }
        }
        .sheet(item: $formulario) { c in
            CompraFormView(corteId: datos.corte.id, tanques: datos.tanques, compra: c) {
                formulario = nil
                Task { await vm.cargar(); await hub.cargar() }
            } cerrar: { formulario = nil }
        }
    }
}

private struct FilaCompra: View {
    let compra: CompraCombustible
    let combustible: Combustible?
    let editable: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(combustible?.nombre ?? "Combustible").font(.headline).foregroundColor(combustible?.color ?? .primary)
                Text("\(compra.origen == .vaciado ? "Generada por una descarga errónea" : (compra.proveedor ?? "Sin proveedor")) · \(Fechas.hora(compra.creadoEn))")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if !editable {
                Image(systemName: "lock.fill").foregroundColor(.secondary).accessibilityLabel("Generada por un vaciado")
            }
            Text(Formateadores.galones(compra.galones)).font(.headline)
        }
    }
}

struct CompraFormView: View {
    @StateObject private var vm: CompraFormViewModel
    let cerrar: () -> Void

    init(corteId: UUID, tanques: [EstadoTanque], compra: CompraCombustible?, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: CompraFormViewModel(corteId: corteId, tanques: tanques, compra: compra,
                                                            servicio: Servicios.lineas, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: vm.esEdicion ? "Editar compra" : "Nueva compra", cerrar: cerrar) {
            if !vm.esEdicion {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Combustible (tanque)").font(.subheadline).foregroundColor(.secondary)
                    Picker("Combustible", selection: $vm.tanqueId) {
                        ForEach(vm.tanques) { Text($0.combustible.nombre).tag($0.tanqueId) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            CampoNumerico(titulo: "Galones recibidos", texto: $vm.galones, unidad: "gal", error: vm.galones.isEmpty ? nil : vm.errorGalones)
            CampoTexto(titulo: "Proveedor (opcional)", texto: $vm.proveedor, placeholder: "Solo el nombre", capitalizacion: .words,
                       error: vm.errorProveedor)
            Text("Una compra no puede superar el espacio libre del tanque. La fecha y hora se registran solas.")
                .font(.footnote).foregroundColor(.secondary)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) { Task { await vm.guardar() } }
        }
        .onChange(of: vm.galones) { _, _ in vm.limpiarError() }
    }
}

/// 37 · Pérdidas. 38 · Nueva pérdida / edición.
struct PerdidasView: View {
    @ObservedObject var vm: CorteEnCursoViewModel

    var body: some View {
        if let d = vm.datos {
            ContenidoPerdidas(hub: vm, datos: d)
        }
    }
}

private struct ContenidoPerdidas: View {
    @ObservedObject var hub: CorteEnCursoViewModel
    let datos: CorteEnCursoViewModel.Datos
    @StateObject private var vm: PerdidasViewModel
    @State private var formulario: PerdidaCombustible?
    @State private var nueva = false

    init(hub: CorteEnCursoViewModel, datos: CorteEnCursoViewModel.Datos) {
        self.hub = hub
        self.datos = datos
        _vm = StateObject(wrappedValue: PerdidasViewModel(corteId: datos.corte.id, tanques: datos.tanques,
                                                          bombas: datos.infra.bombas, servicio: Servicios.lineas))
    }

    var body: some View {
        List {
            if let e = vm.error { Section { MensajeError(texto: e) } }
            switch vm.estado {
            case .inicial, .cargando:
                ProgressView("Cargando…").frame(maxWidth: .infinity)
            case .error(let m):
                VStack { Text(m).foregroundColor(.gas76Rojo); Button("Reintentar") { Task { await vm.cargar() } } }
            case .listo(let lista):
                if lista.isEmpty { Text("Sin pérdidas registradas.").foregroundColor(.secondary) }
                ForEach(lista) { p in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(vm.combustible(de: p)?.nombre ?? "Combustible").font(.headline)
                                .foregroundColor(vm.combustible(de: p)?.color ?? .primary)
                            Insignia(texto: p.tipo.nombre, color: p.tipo == .contaminacion ? .gas76Rojo : .gas76Orange)
                            Spacer()
                            if !vm.esEditable(p) { Image(systemName: "lock.fill").foregroundColor(.secondary) }
                            Text(Formateadores.galones(p.galones)).font(.headline)
                        }
                        Text(p.nota).font(.subheadline).foregroundColor(.secondary)
                        if let n = vm.numeroBomba(de: p) { Text("Bomba \(n)").font(.caption).foregroundColor(.secondary) }
                    }
                    .swipeActions {
                        if vm.esEditable(p) {
                            Button("Eliminar", role: .destructive) { Task { await vm.eliminar(p); await hub.cargar() } }
                            Button("Editar") { formulario = p }.tint(.gas76Orange)
                        }
                    }
                    .onTapGesture { if vm.esEditable(p) { formulario = p } }
                }
            }
        }
        .navigationTitle("Pérdidas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { nueva = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nueva pérdida")
            }
        }
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
        .sheet(isPresented: $nueva) {
            PerdidaFormView(corteId: datos.corte.id, tanques: datos.tanques, bombas: datos.infra.bombas, perdida: nil) {
                nueva = false
                Task { await vm.cargar(); await hub.cargar() }
            } cerrar: { nueva = false }
        }
        .sheet(item: $formulario) { p in
            PerdidaFormView(corteId: datos.corte.id, tanques: datos.tanques, bombas: datos.infra.bombas, perdida: p) {
                formulario = nil
                Task { await vm.cargar(); await hub.cargar() }
            } cerrar: { formulario = nil }
        }
    }
}

struct PerdidaFormView: View {
    @StateObject private var vm: PerdidaFormViewModel
    let cerrar: () -> Void

    init(corteId: UUID, tanques: [EstadoTanque], bombas: [Bomba], perdida: PerdidaCombustible?,
         alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: PerdidaFormViewModel(corteId: corteId, tanques: tanques, bombas: bombas, perdida: perdida,
                                                             servicio: Servicios.lineas, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: vm.esEdicion ? "Editar pérdida" : "Nueva pérdida", cerrar: cerrar) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tipo").font(.subheadline).foregroundColor(.secondary)
                Picker("Tipo", selection: $vm.tipo) {
                    ForEach(TipoPerdida.manuales) { Text($0.nombre).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            if !vm.esEdicion {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Combustible (tanque)").font(.subheadline).foregroundColor(.secondary)
                    Picker("Combustible", selection: $vm.tanqueId) {
                        ForEach(vm.tanques) { Text($0.combustible.nombre).tag($0.tanqueId) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            CampoNumerico(titulo: "Galones perdidos", texto: $vm.galones, unidad: "gal", error: vm.galones.isEmpty ? nil : vm.errorGalones)
            VStack(alignment: .leading, spacing: 6) {
                TituloConAyuda(titulo: "Bomba (opcional)", ayuda: "Un derrame o una falla ocurre en una bomba; una fuga, en el tanque. Por eso es opcional.")
                    .font(.subheadline).foregroundColor(.secondary)
                Picker("Bomba", selection: $vm.bombaId) {
                    Text("Ninguna (tanque)").tag(UUID?.none)
                    ForEach(vm.bombas) { Text("Bomba \($0.numero)").tag(Optional($0.id)) }
                }
                .tint(.gas76Orange)
            }
            CampoNota(titulo: "Nota", texto: $vm.nota, obligatorio: true, error: vm.nota.isEmpty ? nil : vm.errorNota)
            Text("Una pérdida no puede superar el nivel estimado del tanque. Lo que no se reporta como pérdida aparece como diferencia en el cuadre.")
                .font(.footnote).foregroundColor(.secondary)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) { Task { await vm.guardar() } }
        }
        .onChange(of: vm.galones) { _, _ in vm.limpiarError() }
    }
}
