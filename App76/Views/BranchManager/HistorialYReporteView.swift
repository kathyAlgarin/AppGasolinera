import SwiftUI

/// 44 · Historial de cortes cerrados (ambos roles).
struct HistorialCortesView: View {
    let sucursalId: UUID?
    let esGerenteGeneral: Bool
    @StateObject private var vm: HistorialCortesViewModel

    init(sucursalId: UUID?, esGerenteGeneral: Bool) {
        self.sucursalId = sucursalId
        self.esGerenteGeneral = esGerenteGeneral
        _vm = StateObject(wrappedValue: HistorialCortesViewModel(sucursalId: sucursalId, servicio: Servicios.reportes))
    }

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, textoVacio: "Aún no hay cortes cerrados.", iconoVacio: "clock.arrow.circlepath",
                      esVacio: { $0.isEmpty }, reintentar: { Task { await vm.cargar() } }) { items in
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink {
                            ReporteCorteView(corte: item.corte, esGerenteGeneral: esGerenteGeneral)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(item.corte.tipo?.nombre ?? "Corte") · \(Fechas.dia(item.corte.fechaOperativa ?? ""))")
                                        .font(.headline).foregroundColor(.gas76Blue)
                                    if let c = item.corte.cerradoEn { Text("Cerrado \(Fechas.fechaHora(c))").font(.caption).foregroundColor(.secondary) }
                                    HStack(spacing: 6) {
                                        if item.ajustado { Insignia(texto: "Ajustado", color: .gas76Blue) }
                                        if item.cambioMedidor { Insignia(texto: "Cambio de medidor", color: .gas76Gris) }
                                        if item.hayDiferencia { Insignia(texto: "Diferencia", color: .gas76Orange) }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary)
                            }
                            .tarjeta()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Historial de cortes")
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
    }
}

/// Abre el reporte a partir del id del corte (tras cerrarlo).
struct ReporteCortePorIdView: View {
    let corteId: UUID
    let esGerenteGeneral: Bool
    @State private var estado: Carga<Corte> = .inicial

    var body: some View {
        Group {
            switch estado {
            case .listo(let corte): ReporteCorteView(corte: corte, esGerenteGeneral: esGerenteGeneral)
            case .error(let m):
                VStack(spacing: 12) { Text(m).foregroundColor(.gas76Rojo); Button("Reintentar") { Task { await cargar() } } }.padding()
            default: ProgressView("Cargando…")
            }
        }
        .task { await cargar() }
    }

    private func cargar() async {
        estado = .cargando
        do { estado = .listo(try await Servicios.reportes.corte(id: corteId)) } catch { estado.registrarFallo(error) }
    }
}

/// 13 · Reporte de un corte cerrado.
struct ReporteCorteView: View {
    @StateObject private var vm: ReporteCorteViewModel
    @State private var ajustando = false

    init(corte: Corte, esGerenteGeneral: Bool) {
        _vm = StateObject(wrappedValue: ReporteCorteViewModel(corte: corte, esGerenteGeneral: esGerenteGeneral, servicio: Servicios.reportes))
    }

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, reintentar: { Task { await vm.cargar() } }) { r in
                VStack(alignment: .leading, spacing: 16) {
                    encabezado(r)
                    seccion("Bombas") {
                        ForEach(vm.bombas, id: \.numero) { b in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bomba \(b.numero)").font(.subheadline.bold())
                                ForEach(b.lecturas) { l in filaLectura(l) }
                            }
                            .tarjeta(radio: 12)
                        }
                    }
                    seccion("Consolidado por combustible") {
                        ForEach(r.resumen.sorted { $0.combustible.orden < $1.combustible.orden }) { f in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(f.combustible.nombre).font(.headline).foregroundColor(f.combustible.color)
                                    Spacer()
                                    Text(Formateadores.dolares(f.ingresoUsd)).font(.headline)
                                }
                                FilaDato(titulo: "Galones vendidos", valor: Formateadores.galones(f.galonesVendidos))
                                FilaDato(titulo: "Compras", valor: Formateadores.galones(f.comprasGal))
                                FilaDato(titulo: "Pérdidas", valor: Formateadores.galones(f.perdidasGal))
                            }
                            .tarjeta(radio: 12)
                        }
                    }
                    seccion("Cuadre (medidor vs tanque)") {
                        ForEach(r.resumen.sorted { $0.combustible.orden < $1.combustible.orden }) { f in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(f.combustible.nombre).font(.headline).foregroundColor(f.combustible.color)
                                    Spacer()
                                    IndicadorCuadre(hayDiferencia: f.hayDiferencia, diferencia: f.diferenciaGal)
                                }
                                FilaDato(titulo: "Nivel inicial", valor: Formateadores.galones(f.nivelInicialGal))
                                FilaDato(titulo: "Nivel teórico", valor: Formateadores.galones(f.nivelTeoricoGal))
                                FilaDato(titulo: "Nivel medido", valor: Formateadores.galones(f.nivelMedidoGal))
                                FilaDato(titulo: "Diferencia", valor: Formateadores.galonesConSigno(f.diferenciaGal), destacado: true,
                                         color: f.hayDiferencia ? .gas76Orange : .gas76Verde)
                            }
                            .tarjeta(radio: 12)
                        }
                    }
                    if !r.compras.isEmpty {
                        seccion("Compras") {
                            ForEach(r.compras) { c in
                                FilaDato(titulo: "\(combustible(c.tanqueId, r)) · \(c.origen == .vaciado ? "Descarga errónea" : (c.proveedor ?? "Sin proveedor"))", valor: Formateadores.galones(c.galones))
                            }
                        }
                    }
                    if !r.perdidas.isEmpty {
                        seccion("Pérdidas") {
                            ForEach(r.perdidas) { p in
                                VStack(alignment: .leading, spacing: 2) {
                                    FilaDato(titulo: "\(combustible(p.tanqueId, r)) · \(p.tipo.nombre)", valor: Formateadores.galones(p.galones))
                                    Text(p.nota).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    if !r.ajustes.isEmpty {
                        seccion("Ajustes") {
                            ForEach(r.ajustes) { a in
                                VStack(alignment: .leading, spacing: 2) {
                                    FilaDato(titulo: "Valor correcto", valor: Formateadores.galones(a.valorCorrectoGal))
                                    Text("\(a.motivo) · \(Fechas.fechaHora(a.creadoEn))").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    if vm.puedeAjustar {
                        BotonPrimario(titulo: "Ajustar lectura") { ajustando = true }
                    } else if vm.esDefinitivo {
                        Text("Este corte es definitivo: el corte siguiente ya se cerró y no admite ajustes.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Reporte del corte")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
        .sheet(isPresented: $ajustando) {
            if let r = vm.reporte {
                AjustarLecturaView(corteId: r.corte.id, lecturas: r.lecturas) {
                    ajustando = false
                    Task { await vm.cargar() }
                } cerrar: { ajustando = false }
            }
        }
    }

    private func encabezado(_ r: ReporteCorte) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(r.sucursalNombre).font(.title3.bold()).foregroundColor(.gas76Blue)
            Text("\(r.corte.tipo?.nombre ?? "Corte") · \(Fechas.dia(r.corte.fechaOperativa ?? ""))").foregroundColor(.secondary)
            if let c = r.corte.cerradoEn {
                Text("Cerrado \(Fechas.fechaHora(c))\(r.cerradoPorNombre.map { " por \($0)" } ?? "")").font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 6) {
                if r.hayAjuste { Insignia(texto: "Ajustado", color: .gas76Blue) }
                if r.hayCambioMedidor { Insignia(texto: "Cambio de medidor", color: .gas76Gris) }
            }
        }
    }

    private func filaLectura(_ l: LecturaEfectiva) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(l.combustible.nombre).font(.caption.bold()).foregroundColor(l.combustible.color)
                if l.ajustada { Insignia(texto: "Ajustada", color: .gas76Blue) }
                if l.cambioMedidor { Insignia(texto: "Cambio de medidor", color: .gas76Gris) }
                Spacer()
                Text("\(Formateadores.galones(l.galones))\(vm.usd(l).map { " · " + Formateadores.dolares($0) } ?? "")").font(.caption.bold())
            }
            Text("Inicial \(l.lecturaInicialGal.map(Formateadores.numeroDosDecimales) ?? "—") → final \(Formateadores.numeroDosDecimales(l.lecturaFinalGal))")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private func combustible(_ tanqueId: UUID, _ r: ReporteCorte) -> String {
        r.resumen.first { $0.tanqueId == tanqueId }?.combustible.nombre ?? "Combustible"
    }

    private func seccion<C: View>(_ titulo: String, @ViewBuilder _ contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titulo).font(.headline).foregroundColor(.gas76Blue)
            contenido()
        }
    }
}

/// 14 · Ajustar lectura (hoja, solo Gerente General).
struct AjustarLecturaView: View {
    @StateObject private var vm: AjustarLecturaViewModel
    let cerrar: () -> Void

    init(corteId: UUID, lecturas: [LecturaEfectiva], alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: AjustarLecturaViewModel(corteId: corteId, lecturas: lecturas, servicio: Servicios.reportes, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Ajustar lectura", cerrar: cerrar) {
            Text("El ajuste se guarda aparte: la lectura original se conserva y el reporte queda marcado como «Ajustado».")
                .font(.callout).foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Manguera").font(.subheadline).foregroundColor(.secondary)
                Picker("Manguera", selection: $vm.mangueraId) {
                    ForEach(vm.lecturas) { Text(vm.etiqueta($0)).tag($0.mangueraId) }
                }
                .tint(.gas76Orange)
                if let l = vm.lecturaElegida {
                    Text("Lectura final actual: \(Formateadores.numeroDosDecimales(l.lecturaFinalGal))").font(.caption).foregroundColor(.secondary)
                }
            }
            CampoNumerico(titulo: "Valor correcto de la lectura final", texto: $vm.valor, unidad: "gal",
                          error: vm.valor.isEmpty ? nil : vm.errorValor)
            CampoNota(titulo: "Motivo", texto: $vm.motivo, obligatorio: true, error: vm.motivo.isEmpty ? nil : vm.errorMotivo)
            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar ajuste", cargando: vm.guardando, habilitado: vm.esValido) { Task { await vm.guardar() } }
        }
        .onChange(of: vm.valor) { _, _ in vm.limpiarError() }
    }
}
