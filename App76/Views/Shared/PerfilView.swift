import SwiftUI

/// Perfil de cualquier rol: datos de solo lectura, cambiar contraseña y cerrar sesión.
struct PerfilView: View {
    @ObservedObject var sesion: SesionViewModel
    @StateObject private var vm: PerfilViewModel
    @State private var cambiando = false
    @State private var confirmandoSalida = false

    init(perfil: Perfil, sesion: SesionViewModel) {
        self.sesion = sesion
        _vm = StateObject(wrappedValue: PerfilViewModel(perfil: perfil, sucursales: Servicios.sucursales))
    }

    var body: some View {
        List {
            Section {
                FilaDato(titulo: "Nombre", valor: vm.perfil.nombre)
                FilaDato(titulo: "Correo", valor: vm.perfil.correo)
                FilaDato(titulo: "Rol", valor: vm.perfil.rol.nombre)
                if vm.perfil.sucursalId != nil {
                    switch vm.sucursal {
                    case .listo(let nombre): FilaDato(titulo: "Sucursal", valor: nombre ?? "—")
                    case .error(let m): FilaDato(titulo: "Sucursal", valor: m, color: .gas76Rojo)
                    default: FilaDato(titulo: "Sucursal", valor: "Cargando…")
                    }
                }
            }
            Section {
                Button("Cambiar contraseña") { cambiando = true }
                Button("Cerrar sesión", role: .destructive) { confirmandoSalida = true }
            }
        }
        .navigationTitle("Perfil")
        .task { await vm.cargar() }
        .sheet(isPresented: $cambiando) {
            HojaFormulario(titulo: "Cambiar contraseña", cerrar: { cambiando = false }) {
                CambioPasswordView(obligatorio: false) { cambiando = false }
                    .frame(minHeight: 360)
            }
        }
        .alert("¿Cerrar sesión?", isPresented: $confirmandoSalida) {
            Button("Cancelar", role: .cancel) {}
            Button("Cerrar sesión", role: .destructive) { Task { await sesion.cerrarSesion() } }
        }
    }
}
