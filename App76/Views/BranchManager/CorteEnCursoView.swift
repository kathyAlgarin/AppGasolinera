import SwiftUI

/// 31 · Centro del flujo del corte. Cada sección muestra su estado y abre su pantalla.
struct CorteEnCursoView: View {
    let perfil: Perfil
    @ObservedObject var nav: NavegacionSucursal
    @StateObject private var vm: CorteEnCursoViewModel
    @State private var vaciando = false

    init(perfil: Perfil, nav: NavegacionSucursal) {
        self.perfil = perfil
        self.nav = nav
        _vm = StateObject(wrappedValue: CorteEnCursoViewModel(
            sucursalId: perfil.sucursalId ?? UUID(), corte: Servicios.corte, lineas: Servicios.lineas, tanques: Servicios.tanques,
            sucursales: Servicios.sucursales, almacen: Servicios.almacenNiveles))
    }

    var body: some View {
        NavigationStack(path: $nav.rutaCorte) {
            ScrollView {
                CargaView(estado: vm.estado, reintentar: { Task { await vm.cargar() } }) { datos in
                    VStack(alignment: .leading, spacing: 12) {
                        cabecera(datos)
                        fila(.bombas, "Bombas", "\(vm.bombasGuardadas.count) de 6 guardadas", "fuelpump.fill",
                             completo: vm.bombasFaltantes.isEmpty)
                        fila(.compras, "Compras", conteo(datos.compras, "compra"), "shippingbox.fill")
                        fila(.perdidas, "Pérdidas", conteo(datos.perdidas, "pérdida"), "exclamationmark.triangle.fill")
                        Button { vaciando = true } label: {
                            FilaSeccion(titulo: "Descarga errónea y vaciado", detalle: conteo(datos.vaciados, "vaciado"), icono: "arrow.triangle.2.circlepath")
                        }.buttonStyle(.plain)
                        if datos.tieneTienda {
                            fila(.tienda, "Tienda", "Entradas y bajas de mercadería", "bag.fill")
                        }
                        fila(.niveles, "Niveles de tanque", vm.nivelesCompletos ? "Capturados" : "Pendientes", "gauge.with.dots.needle.50percent",
                             completo: vm.nivelesCompletos)

                        VStack(spacing: 6) {
                            NavigationLink(value: RutaCorte.resumen) {
                                Text("Resumen y cierre").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(vm.puedeCerrar ? Color.gas76Orange : Color.gray.opacity(0.4))
                                    .foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(!vm.puedeCerrar)
                            if let motivo = vm.motivoNoCierra {
                                Text(motivo).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .background(Color.gas76Background)
            .navigationTitle("Corte en curso")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AyudaBoton(texto: "Las lecturas y los niveles se ingresan manualmente: lee el totalizador de cada manguera y mide el tanque con varilla. La app no se conecta a las bombas.")
                }
            }
            .refreshable { await vm.cargar() }
            .onAppear { Task { await vm.cargar() } }
            .navigationDestination(for: RutaCorte.self) { destino($0) }
            .sheet(isPresented: $vaciando) {
                if let d = vm.datos {
                    VaciadoView(corteId: d.corte.id, tanques: d.tanques) {
                        vaciando = false
                        Task { await vm.cargar() }
                    } cerrar: { vaciando = false }
                }
            }
        }
    }

    private func cabecera(_ d: CorteEnCursoViewModel.Datos) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Corte n.º \(d.corte.secuencia)").font(.title3.bold()).foregroundColor(.gas76Blue)
                Text("Abierto el \(Fechas.fechaHora(d.corte.abiertoEn))").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if d.corte.secuencia == 1 { Insignia(texto: "Primer corte", color: .gas76Blue) }
        }
    }

    private func conteo(_ n: Int, _ singular: String) -> String {
        n == 0 ? "Sin registros" : "\(n) \(n == 1 ? singular : singular + (singular.hasSuffix("a") || singular.hasSuffix("o") ? "s" : "es"))"
    }

    private func fila(_ ruta: RutaCorte, _ titulo: String, _ detalle: String, _ icono: String, completo: Bool? = nil) -> some View {
        NavigationLink(value: ruta) {
            FilaSeccion(titulo: titulo, detalle: detalle, icono: icono, completo: completo)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destino(_ ruta: RutaCorte) -> some View {
        switch ruta {
        case .bombas: BombasListView(vm: vm)
        case .bomba(let id): BombaFormView(vm: vm, bombaId: id)
        case .compras: ComprasView(vm: vm)
        case .perdidas: PerdidasView(vm: vm)
        case .niveles: NivelesView(vm: vm)
        case .tienda: InventarioSucursalView(perfil: perfil, corteId: vm.datos?.corte.id)
        case .resumen: ResumenCierreView(vm: vm, nav: nav)
        case .cerrado(let r): CorteCerradoView(resultado: r, nav: nav)
        case .reporte(let id): ReporteCortePorIdView(corteId: id, esGerenteGeneral: false)
        }
    }
}

struct FilaSeccion: View {
    let titulo: String
    let detalle: String
    let icono: String
    var completo: Bool?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .frame(width: 36, height: 36)
                .foregroundColor(.white)
                .background(Color.gas76Orange)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.headline).foregroundColor(.gas76Blue)
                Text(detalle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if let completo {
                Image(systemName: completo ? "checkmark.circle.fill" : "circle").foregroundColor(completo ? .gas76Verde : .secondary)
            }
            Image(systemName: "chevron.right").font(.footnote).foregroundColor(.secondary)
        }
        .tarjeta()
    }
}
