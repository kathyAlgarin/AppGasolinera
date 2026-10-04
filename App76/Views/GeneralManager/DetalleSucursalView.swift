import SwiftUI

/// 12 · Detalle de sucursal (solo consulta): lo mismo que ve su gerente, más el gerente asignado y los precios.
struct DetalleSucursalView: View {
    let sucursal: Sucursal
    @StateObject private var vm: DetalleSucursalViewModel

    init(sucursal: Sucursal) {
        self.sucursal = sucursal
        _vm = StateObject(wrappedValue: DetalleSucursalViewModel(
            sucursal: sucursal, usuarios: Servicios.usuarios, tanques: Servicios.tanques, reportes: Servicios.reportes,
            precios: Servicios.precios, sucursales: Servicios.sucursales))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sucursal.direccion).foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        if !sucursal.activa { Insignia(texto: "Inactiva", color: .gas76Gris) }
                        if sucursal.tieneTienda { Insignia(texto: "Con tienda", color: .gas76Blue) }
                    }
                }
                CargaView(estado: vm.estado, reintentar: { Task { await vm.cargar() } }) { d in
                    VStack(alignment: .leading, spacing: 16) {
                        bloque("Gerente asignado") {
                            if let g = d.gerente {
                                FilaDato(titulo: g.nombre, valor: g.correo)
                            } else {
                                Text("Esta sucursal no tiene un Gerente de Sucursal activo.").foregroundColor(.secondary)
                            }
                        }
                        Text("Tanques").font(.headline).foregroundColor(.gas76Blue)
                        ForEach(d.tanques) { TanqueRowView(tanque: $0) }

                        bloque("Precios vigentes") {
                            ForEach(Combustible.allCases) { c in
                                FilaDato(titulo: c.nombre, valor: d.preciosVigentes[c].map { "\(Formateadores.dolares($0.precioGal))/gal" } ?? "Sin precio",
                                         color: d.preciosVigentes[c] == nil ? .gas76Rojo : nil)
                            }
                        }

                        bloque("Cortes recientes") {
                            if d.cortes.isEmpty { Text("Aún no hay cortes cerrados.").foregroundColor(.secondary) }
                            ForEach(d.cortes) { c in
                                NavigationLink { ReporteCorteView(corte: c, esGerenteGeneral: true) } label: {
                                    HStack {
                                        Text("\(c.tipo?.nombre ?? "Corte") · \(Fechas.dia(c.fechaOperativa ?? ""))").foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary)
                                    }
                                }
                            }
                            NavigationLink { HistorialCortesView(sucursalId: sucursal.id, esGerenteGeneral: true) } label: {
                                Text("Ver historial completo").font(.subheadline)
                            }
                            .tint(.gas76Orange)
                        }

                        bloque("Pérdidas registradas") {
                            if d.perdidas.isEmpty { Text("Sin pérdidas registradas").foregroundColor(.secondary) }
                            ForEach(d.perdidas) { p in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(vm.combustible(de: p)?.nombre ?? "Combustible").font(.subheadline.bold())
                                        Insignia(texto: p.tipo.nombre, color: p.tipo == .contaminacion ? .gas76Rojo : .gas76Orange)
                                        Spacer()
                                        Text(Formateadores.galones(p.galones)).font(.subheadline)
                                    }
                                    Text("\(p.nota) · \(Fechas.fechaHora(p.creadoEn))").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }

                        PersonalSucursalResumenView(sucursal: sucursal)
                        if sucursal.tieneTienda { TiendaSucursalResumenView(sucursal: sucursal) }
                    }
                }
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle(sucursal.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
    }

    private func bloque<C: View>(_ titulo: String, @ViewBuilder _ contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo).font(.headline).foregroundColor(.gas76Blue)
            contenido()
        }
        .tarjeta()
    }
}

/// 26 · Pérdidas y contaminaciones de todas las sucursales.
struct PerdidasGlobalesView: View {
    @StateObject private var vm = PerdidasGlobalesViewModel(reportes: Servicios.reportes, sucursales: Servicios.sucursales)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SelectorSucursal(sucursales: vm.estado.valor?.sucursales ?? [], seleccion: $vm.sucursalId)
                    HStack {
                        Text("Tipo").foregroundColor(.secondary)
                        Spacer()
                        Picker("Tipo", selection: $vm.tipo) {
                            Text("Todos los tipos").tag(TipoPerdida?.none)
                            ForEach(TipoPerdida.allCases) { Text($0.nombre).tag(Optional($0)) }
                        }
                    }
                    .tint(.gas76Orange).font(.subheadline)
                    Toggle("Filtrar por fechas", isOn: $vm.usarFechas).tint(.gas76Orange).font(.subheadline)
                    if vm.usarFechas {
                        HStack {
                            DatePicker("Desde", selection: $vm.desde, in: ...Date(), displayedComponents: .date)
                            DatePicker("Hasta", selection: $vm.hasta, in: ...Date(), displayedComponents: .date)
                        }
                        .labelsHidden()
                    }
                }
                CargaView(estado: vm.estado, textoVacio: "Sin pérdidas registradas", iconoVacio: "checkmark.seal",
                          esVacio: { $0.perdidas.isEmpty }, reintentar: { Task { await vm.cargar() } }) { d in
                    LazyVStack(spacing: 10) {
                        ForEach(d.perdidas) { p in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(vm.nombreSucursal(p.sucursalId)).font(.headline).foregroundColor(.gas76Blue)
                                    Spacer()
                                    Text(Formateadores.galones(p.galones)).font(.headline)
                                }
                                HStack(spacing: 6) {
                                    Text(vm.combustible(de: p)?.nombre ?? "Combustible").font(.subheadline.bold())
                                        .foregroundColor(vm.combustible(de: p)?.color ?? .primary)
                                    Insignia(texto: p.tipo.nombre, color: p.tipo == .contaminacion ? .gas76Rojo : .gas76Orange)
                                }
                                Text("\(p.nota) · \(Fechas.fechaHora(p.creadoEn))").font(.caption).foregroundColor(.secondary)
                            }
                            .tarjeta()
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle("Pérdidas y contaminaciones")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
        .onChange(of: vm.sucursalId) { _, _ in Task { await vm.cargar() } }
        .onChange(of: vm.tipo) { _, _ in Task { await vm.cargar() } }
        .onChange(of: vm.usarFechas) { _, _ in Task { await vm.cargar() } }
        .onChange(of: vm.desde) { _, _ in if vm.usarFechas { Task { await vm.cargar() } } }
        .onChange(of: vm.hasta) { _, _ in if vm.usarFechas { Task { await vm.cargar() } } }
    }
}
