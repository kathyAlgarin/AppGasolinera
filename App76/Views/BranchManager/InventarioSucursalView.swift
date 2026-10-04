import SwiftUI

/// 46–50 · Tienda del Gerente de Sucursal: Inventario, Ventas del corte y Cajas.
struct InventarioSucursalView: View {
    let perfil: Perfil
    let corteId: UUID?
    @StateObject private var vm: TiendaGerenteViewModel
    @State private var seccion: Seccion = .inventario
    @State private var hoja: Hoja?

    enum Seccion: String, CaseIterable, Identifiable {
        case inventario = "Inventario", ventas = "Ventas", cajas = "Cajas"
        var id: String { rawValue }
    }

    enum Hoja: Identifiable {
        case entrada(UUID?), baja(UUID?), minimo(TiendaGerenteViewModel.FilaInventario), anular(Venta), forzado(CajaDelCorte)
        var id: String {
            switch self {
            case .entrada: return "entrada"
            case .baja: return "baja"
            case .minimo(let f): return "minimo-\(f.id)"
            case .anular(let v): return "anular-\(v.id)"
            case .forzado(let c): return "forzado-\(c.id)"
            }
        }
    }

    init(perfil: Perfil, corteId: UUID?) {
        self.perfil = perfil
        self.corteId = corteId
        _vm = StateObject(wrappedValue: TiendaGerenteViewModel(
            sucursalId: perfil.sucursalId ?? UUID(), corte: Servicios.corte, tienda: Servicios.tienda, catalogo: Servicios.catalogo))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Sección", selection: $seccion) { ForEach(Seccion.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                MensajeError(texto: vm.error)
                CargaView(estado: vm.estado, reintentar: { Task { await vm.cargar() } }) { d in
                    switch seccion {
                    case .inventario: inventario(d)
                    case .ventas: ventas
                    case .cajas: cajas
                    }
                }
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle("Tienda")
        .refreshable { await vm.cargar() }
        .onAppear { Task { await vm.cargar() } }
        .sheet(item: $hoja) { h in hojaContenido(h) }
    }

    // MARK: Inventario

    @ViewBuilder private func inventario(_ d: TiendaGerenteViewModel.Datos) -> some View {
        HStack(spacing: 10) {
            Button { hoja = .entrada(nil) } label: { Label("Entrada", systemImage: "arrow.down.circle").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(.gas76Orange)
            Button { hoja = .baja(nil) } label: { Label("Baja", systemImage: "arrow.up.circle").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered).tint(.gas76Orange)
        }
        .disabled(vm.productos.isEmpty)

        if vm.filas.isEmpty {
            Text("No hay productos en el inventario. El Gerente General agrega los artículos al catálogo.")
                .foregroundColor(.secondary).font(.callout)
        }
        ForEach(vm.filas) { f in
            Button { hoja = .minimo(f) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.articulo.nombre).font(.headline).foregroundColor(.gas76Blue)
                        HStack(spacing: 6) {
                            Insignia(texto: f.articulo.categoria.nombre, color: .gas76Blue)
                            if f.stockBajo { Insignia(texto: "Stock bajo", color: .gas76Rojo) }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(f.stock)").font(.title3.bold()).foregroundColor(f.stockBajo ? .gas76Rojo : .primary)
                        Text("mín. \(f.minimo)").font(.caption).foregroundColor(.secondary)
                    }
                }
                .tarjeta()
            }
            .buttonStyle(.plain)
        }
        Text("Toca un producto para fijar su stock mínimo.").font(.footnote).foregroundColor(.secondary)

        Text("Entradas del corte").font(.headline).foregroundColor(.gas76Blue).padding(.top, 8)
        if d.entradas.isEmpty { Text("Sin entradas en este corte.").foregroundColor(.secondary).font(.callout) }
        ForEach(d.entradas) { e in
            HStack {
                VStack(alignment: .leading) {
                    Text(vm.nombre(de: e.articuloId)).font(.subheadline.bold())
                    Text("\(e.proveedor ?? "Sin proveedor") · \(Fechas.hora(e.creadoEn))").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("+\(e.cantidad)").font(.headline).foregroundColor(.gas76Verde)
                Button(role: .destructive) { Task { await vm.eliminarEntrada(e) } } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Eliminar entrada")
            }
            .tarjeta(radio: 12)
        }

        Text("Bajas del corte").font(.headline).foregroundColor(.gas76Blue).padding(.top, 8)
        if d.bajas.isEmpty { Text("Sin bajas en este corte.").foregroundColor(.secondary).font(.callout) }
        ForEach(d.bajas) { b in
            HStack {
                VStack(alignment: .leading) {
                    Text(vm.nombre(de: b.articuloId)).font(.subheadline.bold())
                    Text("\(b.motivo.nombre)\(b.nota.map { " · \($0)" } ?? "") · \(Fechas.hora(b.creadoEn))").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text("−\(b.cantidad)").font(.headline).foregroundColor(.gas76Rojo)
                Button(role: .destructive) { Task { await vm.eliminarBaja(b) } } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Eliminar baja")
            }
            .tarjeta(radio: 12)
        }
    }

    // MARK: Ventas del corte (49)

    @ViewBuilder private var ventas: some View {
        if vm.ventasDelCorte.isEmpty {
            Text("Aún no hay ventas en este corte.").foregroundColor(.secondary).font(.callout)
        }
        ForEach(vm.ventasDelCorte) { f in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ticket n.º \(f.venta.numero)").font(.headline).foregroundColor(.gas76Blue)
                    if f.venta.estado == .anulada { Insignia(texto: "Anulada", color: .gas76Rojo) }
                    Spacer()
                    Text(Formateadores.dolares(f.venta.totalUsd)).font(.headline)
                }
                Text("\(f.cajero) · \(f.venta.metodoPago == .efectivo ? "Efectivo" : "Tarjeta") · \(Fechas.hora(f.venta.creadoEn))")
                    .font(.caption).foregroundColor(.secondary)
                if let m = f.venta.motivoAnulacion { Text("Motivo: \(m)").font(.caption).foregroundColor(.gas76Rojo) }
                if f.anulable {
                    Button("Anular venta", role: .destructive) { hoja = .anular(f.venta) }.font(.footnote)
                } else if f.venta.estado == .completada {
                    Text("La venta es definitiva.").font(.caption).foregroundColor(.secondary)
                }
            }
            .tarjeta()
        }
    }

    // MARK: Cajas (50)

    @ViewBuilder private var cajas: some View {
        if (vm.datos?.cajas ?? []).isEmpty {
            Text("Aún no hay cajas en este corte.").foregroundColor(.secondary).font(.callout)
        }
        ForEach(vm.datos?.cajas ?? []) { c in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(c.cajeroNombre).font(.headline).foregroundColor(.gas76Blue)
                    Insignia(texto: c.sesion.estaAbierta ? "Abierta" : "Cerrada", color: c.sesion.estaAbierta ? .gas76Verde : .gas76Gris)
                    if c.sesion.cierreForzado { Insignia(texto: "Forzado", color: .gas76Orange) }
                }
                FilaDato(titulo: "Fondo inicial", valor: Formateadores.dolares(c.sesion.fondoInicialUsd))
                if let e = c.sesion.efectivoEsperadoUsd { FilaDato(titulo: "Esperado", valor: Formateadores.dolares(e)) }
                if let k = c.sesion.efectivoContadoUsd { FilaDato(titulo: "Contado", valor: Formateadores.dolares(k)) }
                if let df = c.sesion.diferenciaUsd {
                    FilaDato(titulo: df < 0 ? "Faltante" : (df > 0 ? "Sobrante" : "Diferencia"), valor: Formateadores.dolaresConSigno(df), destacado: true,
                             color: df == 0 ? .gas76Verde : .gas76Orange)
                }
                if let m = c.sesion.motivoCierreForzado { Text("Motivo: \(m)").font(.caption).foregroundColor(.secondary) }
                if c.sesion.estaAbierta {
                    Button("Cierre forzado") { hoja = .forzado(c) }.font(.footnote).tint(.gas76Rojo)
                }
            }
            .tarjeta()
        }
    }

    // MARK: Hojas

    @ViewBuilder private func hojaContenido(_ h: Hoja) -> some View {
        if let d = vm.datos {
            switch h {
            case .entrada(let id):
                EntradaFormView(corteId: d.corte.id, productos: vm.productos, articulo: id) { hoja = nil; Task { await vm.cargar() } } cerrar: { hoja = nil }
            case .baja(let id):
                BajaFormView(corteId: d.corte.id, filas: vm.filas, articulo: id) { hoja = nil; Task { await vm.cargar() } } cerrar: { hoja = nil }
            case .minimo(let f):
                StockMinimoView(fila: f) { hoja = nil; Task { await vm.cargar() } } cerrar: { hoja = nil }
            case .anular(let v):
                AnularVentaView(venta: v) { hoja = nil; Task { await vm.cargar() } } cerrar: { hoja = nil }
            case .forzado(let c):
                CierreForzadoView(caja: c) { Task { await vm.cargar() } } cerrar: { hoja = nil }
            }
        }
    }
}

struct EntradaFormView: View {
    @StateObject private var vm: EntradaFormViewModel
    let cerrar: () -> Void

    init(corteId: UUID, productos: [Articulo], articulo: UUID?, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: EntradaFormViewModel(corteId: corteId, productos: productos, articuloInicial: articulo,
                                                             servicio: Servicios.tienda, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Entrada de mercadería", cerrar: cerrar) {
            Picker("Producto", selection: $vm.articuloId) { ForEach(vm.productos) { Text($0.nombre).tag($0.id) } }.tint(.gas76Orange)
            CampoNumerico(titulo: "Cantidad", texto: $vm.cantidad, entero: true, error: vm.cantidad.isEmpty ? nil : vm.errorCantidad)
            CampoTexto(titulo: "Proveedor (opcional)", texto: $vm.proveedor, capitalizacion: .words, error: vm.errorProveedor)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) { Task { await vm.guardar() } }
        }
        .onChange(of: vm.cantidad) { _, _ in vm.limpiarError() }
    }
}

struct BajaFormView: View {
    @StateObject private var vm: BajaFormViewModel
    let cerrar: () -> Void

    init(corteId: UUID, filas: [TiendaGerenteViewModel.FilaInventario], articulo: UUID?, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: BajaFormViewModel(corteId: corteId, filas: filas, articuloInicial: articulo, servicio: Servicios.tienda, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Baja de mercadería", cerrar: cerrar) {
            Picker("Producto", selection: $vm.articuloId) { ForEach(vm.filas) { Text("\($0.articulo.nombre) (stock \($0.stock))").tag($0.id) } }.tint(.gas76Orange)
            CampoNumerico(titulo: "Cantidad", texto: $vm.cantidad, entero: true, error: vm.cantidad.isEmpty ? nil : vm.errorCantidad)
            Picker("Motivo", selection: $vm.motivo) { ForEach(MotivoBaja.allCases) { Text($0.nombre).tag($0) } }.pickerStyle(.segmented)
            CampoNota(titulo: "Nota", texto: $vm.nota, obligatorio: vm.motivo == .otro, error: vm.nota.isEmpty && vm.motivo != .otro ? nil : vm.errorNota)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.esValido) { Task { await vm.guardar() } }
        }
        .onChange(of: vm.cantidad) { _, _ in vm.limpiarError() }
    }
}

struct StockMinimoView: View {
    @StateObject private var vm: StockMinimoViewModel
    let cerrar: () -> Void

    init(fila: TiendaGerenteViewModel.FilaInventario, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: StockMinimoViewModel(fila: fila, servicio: Servicios.tienda, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Stock mínimo", cerrar: cerrar) {
            Text(vm.fila.articulo.nombre).font(.headline)
            FilaDato(titulo: "Stock actual", valor: "\(vm.fila.stock)")
            CampoNumerico(titulo: "Stock mínimo", texto: $vm.minimo, entero: true, error: vm.errorMinimo)
            Text("Cuando el stock llega al mínimo, el producto aparece con «Stock bajo».").font(.footnote).foregroundColor(.secondary)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.errorMinimo == nil) { Task { await vm.guardar() } }
        }
    }
}

struct AnularVentaView: View {
    @StateObject private var vm: AnularVentaViewModel
    let cerrar: () -> Void
    @State private var confirmando = false

    init(venta: Venta, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: AnularVentaViewModel(venta: venta, servicio: Servicios.tienda, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Anular venta", cerrar: cerrar) {
            Text("Ticket n.º \(vm.venta.numero) · \(Formateadores.dolares(vm.venta.totalUsd))").font(.headline)
            Text("La venta se conserva marcada como «Anulada». Se devuelve el stock y se excluye del efectivo esperado de la caja.")
                .font(.callout).foregroundColor(.secondary)
            CampoNota(titulo: "Motivo", texto: $vm.motivo, obligatorio: true, error: vm.motivo.isEmpty ? nil : vm.errorMotivo)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Anular venta", cargando: vm.guardando, habilitado: vm.esValido, tint: .gas76Rojo) { confirmando = true }
        }
        .onChange(of: vm.motivo) { _, _ in vm.limpiarError() }
        .alert("¿Anular esta venta?", isPresented: $confirmando) {
            Button("Cancelar", role: .cancel) {}
            Button("Anular", role: .destructive) { Task { await vm.anular() } }
        }
    }
}

struct CierreForzadoView: View {
    @StateObject private var vm: CierreForzadoViewModel
    let cerrar: () -> Void
    @State private var confirmando = false

    init(caja: CajaDelCorte, alCerrar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: CierreForzadoViewModel(caja: caja, servicio: Servicios.tienda, alCerrar: alCerrar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Cierre forzado de caja", cerrar: cerrar) {
            if let r = vm.resultado {
                ResultadoCajaView(resultado: r)
                BotonPrimario(titulo: "Listo", cargando: false, habilitado: true) { cerrar() }
            } else {
                Text("Caja de \(vm.caja.cajeroNombre). Cuenta tú el efectivo y deja el motivo: quedará marcada como «cierre forzado».")
                    .font(.callout).foregroundColor(.secondary)
                CampoNumerico(titulo: "Efectivo contado", texto: $vm.contado, unidad: "USD", error: vm.contado.isEmpty ? nil : vm.errorContado)
                CampoNota(titulo: "Motivo", texto: $vm.motivo, obligatorio: true, error: vm.motivo.isEmpty ? nil : vm.errorMotivo)
                MensajeError(texto: vm.error)
                BotonPrimario(titulo: "Cerrar caja", cargando: vm.guardando, habilitado: vm.esValido, tint: .gas76Rojo) { confirmando = true }
            }
        }
        .onChange(of: vm.motivo) { _, _ in vm.limpiarError() }
        .alert("¿Cerrar esta caja?", isPresented: $confirmando) {
            Button("Cancelar", role: .cancel) {}
            Button("Cerrar caja", role: .destructive) { Task { await vm.cerrar() } }
        } message: { Text("Después de cerrarla no se pueden anular sus ventas.") }
    }
}

/// Esperado, contado y diferencia (faltante o sobrante) que devuelve el servidor al cerrar una caja.
struct ResultadoCajaView: View {
    let resultado: ResultadoCierreCaja
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: resultado.diferenciaUsd == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 48)).foregroundColor(resultado.diferenciaUsd == 0 ? .gas76Verde : .gas76Orange)
            Text("Caja cerrada").font(.title3.bold())
            VStack(spacing: 6) {
                FilaDato(titulo: "Efectivo esperado", valor: Formateadores.dolares(resultado.esperadoUsd))
                FilaDato(titulo: "Efectivo contado", valor: Formateadores.dolares(resultado.contadoUsd))
                Divider()
                FilaDato(titulo: resultado.diferenciaUsd < 0 ? "Faltante" : (resultado.diferenciaUsd > 0 ? "Sobrante" : "Diferencia"),
                         valor: Formateadores.dolaresConSigno(resultado.diferenciaUsd), destacado: true,
                         color: resultado.diferenciaUsd == 0 ? .gas76Verde : .gas76Orange)
            }
            .tarjeta(radio: 12)
            Text("La diferencia es solo un indicador.").font(.footnote).foregroundColor(.secondary)
        }
    }
}
