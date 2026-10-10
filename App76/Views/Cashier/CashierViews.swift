import SwiftUI

/// 60 · Caja del cajero.
struct CajaView: View {
    @StateObject private var vm = CajaViewModel(servicio: Servicios.caja)
    @State private var abriendo = false
    @State private var cobrando = false

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, reintentar: { Task { await vm.cargar() } }) { _ in
                VStack(alignment: .leading, spacing: 16) {
                    if let s = vm.sesion {
                        HStack {
                            Insignia(texto: "Caja abierta", color: .gas76Verde)
                            Text("desde \(Fechas.hora(s.abiertaEn))").font(.caption).foregroundColor(.secondary)
                        }
                        HStack(spacing: 10) {
                            SummaryCard(title: "Fondo inicial", value: Formateadores.dolares(s.fondoInicialUsd), systemImage: "banknote")
                            SummaryCard(title: "Vendido (\(vm.completadas.count) ventas)", value: Formateadores.dolares(vm.totalVendido),
                                        systemImage: "cart.fill", tint: .gas76Verde)
                        }
                        HStack(spacing: 4) {
                            FilaDato(titulo: "Efectivo según tus ventas", valor: Formateadores.dolares(vm.efectivoEsperadoReferencia))
                            AyudaBoton(texto: "Es fondo inicial más tus ventas en efectivo. El cierre oficial compara este esperado con el efectivo que cuentes al cerrar la caja.")
                        }
                        .tarjeta(radio: 12)
                        BotonPrimario(titulo: "Cobrar") { cobrando = true }
                        NavigationLink { CerrarCajaView(sesion: s) { Task { await vm.cargar() } } } label: {
                            Label("Cerrar caja", systemImage: "lock").frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.gas76Blue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .tint(.gas76Blue)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "cart.badge.plus").font(.system(size: 48)).foregroundColor(.gas76Orange)
                            Text("No tienes una caja abierta").font(.headline)
                            Text("Abre tu caja con el efectivo inicial para empezar a cobrar.").font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center)
                            BotonPrimario(titulo: "Abrir caja") { abriendo = true }
                        }
                        .padding().frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Caja")
        .refreshable { await vm.cargar() }
        .onAppear { Task { await vm.cargar() } }
        .sheet(isPresented: $abriendo) {
            AbrirCajaView { abriendo = false; Task { await vm.cargar() } } cerrar: { abriendo = false }
        }
        .fullScreenCover(isPresented: $cobrando) {
            if let s = vm.sesion {
                PosView(sesion: s) { cobrando = false; Task { await vm.cargar() } }
            }
        }
    }
}

/// 61 · Abrir caja (hoja).
struct AbrirCajaView: View {
    @StateObject private var vm: AbrirCajaViewModel
    let cerrar: () -> Void

    init(alAbrir: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: AbrirCajaViewModel(servicio: Servicios.caja, alAbrir: alAbrir))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Abrir caja", cerrar: cerrar) {
            CampoNumerico(titulo: "Fondo inicial (USD)", texto: $vm.fondo, unidad: "USD", error: vm.fondo.isEmpty ? nil : vm.errorFondo)
            Text("Es el efectivo con el que empiezas. Puedes tener una sola caja abierta.").font(.footnote).foregroundColor(.secondary)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Abrir", cargando: vm.guardando, habilitado: vm.errorFondo == nil) { Task { await vm.abrir() } }
        }
        .onChange(of: vm.fondo) { _, _ in vm.limpiarError() }
    }
}

/// 62 · POS: búsqueda, categorías, tarjetas de artículo y barra de cobro.
struct PosView: View {
    let sesion: SesionCaja
    let cerrar: () -> Void
    @StateObject private var vm = PosViewModel(servicio: Servicios.caja)
    @State private var cobrando = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Buscar artículo", text: $vm.busqueda)
                            .padding(10).background(Color.gas76Card).clipShape(RoundedRectangle(cornerRadius: 10))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                chip("Todo", activo: vm.categoria == nil) { vm.categoria = nil }
                                ForEach(vm.categoriasDisponibles) { c in chip(c.nombre, activo: vm.categoria == c) { vm.categoria = c } }
                            }
                        }
                        CargaView(estado: vm.estado, textoVacio: "No hay artículos para vender.", esVacio: { $0.isEmpty },
                                  reintentar: { Task { await vm.cargar() } }) { _ in
                            if vm.filtrados.isEmpty {
                                Text("Ningún artículo coincide con la búsqueda.").foregroundColor(.secondary).padding()
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                                ForEach(vm.filtrados) { a in tarjeta(a) }
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                barraCobro
            }
            .background(Color.gas76Background)
            .navigationTitle("Cobrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button { cerrar() } label: { Image(systemName: "xmark") }.accessibilityLabel("Cerrar") } }
            .task { await vm.cargar() }
            .sheet(isPresented: $cobrando) {
                CobroView(sesionId: sesion.id, total: vm.total, lineas: vm.lineas) { nueva in
                    cobrando = false
                    if nueva { vm.vaciar() }
                    Task { await vm.cargar() }
                }
                .interactiveDismissDisabled()
            }
        }
    }

    private func chip(_ texto: String, activo: Bool, _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(texto).font(.subheadline).padding(.horizontal, 12).padding(.vertical, 6)
                .background(activo ? Color.gas76Orange : Color.gas76Card).foregroundColor(activo ? .white : .primary).clipShape(Capsule())
        }
    }

    private func tarjeta(_ a: ArticuloPOS) -> some View {
        let n = vm.cantidad(de: a)
        return VStack(alignment: .leading, spacing: 6) {
            Text(a.articulo.nombre).font(.headline).foregroundColor(.gas76Blue).lineLimit(2)
            Text(Formateadores.dolares(a.articulo.precioUsd)).font(.title3.bold())
            if let s = a.stock { Text(s > 0 ? "Stock: \(s)" : "Sin stock").font(.caption).foregroundColor(s > 0 ? .secondary : .gas76Rojo) }
            else { Text("Servicio").font(.caption).foregroundColor(.secondary) }
            if n > 0 {
                HStack {
                    Button { vm.cambiar(a, delta: -1) } label: { Image(systemName: "minus.circle.fill") }.accessibilityLabel("Quitar uno")
                    Text("\(n)").font(.headline).frame(minWidth: 28)
                    Button { vm.cambiar(a, delta: 1) } label: { Image(systemName: "plus.circle.fill") }.accessibilityLabel("Agregar uno")
                        .disabled(a.stock.map { n >= $0 } ?? false)
                }
                .font(.title2).tint(.gas76Orange)
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(n > 0 ? Color.gas76Orange.opacity(0.12) : Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(n > 0 ? Color.gas76Orange : Color.clear, lineWidth: 1.5))
        .opacity(a.disponible ? 1 : 0.45)
        .contentShape(Rectangle())
        .onTapGesture { if n == 0 { vm.agregar(a) } }
    }

    private var barraCobro: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(vm.unidades) \(vm.unidades == 1 ? "artículo" : "artículos")").foregroundColor(.secondary)
                Spacer()
                Text(Formateadores.dolares(vm.total)).font(.title2.bold()).foregroundColor(.gas76Blue)
            }
            HStack(spacing: 10) {
                if !vm.carritoVacio { Button("Vaciar", role: .destructive) { vm.vaciar() }.buttonStyle(.bordered) }
                BotonPrimario(titulo: "Cobrar", habilitado: !vm.carritoVacio) { cobrando = true }
            }
        }
        .padding()
        .background(.thinMaterial)
    }
}

/// 63 · Cobro → 64 · Animación de pago simulado → 65 · Ticket.
struct CobroView: View {
    @StateObject private var vm: CobroViewModel
    let terminar: (_ nuevaVenta: Bool) -> Void

    init(sesionId: UUID, total: Decimal, lineas: [PosViewModel.LineaCarrito], terminar: @escaping (Bool) -> Void) {
        _vm = StateObject(wrappedValue: CobroViewModel(sesionId: sesionId, total: total, lineas: lineas, servicio: Servicios.caja))
        self.terminar = terminar
    }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.fase {
                case .editando: formulario
                case .pagando: PagoSimuladoView()
                case .exito(let r): TicketView(resultado: r, lineas: vm.lineas, metodo: vm.metodo) { terminar(true) }
                }
            }
            .background(Color.gas76Background)
            .navigationTitle("Cobro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.fase == .editando {
                    ToolbarItem(placement: .topBarLeading) { Button { terminar(false) } label: { Image(systemName: "xmark") }.accessibilityLabel("Cerrar") }
                }
            }
        }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 4) {
                    Text("Total a cobrar").foregroundColor(.secondary)
                    Text(Formateadores.dolares(vm.total)).font(.system(size: 44, weight: .bold)).foregroundColor(.gas76Blue)
                }
                .frame(maxWidth: .infinity)
                Picker("Método", selection: $vm.metodo) { ForEach(MetodoPago.allCases) { Text($0.nombre).tag($0) } }.pickerStyle(.segmented)
                if vm.metodo == .efectivo {
                    CampoNumerico(titulo: "Monto recibido", texto: $vm.recibido, unidad: "USD")
                    Button("Pago exacto (\(Formateadores.dolares(vm.total)))") { vm.pagarExacto() }.font(.subheadline).tint(.gas76Orange)
                    if let v = vm.vueltoPrevio {
                        FilaDato(titulo: "Vuelto", valor: Formateadores.dolares(v), destacado: true, color: .gas76Verde)
                            .tarjeta(radio: 12)
                    } else if let f = vm.faltante {
                        Text("Faltan \(Formateadores.dolares(f)) para cubrir el total.").font(.callout).foregroundColor(.gas76Rojo)
                    }
                } else {
                    Text("Pago con tarjeta simulado: no se pide ningún dato de tarjeta ni se procesa un pago real.")
                        .font(.callout).foregroundColor(.secondary)
                }
                MensajeError(texto: vm.error)
                BotonPrimario(titulo: "Pagar", habilitado: vm.puedePagar) { Task { await vm.pagar() } }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: vm.recibido) { _, _ in vm.limpiarError() }
    }
}

/// 64 · Animación que SIMULA el cobro (no se procesa ningún pago real).
struct PagoSimuladoView: View {
    @State private var girando = false
    @State private var pulso = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().stroke(Color.gas76Orange.opacity(0.25), lineWidth: 8).frame(width: 140, height: 140)
                Circle().trim(from: 0, to: 0.28).stroke(Color.gas76Orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 140, height: 140).rotationEffect(.degrees(girando ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: girando)
                Image(systemName: "creditcard.fill").font(.system(size: 48)).foregroundColor(.gas76Blue)
                    .scaleEffect(pulso ? 1.08 : 0.94)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulso)
            }
            Text("Procesando el pago…").font(.title3.bold()).foregroundColor(.gas76Blue)
            Text("Pago simulado: no se procesa ningún pago real.").font(.footnote).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { girando = true; pulso = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Procesando el pago simulado")
    }
}

/// 65 · Ticket con lo que registró el servidor.
struct TicketView: View {
    let resultado: ResultadoVenta
    let lineas: [PosViewModel.LineaCarrito]
    let metodo: MetodoPago
    let nuevaVenta: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundColor(.gas76Verde)
                Text("Venta registrada").font(.title2.bold()).foregroundColor(.gas76Blue)
                Text("Ticket n.º \(resultado.numero)").foregroundColor(.secondary)
                VStack(spacing: 8) {
                    ForEach(lineas) { l in
                        HStack {
                            Text("\(l.cantidad) × \(l.articulo.articulo.nombre)").font(.subheadline)
                            Spacer()
                            Text(Formateadores.dolares(l.subtotal)).font(.subheadline)
                        }
                    }
                    Divider()
                    FilaDato(titulo: "Total", valor: Formateadores.dolares(resultado.totalUsd), destacado: true)
                    FilaDato(titulo: "Método", valor: metodo.nombre)
                    if let r = resultado.recibidoUsd { FilaDato(titulo: "Recibido", valor: Formateadores.dolares(r)) }
                    if let v = resultado.vueltoUsd { FilaDato(titulo: "Vuelto", valor: Formateadores.dolares(v), destacado: true, color: .gas76Verde) }
                }
                .tarjeta()
                Text("Pago simulado.").font(.footnote).foregroundColor(.secondary)
                BotonPrimario(titulo: "Nueva venta", cargando: false, habilitado: true, tint: .gas76Orange, accion: nuevaVenta)
            }
            .padding()
        }
    }
}

/// 66 · Mis ventas de la caja abierta (solo lectura).
struct MisVentasView: View {
    @StateObject private var vm = MisVentasViewModel(servicio: Servicios.caja)
    @State private var detalle: Venta?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                CargaView(estado: vm.estado, textoVacio: "Aún no tienes ventas en esta caja.", iconoVacio: "receipt",
                          esVacio: { $0.ventas.isEmpty }, reintentar: { Task { await vm.cargar() } }) { d in
                    LazyVStack(spacing: 10) {
                        ForEach(d.ventas) { v in
                            Button { detalle = v } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text("Ticket n.º \(v.numero)").font(.headline).foregroundColor(.gas76Blue)
                                            if v.estado == .anulada { Insignia(texto: "Anulada", color: .gas76Rojo) }
                                        }
                                        Text("\(v.metodoPago == .efectivo ? "Efectivo" : "Tarjeta") · \(Fechas.hora(v.creadoEn))").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(Formateadores.dolares(v.totalUsd)).font(.headline).strikethrough(v.estado == .anulada)
                                }
                                .tarjeta()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Pide al Gerente de Sucursal que anule una venta.").font(.footnote).foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle("Mis ventas")
        .refreshable { await vm.cargar() }
        .onAppear { Task { await vm.cargar() } }
        .sheet(item: $detalle) { v in
            HojaFormulario(titulo: "Ticket n.º \(v.numero)", cerrar: { detalle = nil }) {
                CargaView(estado: vm.lineas, reintentar: { Task { await vm.cargarLineas(de: v) } }) { lineas in
                    VStack(spacing: 8) {
                        ForEach(lineas) { l in
                            HStack {
                                Text("\(l.cantidad) × \(vm.nombre(de: l.articuloId))").font(.subheadline)
                                Spacer()
                                Text(Formateadores.dolares(l.subtotalUsd)).font(.subheadline)
                            }
                        }
                        Divider()
                        FilaDato(titulo: "Total", valor: Formateadores.dolares(v.totalUsd), destacado: true)
                        if let r = v.recibidoUsd { FilaDato(titulo: "Recibido", valor: Formateadores.dolares(r)) }
                        if let c = v.vueltoUsd { FilaDato(titulo: "Vuelto", valor: Formateadores.dolares(c)) }
                        if v.estado == .anulada, let m = v.motivoAnulacion { Text("Anulada: \(m)").font(.callout).foregroundColor(.gas76Rojo) }
                    }
                }
            }
            .task { await vm.cargarLineas(de: v) }
        }
    }
}

/// 67 · Cerrar caja.
struct CerrarCajaView: View {
    @StateObject private var vm: CerrarCajaViewModel
    @State private var confirmando = false
    @Environment(\.dismiss) private var dismiss

    init(sesion: SesionCaja, alCerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: CerrarCajaViewModel(sesion: sesion, servicio: Servicios.caja, alCerrar: alCerrar))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let r = vm.resultado {
                    ResultadoCajaView(resultado: r)
                    BotonPrimario(titulo: "Listo", cargando: false, habilitado: true) { dismiss() }
                } else {
                    resumenDeCaja

                    Text("Cuenta el efectivo que hay en tu caja y escríbelo.")
                        .foregroundColor(.secondary)

                    CampoNumerico(
                        titulo: "Efectivo contado (USD)",
                        texto: $vm.contado,
                        unidad: "USD",
                        error: vm.contado.isEmpty ? nil : vm.errorContado
                    )
                    .onChange(of: vm.contado) { _, _ in vm.limpiarError() }

                    Text("Después de cerrar no se pueden anular ventas de esta caja.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    MensajeError(texto: vm.error)

                    BotonPrimario(
                        titulo: "Cerrar caja",
                        cargando: vm.cerrando,
                        habilitado: vm.esValido
                    ) {
                        confirmando = true
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gas76Background)
        .navigationTitle("Cerrar caja")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(vm.resultado != nil)
        .task { await vm.cargar() }
        .refreshable { await vm.cargar() }
        .alert("Confirmar cierre de caja", isPresented: $confirmando) {
            Button("Volver", role: .cancel) {}
            Button("Confirmar cierre", role: (vm.diferencia ?? 0) < 0 ? .destructive : .none) {
                Task { await vm.cerrar() }
            }
        } message: {
            Text(vm.mensajeConfirmacion)
        }
    }

    @ViewBuilder
    private var resumenDeCaja: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Resumen de caja")
                    .font(.headline)
                Spacer()
                if vm.cargandoEsperado {
                    ProgressView()
                        .controlSize(.small)
                } else if vm.efectivoEsperado != nil {
                    Text("Estimación previa")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let esperado = vm.efectivoEsperado {
                VStack(spacing: 8) {
                    FilaDato(titulo: "Efectivo esperado", valor: Formateadores.dolares(esperado))
                    FilaDato(
                        titulo: "Efectivo contado",
                        valor: vm.efectivoContado != nil ? Formateadores.dolares(vm.efectivoContado!) : "—"
                    )
                    Divider()

                    if let diff = vm.diferencia, let estado = vm.estadoDiferencia {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: estado.nombreIcono)
                                    .foregroundColor(color(para: estado))
                                Text("Diferencia")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(Formateadores.dolaresConSigno(diff)) — \(estado.titulo)")
                                .fontWeight(.semibold)
                                .foregroundColor(color(para: estado))
                        }
                        .font(.subheadline)
                    } else {
                        FilaDato(titulo: "Diferencia", valor: "Escribe el efectivo contado")
                    }
                }
                .tarjeta(radio: 12)

                Text("La diferencia previa es una estimación de referencia. El arqueo oficial lo determina el servidor.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if vm.cargandoEsperado {
                HStack {
                    Spacer()
                    ProgressView("Calculando efectivo esperado…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .tarjeta(radio: 12)
            } else if let err = vm.errorCargaEsperado {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.gas76Orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No se pudo obtener el efectivo esperado previo (\(err)).")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button("Reintentar") {
                            Task { await vm.cargar() }
                        }
                        .font(.footnote.bold())
                    }
                    Spacer()
                }
                .tarjeta(radio: 12)
            }
        }
    }

    private func color(para estado: CerrarCajaViewModel.EstadoDiferencia) -> Color {
        switch estado {
        case .cuadrado: return .gas76Verde
        case .faltante: return .gas76Rojo
        case .sobrante: return .gas76Orange
        }
    }
}
