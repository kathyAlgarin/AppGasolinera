import SwiftUI
import Charts

/// 10 · Panel del Gerente General.
struct PanelView: View {
    @StateObject private var vm = PanelViewModel(sucursales: Servicios.sucursales, dashboard: Servicios.dashboard,
                                                 tanques: Servicios.tanques, reportes: Servicios.reportes)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filtros
                CargaView(estado: vm.estado, textoVacio: "No hay datos todavía. Crea una sucursal en la pestaña Sucursales para ver aquí sus ventas, tanques y cortes.",
                          iconoVacio: "building.2", esVacio: { _ in vm.sinSucursales }, reintentar: { Task { await vm.cargar() } }) { _ in
                    VStack(alignment: .leading, spacing: 16) {
                        avisoDeDatos
                        totales
                        tarjetasCombustible
                        tendencia
                        ranking
                        tanquesCriticos
                        sinCorteHoy
                        cortesConDiferencia
                        tienda
                    }
                }
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle("Panel")
        .refreshable { await vm.cargar() }
        .onAppear { Task { await vm.cargar() } }
        .onChange(of: vm.sucursalId) { _, _ in Task { await vm.cargar() } }
        .onChange(of: vm.periodo) { _, _ in Task { await vm.cargar() } }
        .onChange(of: vm.desdePersonalizado) { _, _ in if vm.periodo == .personalizado { Task { await vm.cargar() } } }
        .onChange(of: vm.hastaPersonalizado) { _, _ in if vm.periodo == .personalizado { Task { await vm.cargar() } } }
    }

    // MARK: Filtros

    private var filtros: some View {
        VStack(alignment: .leading, spacing: 10) {
            SelectorSucursal(sucursales: vm.datos?.sucursales ?? [], seleccion: $vm.sucursalId)
            Picker("Periodo", selection: $vm.periodo) {
                ForEach(PanelViewModel.Periodo.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if vm.periodo == .personalizado {
                HStack {
                    DatePicker("Desde", selection: $vm.desdePersonalizado, in: ...Date(), displayedComponents: .date)
                    DatePicker("Hasta", selection: $vm.hastaPersonalizado, in: ...Date(), displayedComponents: .date)
                }
                .labelsHidden()
                .font(.subheadline)
                Text("Del \(Fechas.dia(vm.rango.desde)) al \(Fechas.dia(vm.rango.hasta))").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // MARK: Secciones

    @ViewBuilder private var avisoDeDatos: some View {
        if vm.sinCortesCerrados {
            SinCortesCerradosView(texto: vm.textoSinCortes)
        } else {
            Text("Datos de \(vm.cortesCerrados) de \(vm.cortesEsperados) cortes").font(.caption).foregroundColor(.secondary)
        }
    }

    private var totales: some View {
        HStack(spacing: 10) {
            SummaryCard(title: "Galones vendidos", value: Formateadores.galones(vm.galonesTotales), systemImage: "drop.fill")
            SummaryCard(title: "Ingreso en combustible", value: Formateadores.dolares(vm.ingresoTotal), systemImage: "dollarsign.circle.fill", tint: .gas76Verde)
        }
    }

    private var tarjetasCombustible: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Por combustible").font(.headline).foregroundColor(.gas76Blue)
            ForEach(vm.totales) { t in
                NavigationLink {
                    DetalleCombustibleView(vm: vm, combustible: t.combustible)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(t.combustible.nombre, systemImage: "fuelpump.fill").font(.headline).foregroundColor(t.combustible.color)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary)
                        }
                        HStack {
                            DatoCorto(valor: Formateadores.galones(t.galones), titulo: "Vendido")
                            DatoCorto(valor: Formateadores.dolares(t.ingreso), titulo: "Ingreso")
                        }
                        HStack {
                            DatoCorto(valor: Formateadores.galones(t.compras), titulo: "Compras")
                            DatoCorto(valor: Formateadores.galones(t.perdidas), titulo: "Pérdidas")
                        }
                    }
                    .tarjeta()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tendencia: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tendencia de galones vendidos").font(.headline).foregroundColor(.gas76Blue)
            let puntos = vm.tendencia
            if vm.sinCortesCerrados {
                Text("Aún no hay datos para graficar.").font(.callout).foregroundColor(.secondary)
            } else {
                Chart(puntos) { p in
                    BarMark(x: .value("Día", Fechas.fecha(deDia: p.dia) ?? Date(), unit: .day),
                            y: .value("Galones", NSDecimalNumber(decimal: p.galones).doubleValue))
                        .foregroundStyle(by: .value("Combustible", p.combustible.nombre))
                }
                .chartForegroundStyleScale([
                    Combustible.superior.nombre: Combustible.superior.color,
                    Combustible.regular.nombre: Combustible.regular.color,
                    Combustible.diesel.nombre: Combustible.diesel.color,
                ])
                .frame(height: 200)
                .accessibilityLabel("Gráfico de galones vendidos por día y combustible")
            }
        }
        .tarjeta()
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ranking de sucursales por ventas").font(.headline).foregroundColor(.gas76Blue)
            ForEach(Array(vm.ranking.enumerated()), id: \.element.id) { i, f in
                NavigationLink { DetalleSucursalView(sucursal: f.sucursal) } label: {
                    HStack {
                        Text("\(i + 1)").font(.headline).foregroundColor(.gas76Orange).frame(width: 24)
                        Text(f.sucursal.nombre).foregroundColor(.primary)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(Formateadores.galones(f.galones)).font(.subheadline.bold()).foregroundColor(.primary)
                            Text(Formateadores.dolares(f.ingreso)).font(.caption).foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                if i < vm.ranking.count - 1 { Divider() }
            }
        }
        .tarjeta()
    }

    @ViewBuilder private var tanquesCriticos: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tanques en estado Crítico").font(.headline).foregroundColor(.gas76Rojo)
            if vm.tanquesCriticos.isEmpty {
                Text("Ningún tanque está en estado Crítico.").font(.callout).foregroundColor(.secondary)
            }
            ForEach(vm.tanquesCriticos) { t in
                if let s = vm.datos?.sucursales.first(where: { $0.id == t.sucursalId }) {
                    NavigationLink { DetalleSucursalView(sucursal: s) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(s.nombre) · \(t.combustible.nombre)").foregroundColor(.primary)
                                Text("\(Formateadores.galones(t.nivelEstimadoGal)) · \(Formateadores.porcentaje(t.porcentaje))")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Insignia(texto: "Crítico", color: .gas76Rojo)
                        }
                    }
                }
            }
        }
        .tarjeta()
    }

    private var sinCorteHoy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sucursales sin corte cerrado hoy").font(.headline).foregroundColor(.gas76Blue)
            if vm.sucursalesSinCorteHoy.isEmpty {
                Text("Todas las sucursales ya cerraron un corte hoy.").font(.callout).foregroundColor(.secondary)
            }
            ForEach(vm.sucursalesSinCorteHoy) { Text($0.nombre).font(.subheadline) }
        }
        .tarjeta()
    }

    private var cortesConDiferencia: some View {
        HStack {
            Text("Cortes con diferencia en el cuadre").foregroundColor(.primary)
            AyudaBoton(texto: "Es solo un indicador: cuenta los cortes cuyo nivel medido en el tanque difiere del teórico por más de la tolerancia (0.5 % de los galones despachados).")
            Spacer()
            Text("\(vm.datos?.cortesConDiferencia ?? 0)").font(.title3.bold()).foregroundColor(.gas76Orange)
        }
        .tarjeta()
    }

    /// Bloque aparte «Tienda y servicios».
    private var tienda: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tienda y servicios").font(.headline).foregroundColor(.gas76Blue)
            if !vm.hayActividadTienda {
                Text("Sin ventas de tienda en este periodo.").font(.callout).foregroundColor(.secondary)
            } else {
                FilaDato(titulo: "Ingreso de tienda", valor: Formateadores.dolares(vm.ingresoTienda), destacado: true)
                ForEach(vm.ingresoTiendaPorCategoria, id: \.categoria) { c in
                    FilaDato(titulo: "\(c.categoria.nombre) (\(c.unidades) u.)", valor: Formateadores.dolares(c.ingreso))
                }
                Divider()
                FilaDato(titulo: "Ventas anuladas", valor: "\(vm.ventasAnuladas) · \(Formateadores.dolares(vm.totalAnulado))")
                FilaDato(titulo: "Cierres de caja con diferencia", valor: "\(vm.cajasConDiferencia)")
                FilaDato(titulo: "Cierres forzados", valor: "\(vm.cajasForzadas)")
                FilaDato(titulo: "Productos con stock bajo", valor: "\(vm.datos?.stockBajo.count ?? 0)")
            }
            NavigationLink { TiendaYCajasView() } label: {
                Label("Ver tienda y cajas", systemImage: "bag").font(.subheadline)
            }
            .tint(.gas76Orange)
        }
        .tarjeta()
    }
}

/// 11 · Detalle de combustible: por sucursal, lo vendido, compras, pérdidas y el estado del tanque.
struct DetalleCombustibleView: View {
    @ObservedObject var vm: PanelViewModel
    let combustible: Combustible

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if vm.sinCortesCerrados { SinCortesCerradosView(texto: vm.textoSinCortes) }
                if let t = vm.totales.first(where: { $0.combustible == combustible }) {
                    HStack(spacing: 10) {
                        SummaryCard(title: "Vendido", value: Formateadores.galones(t.galones), systemImage: "drop.fill", tint: combustible.color)
                        SummaryCard(title: "Ingreso", value: Formateadores.dolares(t.ingreso), systemImage: "dollarsign.circle.fill", tint: .gas76Verde)
                    }
                    HStack(spacing: 10) {
                        SummaryCard(title: "Compras", value: Formateadores.galones(t.compras), systemImage: "shippingbox.fill", tint: .gas76Blue)
                        SummaryCard(title: "Pérdidas", value: Formateadores.galones(t.perdidas), systemImage: "exclamationmark.triangle.fill", tint: .gas76Rojo)
                    }
                }
                ForEach(vm.detalle(de: combustible)) { f in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(f.sucursal.nombre).font(.headline).foregroundColor(.gas76Blue)
                        FilaDato(titulo: "Vendido", valor: Formateadores.galones(f.galones))
                        FilaDato(titulo: "Compras", valor: Formateadores.galones(f.compras))
                        FilaDato(titulo: "Pérdidas", valor: Formateadores.galones(f.perdidas))
                        if let t = f.tanque { TanqueRowView(tanque: t, mostrarIncluye: false) }
                    }
                    .tarjeta()
                }
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle(combustible.nombre)
        .navigationBarTitleDisplayMode(.inline)
    }
}
