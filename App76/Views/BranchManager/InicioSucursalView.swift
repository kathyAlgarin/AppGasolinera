import SwiftUI

/// 30 · Inicio del Gerente de Sucursal.
struct InicioSucursalView: View {
    let perfil: Perfil
    @ObservedObject var nav: NavegacionSucursal
    @StateObject private var vm: InicioSucursalViewModel

    init(perfil: Perfil, nav: NavegacionSucursal) {
        self.perfil = perfil
        self.nav = nav
        _vm = StateObject(wrappedValue: InicioSucursalViewModel(
            sucursalId: perfil.sucursalId ?? UUID(), tanques: Servicios.tanques, corte: Servicios.corte,
            lineas: Servicios.lineas, dashboard: Servicios.dashboard))
    }

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, reintentar: { Task { await vm.cargar() } }) { datos in
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hola, \(perfil.nombre)").font(.title2.bold()).foregroundColor(.gas76Blue)

                    seccion("Tanques") {
                        ForEach(datos.tanques) { TanqueRowView(tanque: $0) }
                    }

                    seccion("Corte en curso") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Corte n.º \(datos.corte.secuencia)").font(.headline)
                                Spacer()
                                Insignia(texto: "En curso", color: .gas76Orange)
                            }
                            Text("Abierto el \(Fechas.fechaHora(datos.corte.abiertoEn))").font(.caption).foregroundColor(.secondary)
                            HStack {
                                DatoCorto(valor: "\(datos.bombasGuardadas) de 6", titulo: "Bombas")
                                DatoCorto(valor: "\(datos.compras)", titulo: "Compras")
                                DatoCorto(valor: "\(datos.perdidas)", titulo: "Pérdidas")
                            }
                            BotonPrimario(titulo: "Continuar corte") { nav.abrir(nil) }
                            HStack(spacing: 10) {
                                Button { nav.abrir(.compras) } label: { Label("Registrar compra", systemImage: "plus.circle").frame(maxWidth: .infinity) }
                                Button { nav.abrir(.perdidas) } label: { Label("Registrar pérdida", systemImage: "exclamationmark.triangle").frame(maxWidth: .infinity) }
                            }
                            .buttonStyle(.bordered).tint(.gas76Orange).font(.footnote)
                        }
                        .padding()
                        .background(Color.gas76Card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    seccion("Hoy, en cortes cerrados") {
                        if vm.sinCortesCerradosHoy {
                            SinCortesCerradosView()
                        } else {
                            Text("Datos de \(vm.cortesCerradosHoy) \(vm.cortesCerradosHoy == 1 ? "corte cerrado" : "cortes cerrados") de hoy")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        HStack(spacing: 10) {
                            SummaryCard(title: "Galones vendidos", value: Formateadores.galones(vm.galonesHoy), systemImage: "drop.fill")
                            SummaryCard(title: "Ingreso", value: Formateadores.dolares(vm.ingresoHoy), systemImage: "dollarsign.circle.fill", tint: .gas76Verde)
                        }
                        ForEach(datos.hoy) { f in
                            HStack {
                                Text(f.combustible.nombre).foregroundColor(f.combustible.color).font(.subheadline.bold())
                                Spacer()
                                Text("\(Formateadores.galones(f.galonesVendidos)) · \(Formateadores.dolares(f.ingresoUsd))").font(.subheadline)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Inicio")
        .refreshable { await vm.cargar() }
        .onAppear { Task { await vm.cargar() } }
    }

    private func seccion<C: View>(_ titulo: String, @ViewBuilder _ contenido: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titulo).font(.headline).foregroundColor(.gas76Blue)
            contenido()
        }
    }
}

struct DatoCorto: View {
    let valor: String
    let titulo: String
    var body: some View {
        VStack {
            Text(valor).font(.title3.bold()).foregroundColor(.gas76Blue)
            Text(titulo).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
