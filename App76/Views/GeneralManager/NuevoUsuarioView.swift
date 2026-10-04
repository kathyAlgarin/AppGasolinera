import SwiftUI

/// 22 · Nuevo usuario (hoja). Lo usa el Gerente General (cualquier rol) y el Gerente de Sucursal (cajeros).
struct NuevoUsuarioView: View {
    @StateObject private var vm: NuevoUsuarioViewModel
    let cerrar: () -> Void
    @State private var intentado = false

    init(creador: Perfil, sucursales: [Sucursal], alCrear: @escaping () -> Void, cerrar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: NuevoUsuarioViewModel(
            creador: creador, sucursales: sucursales, servicio: Servicios.usuarios, alCrear: alCrear))
        self.cerrar = cerrar
    }

    var body: some View {
        HojaFormulario(titulo: vm.rolesPermitidos == [.cajero] ? "Nuevo cajero" : "Nuevo usuario", cerrar: cerrar) {
            CampoTexto(titulo: "Nombre", texto: $vm.nombre, capitalizacion: .words,
                       error: mostrar(vm.errorNombre, vacio: vm.nombre.isEmpty))
            CampoTexto(titulo: "Correo", texto: $vm.correo, teclado: .emailAddress, capitalizacion: .never,
                       contenido: .emailAddress, error: mostrar(vm.errorCorreo, vacio: vm.correo.isEmpty))
            VStack(alignment: .leading, spacing: 4) {
                CampoPassword(titulo: "Contraseña temporal", texto: $vm.passwordTemporal, nueva: true)
                if intentado || !vm.passwordTemporal.isEmpty, let e = vm.errorPassword { Text(e).font(.caption).foregroundColor(.gas76Rojo) }
                Text("Deberá cambiarla al iniciar sesión.").font(.caption).foregroundColor(.secondary)
            }

            if vm.rolesPermitidos.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rol").font(.subheadline).foregroundColor(.secondary)
                    Picker("Rol", selection: $vm.rol) {
                        ForEach(vm.rolesPermitidos) { Text($0.nombre).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.gas76Orange)
                }
            }

            if vm.rolRequiereSucursal && !vm.esSucursalFija {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sucursal").font(.subheadline).foregroundColor(.secondary)
                    Picker("Sucursal", selection: $vm.sucursalId) {
                        Text("Elige una sucursal").tag(UUID?.none)
                        ForEach(vm.sucursalesElegibles) { Text($0.nombre).tag(Optional($0.id)) }
                    }
                    .tint(.gas76Orange)
                    if vm.rol == .cajero {
                        Text("Los cajeros solo se crean en sucursales con tienda.").font(.caption).foregroundColor(.secondary)
                    }
                    if intentado, let e = vm.errorSucursal { Text(e).font(.caption).foregroundColor(.gas76Rojo) }
                }
            }

            MensajeError(texto: vm.error)
            BotonPrimario(titulo: "Crear usuario", cargando: vm.guardando, habilitado: vm.esValido) {
                intentado = true
                Task { await vm.crear() }
            }
        }
        .onChange(of: vm.correo) { _, _ in vm.limpiarError() }
    }

    private func mostrar(_ mensaje: String?, vacio: Bool) -> String? {
        (intentado || !vacio) ? mensaje : nil
    }
}
