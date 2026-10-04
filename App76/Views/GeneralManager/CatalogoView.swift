import SwiftUI

/// 24 · Catálogo de productos y servicios (Gerente General). 25 · Alta y edición de un artículo.
struct CatalogoView: View {
    @StateObject private var vm = CatalogoViewModel(servicio: Servicios.catalogo)
    @State private var creando = false
    @State private var editando: Articulo?

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, textoVacio: "El catálogo está vacío. Toca ＋ para agregar un artículo.",
                      iconoVacio: "shippingbox", esVacio: { $0.isEmpty }, reintentar: { Task { await vm.cargar() } }) { lista in
                LazyVStack(spacing: 10) {
                    ForEach(lista) { a in
                        Button { editando = a } label: { FilaArticulo(articulo: a) }
                            .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Catálogo")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creando = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nuevo artículo")
            }
        }
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
        .sheet(isPresented: $creando) {
            ArticuloFormView(articulo: nil) { creando = false; Task { await vm.cargar() } } cerrar: { creando = false }
        }
        .sheet(item: $editando) { a in
            ArticuloFormView(articulo: a) { editando = nil; Task { await vm.cargar() } } cerrar: { editando = nil }
        }
    }
}

struct FilaArticulo: View {
    let articulo: Articulo
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(articulo.nombre).font(.headline).foregroundColor(.gas76Blue)
                HStack(spacing: 6) {
                    Insignia(texto: articulo.categoria.nombre, color: .gas76Blue)
                    Insignia(texto: articulo.tipo.nombre, color: .gas76Gris)
                    if !articulo.activo { Insignia(texto: "Inactivo", color: .gas76Rojo) }
                }
            }
            Spacer()
            Text(Formateadores.dolares(articulo.precioUsd)).font(.headline)
        }
        .tarjeta()
        .opacity(articulo.activo ? 1 : 0.7)
    }
}

struct ArticuloFormView: View {
    @StateObject private var vm: ArticuloFormViewModel
    let cerrar: () -> Void
    @State private var intentado = false

    init(articulo: Articulo?, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: ArticuloFormViewModel(articulo: articulo, servicio: Servicios.catalogo, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: vm.esEdicion ? "Editar artículo" : "Nuevo artículo", cerrar: cerrar) {
            CampoTexto(titulo: "Nombre", texto: $vm.nombre, capitalizacion: .words,
                       error: (intentado || !vm.nombre.isEmpty) ? vm.errorNombre : nil)
            VStack(alignment: .leading, spacing: 6) {
                Text("Categoría").font(.subheadline).foregroundColor(.secondary)
                Picker("Categoría", selection: $vm.categoria) {
                    ForEach(CategoriaArticulo.allCases) { Text($0.nombre).tag($0) }
                }
                .tint(.gas76Orange)
                .disabled(vm.esEdicion)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Tipo").font(.subheadline).foregroundColor(.secondary)
                Picker("Tipo", selection: $vm.tipo) {
                    ForEach(TipoArticulo.allCases) { Text($0.nombre).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(vm.esEdicion || vm.categoria == .servicios)
                Text("Producto: lleva inventario. Servicio: sin inventario.").font(.caption).foregroundColor(.secondary)
            }
            CampoNumerico(titulo: "Precio de venta (USD)", texto: $vm.precio, unidad: "USD",
                          error: (intentado || !vm.precio.isEmpty) ? vm.errorPrecio : nil)
            Toggle("Activo", isOn: $vm.activo).tint(.gas76Orange)
            if vm.esEdicion {
                Text("Al editar, el tipo y la categoría no cambian. Un artículo se desactiva, nunca se borra.")
                    .font(.footnote).foregroundColor(.secondary)
            }
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) {
                intentado = true
                Task { await vm.guardar() }
            }
        }
    }
}
