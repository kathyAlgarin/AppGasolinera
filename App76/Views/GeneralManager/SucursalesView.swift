import SwiftUI

/// 15 · Lista de sucursales. ＋ abre el alta; la fila abre la edición.
struct SucursalesView: View {
    @StateObject private var vm = SucursalesViewModel(servicio: Servicios.sucursales)
    @State private var creando = false

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, textoVacio: "Aún no hay sucursales. Toca ＋ para crear la primera.",
                      iconoVacio: "building.2", esVacio: { $0.isEmpty },
                      reintentar: { Task { await vm.cargar() } }) { lista in
                LazyVStack(spacing: 10) {
                    ForEach(lista) { s in
                        NavigationLink {
                            EditarSucursalView(sucursal: s) { Task { await vm.cargar() } }
                        } label: {
                            FilaSucursal(sucursal: s)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Sucursales")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creando = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nueva sucursal")
            }
        }
        .refreshable { await vm.cargar() }
        .onAppear { Task { await vm.cargar() } }
        .sheet(isPresented: $creando) {
            NuevaSucursalView {
                creando = false
                Task { await vm.cargar() }
            } cerrar: { creando = false }
        }
    }
}

struct FilaSucursal: View {
    let sucursal: Sucursal
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sucursal.nombre).font(.headline).foregroundColor(.gas76Blue)
                Text(sucursal.direccion).font(.caption).foregroundColor(.secondary).lineLimit(2)
                HStack(spacing: 6) {
                    if !sucursal.activa { Insignia(texto: "Inactiva", color: .gas76Gris) }
                    if sucursal.tieneTienda { Insignia(texto: "Con tienda", color: .gas76Blue) }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.footnote)
        }
        .tarjeta()
        .opacity(sucursal.activa ? 1 : 0.7)
    }
}
