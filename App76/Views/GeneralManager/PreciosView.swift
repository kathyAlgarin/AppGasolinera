import SwiftUI

/// 18 · Precios vigentes por sucursal. 19 · Fijar precio. 20 · Historial.
struct PreciosView: View {
    @StateObject private var vm = PreciosViewModel(sucursales: Servicios.sucursales, precios: Servicios.precios)
    @State private var fijando = false

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, textoVacio: "Aún no hay sucursales.", iconoVacio: "building.2",
                      esVacio: { $0.sucursales.isEmpty }, reintentar: { Task { await vm.cargar() } }) { datos in
                VStack(alignment: .leading, spacing: 16) {
                    SelectorSucursal(sucursales: datos.sucursales, seleccion: $vm.sucursalId, permitirTodas: false)

                    if !vm.combustiblesSinPrecio.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Sin precio de \(vm.combustiblesSinPrecio.map(\.nombre).joined(separator: ", ")): la sucursal no podrá cerrar cortes.")
                        }
                        .font(.callout).foregroundColor(.gas76Rojo)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gas76Rojo.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(spacing: 10) {
                        ForEach(Combustible.allCases) { c in
                            FilaPrecio(combustible: c, precio: vm.vigente(c))
                        }
                    }

                    BotonPrimario(titulo: "Fijar precio") { fijando = true }
                    NavigationLink {
                        HistorialPreciosView(vm: vm)
                    } label: {
                        Label("Ver historial de precios", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .font(.subheadline)
                    .tint(.gas76Orange)
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Precios")
        .refreshable { await vm.cargar() }
        .onAppear { Task { await vm.cargar() } }
        .sheet(isPresented: $fijando) {
            if let datos = vm.estado.valor {
                FijarPrecioView(sucursales: datos.sucursales, sucursalActual: vm.sucursalId) {
                    fijando = false
                    Task { await vm.cargar() }
                } cerrar: { fijando = false }
            }
        }
    }
}

private struct FilaPrecio: View {
    let combustible: Combustible
    let precio: Precio?
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(combustible.nombre).font(.headline).foregroundColor(combustible.color)
                if let precio {
                    Text("Vigente desde \(Fechas.fechaHora(precio.vigenteDesde))").font(.caption).foregroundColor(.secondary)
                } else {
                    Text("Sin precio").font(.caption).foregroundColor(.gas76Rojo)
                }
            }
            Spacer()
            if let precio {
                Text("\(Formateadores.dolares(precio.precioGal))/gal").font(.title3.bold()).foregroundColor(.gas76Blue)
            } else {
                Text("—").font(.title3).foregroundColor(.secondary)
            }
        }
        .tarjeta()
    }
}

struct FijarPrecioView: View {
    @StateObject private var vm: FijarPrecioViewModel
    let cerrar: () -> Void

    init(sucursales: [Sucursal], sucursalActual: UUID?, alGuardar: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: FijarPrecioViewModel(
            sucursales: sucursales, sucursalActual: sucursalActual, servicio: Servicios.precios, alGuardar: alGuardar))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: "Fijar precio", cerrar: cerrar) {
            Picker("Combustible", selection: $vm.combustible) {
                ForEach(Combustible.allCases) { Text($0.nombre).tag($0) }
            }
            .pickerStyle(.segmented)

            CampoNumerico(titulo: "Precio por galón (USD)", texto: $vm.precio, unidad: "USD",
                          ayuda: "Es el precio final por galón, ya con impuestos. Cada cambio guarda su fecha de inicio; el historial nunca se sobrescribe.",
                          error: vm.precio.isEmpty ? nil : vm.errorPrecio)

            VStack(alignment: .leading, spacing: 6) {
                Text("Aplicar a").font(.subheadline).foregroundColor(.secondary)
                Picker("Aplicar a", selection: $vm.alcance) {
                    ForEach(FijarPrecioViewModel.Alcance.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if vm.alcance == .elegir {
                VStack(spacing: 0) {
                    ForEach(vm.sucursales) { s in
                        Button { vm.alternar(s.id) } label: {
                            HStack {
                                Text(s.nombre).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: vm.elegidas.contains(s.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(vm.elegidas.contains(s.id) ? .gas76Orange : .secondary)
                            }
                            .padding(12)
                        }
                        Divider()
                    }
                }
                .background(Color.gas76Card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if vm.alcance == .todas {
                Text("Se aplicará a las \(vm.destino.count) sucursales activas.").font(.footnote).foregroundColor(.secondary)
            }

            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Guardar", cargando: vm.guardando, habilitado: vm.puedeGuardar) {
                Task { await vm.guardar() }
            }
        }
        .onChange(of: vm.precio) { _, _ in vm.limpiarError() }
    }
}

struct HistorialPreciosView: View {
    @ObservedObject var vm: PreciosViewModel

    var body: some View {
        List {
            let filas = vm.historialDeSucursal()
            if filas.isEmpty {
                Text("Esta sucursal todavía no tiene precios.").foregroundColor(.secondary)
            }
            ForEach(Combustible.allCases) { c in
                let deEste = filas.filter { $0.combustible == c }
                if !deEste.isEmpty {
                    Section(c.nombre) {
                        ForEach(deEste) { p in
                            HStack {
                                Text(Fechas.fechaHora(p.vigenteDesde)).font(.subheadline)
                                Spacer()
                                Text("\(Formateadores.dolares(p.precioGal))/gal").font(.subheadline.bold())
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Historial · \(vm.sucursalActual?.nombre ?? "")")
        .navigationBarTitleDisplayMode(.inline)
    }
}
