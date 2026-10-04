import SwiftUI

/// 41 · Resumen y cierre del corte. 42 · Alerta de confirmación. 43 · Corte cerrado.
struct ResumenCierreView: View {
    @ObservedObject var vm: CorteEnCursoViewModel
    @ObservedObject var nav: NavegacionSucursal

    var body: some View {
        if let d = vm.datos, let niveles = vm.nivelesParaEnviar() {
            ContenidoResumen(hub: vm, nav: nav, datos: d, niveles: niveles)
        } else {
            Text("Faltan lecturas o niveles para ver el resumen.").foregroundColor(.secondary).padding()
                .navigationTitle("Resumen y cierre")
        }
    }
}

private struct ContenidoResumen: View {
    @ObservedObject var hub: CorteEnCursoViewModel
    @ObservedObject var nav: NavegacionSucursal
    @StateObject private var vm: ResumenCierreViewModel
    @State private var confirmando = false

    init(hub: CorteEnCursoViewModel, nav: NavegacionSucursal, datos: CorteEnCursoViewModel.Datos, niveles: [NivelMedido]) {
        self.hub = hub
        self.nav = nav
        _vm = StateObject(wrappedValue: ResumenCierreViewModel(
            corte: datos.corte, niveles: niveles, tieneTienda: datos.tieneTienda, servicio: Servicios.corte, tienda: Servicios.tienda,
            alCerrar: {}))
    }

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, reintentar: { Task { await vm.cargar() } }) { _ in
                VStack(alignment: .leading, spacing: 14) {
                    if vm.esPrimerCorte {
                        VStack(alignment: .leading, spacing: 6) {
                            TituloConAyuda(titulo: "¿Este primer corte es Matutino o Vespertino?",
                                           ayuda: "Solo se pregunta en el primer corte de la sucursal. Desde el segundo, los cortes alternan Matutino y Vespertino automáticamente.")
                                .font(.subheadline.bold())
                            Picker("Tipo", selection: $vm.tipoInicial) {
                                ForEach(TipoCorte.allCases) { Text($0.nombre).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    HStack(spacing: 10) {
                        SummaryCard(title: "Galones", value: Formateadores.galones(vm.galonesTotales), systemImage: "drop.fill")
                        SummaryCard(title: "Ingreso", value: Formateadores.dolares(vm.ingresoTotal), systemImage: "dollarsign.circle.fill", tint: .gas76Verde)
                    }

                    ForEach(vm.filas) { f in TarjetaResumenPrevio(fila: f) }

                    if vm.hayDiferencias {
                        Text("La diferencia del cuadre es solo un indicador: no impide cerrar el corte.")
                            .font(.footnote).foregroundColor(.secondary)
                    }

                    if let bloqueo = vm.motivoBloqueo {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(bloqueo)
                        }
                        .font(.callout).foregroundColor(.gas76Rojo)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gas76Rojo.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    MensajeError(texto: vm.error)
                    BotonPrimario(titulo: "Cerrar corte", cargando: vm.cerrando, habilitado: vm.puedeCerrar) { confirmando = true }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Resumen y cierre")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
        .alert("¿Cerrar el corte?", isPresented: $confirmando) {
            Button("Cancelar", role: .cancel) {}
            Button("Cerrar corte", role: .destructive) {
                Task {
                    await vm.cerrar()
                    if let r = vm.resultado {
                        hub.olvidarNiveles()
                        nav.rutaCorte.append(.cerrado(r))
                        await hub.cargar()
                    }
                }
            }
        } message: {
            Text("Después de cerrarlo no se podrá modificar.")
        }
    }
}

struct TarjetaResumenPrevio: View {
    let fila: ResumenPrevio

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(fila.combustible.nombre, systemImage: "fuelpump.fill").font(.headline).foregroundColor(fila.combustible.color)
                Spacer()
                if fila.hayCambioMedidor { Insignia(texto: "Cambio de medidor", color: .gas76Blue) }
                IndicadorCuadre(hayDiferencia: fila.hayDiferencia, diferencia: fila.diferenciaGal)
            }
            FilaDato(titulo: "Galones vendidos", valor: Formateadores.galones(fila.galonesVendidos))
            if let p = fila.precioGal {
                FilaDato(titulo: "Precio vigente", valor: "\(Formateadores.dolares(p))/gal")
                FilaDato(titulo: "Ingreso", valor: Formateadores.dolares(fila.ingresoUsd ?? 0), destacado: true)
            } else {
                FilaDato(titulo: "Precio vigente", valor: "Sin precio", color: .gas76Rojo)
            }
            FilaDato(titulo: "Compras", valor: Formateadores.galones(fila.comprasGal))
            FilaDato(titulo: "Pérdidas", valor: Formateadores.galones(fila.perdidasGal))
            Divider()
            FilaDato(titulo: "Nivel teórico", valor: Formateadores.galones(fila.nivelTeoricoGal))
            if let m = fila.nivelMedidoGal { FilaDato(titulo: "Nivel medido", valor: Formateadores.galones(m)) }
        }
        .tarjeta()
    }
}

/// «Cuadra» (verde) o «Diferencia» (naranja, con ± galones), con la explicación de la tolerancia.
struct IndicadorCuadre: View {
    let hayDiferencia: Bool?
    let diferencia: Decimal?

    var body: some View {
        HStack(spacing: 4) {
            if hayDiferencia == true {
                Insignia(texto: "Diferencia \(diferencia.map(Formateadores.galonesConSigno) ?? "")", color: .gas76Orange, conAyuda: false)
            } else {
                Insignia(texto: "Cuadra", color: .gas76Verde, conAyuda: false)
            }
            AyudaBoton(texto: "El cuadre compara el nivel teórico (inicial + compras − galones del medidor − pérdidas) con el nivel medido en el tanque. Se considera «Cuadra» si la diferencia es menor al 0.5 % de los galones despachados. Es solo un indicador.")
        }
    }
}

/// 43 · Confirmación del cierre.
struct CorteCerradoView: View {
    let resultado: ResultadoCierreCorte
    @ObservedObject var nav: NavegacionSucursal

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundColor(.gas76Verde)
            Text("Corte cerrado").font(.title.bold()).foregroundColor(.gas76Blue)
            Text("\(resultado.tipo.nombre) · \(Fechas.dia(resultado.fechaOperativa))").foregroundColor(.secondary)
            Text("Ya no se puede modificar. El siguiente corte quedó en curso con las lecturas iniciales derivadas.")
                .multilineTextAlignment(.center).font(.callout).foregroundColor(.secondary).padding(.horizontal)
            Spacer()
            BotonPrimario(titulo: "Ver reporte") { nav.rutaCorte.append(.reporte(resultado.corteId)) }
            Button("Volver al inicio") { nav.pestana = .inicio; nav.rutaCorte = [] }
                .padding(.bottom)
        }
        .padding()
        .background(Color.gas76Background)
        .navigationBarBackButtonHidden(true)
    }
}
