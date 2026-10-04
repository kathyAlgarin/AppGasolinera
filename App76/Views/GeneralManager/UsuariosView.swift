import SwiftUI

/// 21 · Lista de usuarios con filtros por rol y sucursal.
struct UsuariosView: View {
    let perfil: Perfil
    @StateObject private var vm = UsuariosViewModel(usuarios: Servicios.usuarios, sucursales: Servicios.sucursales)
    @State private var creando = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                filtros
                CargaView(estado: vm.estado, textoVacio: "No hay usuarios con esos filtros.", iconoVacio: "person.2",
                          esVacio: { _ in vm.filtrados.isEmpty }, reintentar: { Task { await vm.cargar() } }) { datos in
                    LazyVStack(spacing: 10) {
                        ForEach(vm.filtrados) { u in
                            NavigationLink {
                                EditarUsuarioView(usuario: u, sucursal: vm.nombreSucursal(u.sucursalId), esPropio: u.id == perfil.id) { Task { await vm.cargar() } }
                            } label: {
                                FilaUsuario(usuario: u, sucursal: vm.nombreSucursal(u.sucursalId))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.gas76Background)
        .navigationTitle("Usuarios")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creando = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nuevo usuario")
                    .disabled(vm.estado.valor == nil)
            }
        }
        .refreshable { await vm.cargar() }
        .onAppear { Task { await vm.cargar() } }
        .sheet(isPresented: $creando) {
            NuevoUsuarioView(creador: perfil, sucursales: vm.estado.valor?.sucursales ?? []) {
                creando = false
                Task { await vm.cargar() }
            } cerrar: { creando = false }
        }
    }

    private var filtros: some View {
        VStack(spacing: 8) {
            SelectorSucursal(sucursales: vm.estado.valor?.sucursales ?? [], seleccion: $vm.filtroSucursal)
            HStack {
                Text("Rol").foregroundColor(.secondary)
                Spacer()
                Picker("Rol", selection: $vm.filtroRol) {
                    Text("Todos los roles").tag(RolUsuario?.none)
                    ForEach(RolUsuario.allCases) { Text($0.nombre).tag(Optional($0)) }
                }
                .tint(.gas76Orange)
            }
            .font(.subheadline)
        }
    }
}

struct FilaUsuario: View {
    let usuario: Perfil
    let sucursal: String?
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(usuario.nombre).font(.headline).foregroundColor(.gas76Blue)
                Text(usuario.correo).font(.caption).foregroundColor(.secondary)
                HStack(spacing: 6) {
                    Insignia(texto: usuario.rol.nombre, color: .gas76Blue)
                    if let sucursal { Insignia(texto: sucursal, color: .gas76Gris) }
                    if !usuario.activo { Insignia(texto: "Inactivo", color: .gas76Rojo) }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.footnote)
        }
        .tarjeta()
        .opacity(usuario.activo ? 1 : 0.7)
    }
}
