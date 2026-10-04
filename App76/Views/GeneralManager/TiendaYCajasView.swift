import SwiftUI

/// 28 · Tienda y cajas (Gerente General, solo consulta).
struct TiendaYCajasView: View {
    @StateObject private var vm = TiendaYCajasViewModel(dashboard: Servicios.dashboard, sucursales: Servicios.sucursales)
    @State private var seccion: Seccion = .cierres

    enum Seccion: String, CaseIterable, Identifiable {
        case cierres = "Cierres de caja", anulaciones = "Anulaciones", stock = "Stock bajo"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SelectorSucursal(sucursales: vm.estado.valor?.sucursales ?? [], seleccion: $vm.sucursalId)
                Picker("Periodo", selection: $vm.periodo) { ForEach(PeriodoFiltro.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                if vm.periodo == .personalizado {
                    HStack {
                        DatePicker("Desde", selection: $vm.desdePersonalizado, in: ...Date(), displayedComponents: .date)
                        DatePicker("Hasta", selection: $vm.hastaPersonalizado, in: ...Date(), displayedComponents: .date)
                    }
                    .labelsHidden()
                }
                CargaView(estado: vm.estado, reintentar: { Task { await vm.cargar() } }) { d in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            SummaryCard(title: "Ingreso de tienda", value: Formateadores.dolares(vm.ingresoTotal), systemImage: "bag.fill", tint: .gas76Verde)
                            SummaryCard(title: "Cajas con diferencia", value: "\(vm.cajasConDiferencia)", systemImage: "exclamationmark.triangle.fill")
                        }
                        Picker("Sección", selection: $seccion) { ForEach(Seccion.allCases) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented)
                        if seccion == .cierres {
                        bloque("Cierres de caja") {
                            if d.cajas.isEmpty { Text("Sin cajas en este periodo.").foregroundColor(.secondary) }
                            ForEach(d.cajas) { c in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(vm.nombreSucursal(c.sucursalId)) · \(c.cajeroNombre)").font(.subheadline.bold())
                                        if c.cierreForzado { Insignia(texto: "Forzado", color: .gas76Orange) }
                                        if c.cerradaEn == nil { Insignia(texto: "Abierta", color: .gas76Verde) }
                                    }
                                    if c.cerradaEn != nil {
                                        FilaDato(titulo: "Fondo / esperado / contado",
                                                 valor: "\(Formateadores.dolares(c.fondoInicialUsd)) / \(Formateadores.dolares(c.efectivoEsperadoUsd ?? 0)) / \(Formateadores.dolares(c.efectivoContadoUsd ?? 0))")
                                        if let df = c.diferenciaUsd {
                                            FilaDato(titulo: df < 0 ? "Faltante" : (df > 0 ? "Sobrante" : "Diferencia"), valor: Formateadores.dolaresConSigno(df),
                                                     color: df == 0 ? .gas76Verde : .gas76Orange)
                                        }
                                    }
                                    Text(Fechas.fechaHora(c.abiertaEn)).font(.caption).foregroundColor(.secondary)
                                }
                                Divider()
                            }
                        }
                        }
                        if seccion == .anulaciones {
                        bloque("Anulaciones por sucursal") {
                            if vm.anulacionesPorSucursal.isEmpty { Text("Sin anulaciones en este periodo.").foregroundColor(.secondary) }
                            ForEach(vm.anulacionesPorSucursal, id: \.sucursal) { a in
                                FilaDato(titulo: a.sucursal, valor: "\(a.ventas) · \(Formateadores.dolares(a.total))")
                            }
                        }
                        }
                        if seccion == .stock {
                        bloque("Productos con stock bajo") {
                            if d.stockBajo.isEmpty { Text("Ningún producto con stock bajo.").foregroundColor(.secondary) }
                            ForEach(d.stockBajo) { s in
                                FilaDato(titulo: "\(vm.nombreSucursal(s.sucursalId)) · \(s.nombre)",
                                         valor: s.stock == 0 ? "Agotado" : "\(s.stock) (mín. \(s.stockMinimo))", color: .gas76Rojo)
                            }
                        }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle("Tienda y cajas")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
        .onChange(of: vm.sucursalId) { _, _ in Task { await vm.cargar() } }
        .onChange(of: vm.periodo) { _, _ in Task { await vm.cargar() } }
        .onChange(of: vm.desdePersonalizado) { _, _ in if vm.periodo == .personalizado { Task { await vm.cargar() } } }
        .onChange(of: vm.hastaPersonalizado) { _, _ in if vm.periodo == .personalizado { Task { await vm.cargar() } } }
    }

    private func bloque<C: View>(_ titulo: String, @ViewBuilder _ contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo).font(.headline).foregroundColor(.gas76Blue)
            contenido()
        }
        .tarjeta()
    }
}

/// Resumen de tienda en el detalle de sucursal (últimos 30 días).
struct TiendaSucursalResumenView: View {
    let sucursal: Sucursal
    @StateObject private var vm: TiendaSucursalResumenViewModel

    init(sucursal: Sucursal) {
        self.sucursal = sucursal
        _vm = StateObject(wrappedValue: TiendaSucursalResumenViewModel(sucursalId: sucursal.id, dashboard: Servicios.dashboard))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tienda y servicios").font(.headline).foregroundColor(.gas76Blue)
            if vm.estado.valor != nil {
                FilaDato(titulo: "Ingreso (30 días)", valor: Formateadores.dolares(vm.ingreso30Dias))
                FilaDato(titulo: "Ventas anuladas (30 días)", valor: "\(vm.anuladas30Dias)")
                FilaDato(titulo: "Cierres de caja con diferencia", valor: "\(vm.cajasConDiferencia)")
                FilaDato(titulo: "Productos con stock bajo", valor: "\(vm.estado.valor?.stockBajo.count ?? 0)")
            } else if let m = vm.estado.mensajeError {
                Text(m).foregroundColor(.gas76Rojo)
            } else {
                ProgressView()
            }
        }
        .tarjeta()
        .task { await vm.cargar() }
    }
}
