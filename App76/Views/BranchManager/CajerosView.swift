import SwiftUI

/// 57 · Cajeros de la sucursal (solo con tienda): crear, restablecer contraseña y activar/desactivar.
struct CajerosView: View {
    let perfil: Perfil
    @StateObject private var vm: UsuariosViewModel
    @State private var creando = false

    init(perfil: Perfil) {
        self.perfil = perfil
        let modelo = UsuariosViewModel(usuarios: Servicios.usuarios, sucursales: Servicios.sucursales)
        modelo.filtroRol = .cajero
        _vm = StateObject(wrappedValue: modelo)
    }

    var body: some View {
        ScrollView {
            CargaView(estado: vm.estado, textoVacio: "Aún no hay cajeros. Toca ＋ para crear el primero.", iconoVacio: "person.crop.circle.badge.plus",
                      esVacio: { _ in vm.filtrados.isEmpty }, reintentar: { Task { await vm.cargar() } }) { _ in
                LazyVStack(spacing: 10) {
                    ForEach(vm.filtrados) { u in
                        NavigationLink {
                            EditarUsuarioView(usuario: u, sucursal: nil, esPropio: u.id == perfil.id) { Task { await vm.cargar() } }
                        } label: { FilaUsuario(usuario: u, sucursal: nil) }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .background(Color.gas76Background)
        .navigationTitle("Cajeros")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creando = true } label: { Image(systemName: "plus") }.accessibilityLabel("Nuevo cajero")
            }
        }
        .refreshable { await vm.cargar() }
        .task { await vm.cargar() }
        .sheet(isPresented: $creando) {
            NuevoUsuarioView(creador: perfil, sucursales: vm.estado.valor?.sucursales ?? []) {
                creando = false
                Task { await vm.cargar() }
            } cerrar: { creando = false }
        }
    }
}
