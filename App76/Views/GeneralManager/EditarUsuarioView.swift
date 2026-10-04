import SwiftUI

/// 23 · Datos del usuario, cambiar correo, restablecer contraseña y activar/desactivar.
struct EditarUsuarioView: View {
    @StateObject private var vm: EditarUsuarioViewModel
    let sucursal: String?
    let esPropio: Bool

    init(usuario: Perfil, sucursal: String?, esPropio: Bool = false, alCambiar: @escaping () -> Void) {
        self.esPropio = esPropio
        _vm = StateObject(wrappedValue: EditarUsuarioViewModel(usuario: usuario, servicio: Servicios.usuarios, alCambiar: alCambiar))
        self.sucursal = sucursal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    FilaDato(titulo: "Nombre", valor: vm.usuario.nombre)
                    FilaDato(titulo: "Rol", valor: vm.usuario.rol.nombre)
                    if let sucursal { FilaDato(titulo: "Sucursal", valor: sucursal) }
                }
                .padding()
                .background(Color.gas76Card)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if esPropio {
                    FilaDato(titulo: "Correo", valor: vm.usuario.correo)
                        .padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gas76Card).clipShape(RoundedRectangle(cornerRadius: 14))
                    Text("Este es tu usuario: no puedes cambiar tu propio correo, contraseña ni estado desde aquí.")
                        .font(.footnote).foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        CampoTexto(titulo: "Correo de inicio de sesión", texto: $vm.correoNuevo, teclado: .emailAddress, capitalizacion: .never,
                                   contenido: .emailAddress, error: vm.correoNuevo.isEmpty ? nil : vm.errorCorreo)
                        BotonPrimario(titulo: "Cambiar correo", cargando: vm.trabajando, habilitado: vm.errorCorreo == nil && vm.hayCambioCorreo) {
                            Task { await vm.cambiarCorreo() }
                        }
                        Text("Úsalo si el correo estaba mal escrito. El usuario deberá iniciar sesión con el correo nuevo.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }

                Toggle("Activo", isOn: Binding(get: { vm.usuario.activo }, set: { nuevo in Task { await vm.cambiarActivo(nuevo) } }))
                    .tint(.gas76Orange)
                    .disabled(vm.trabajando || esPropio)
                Text("Un usuario desactivado no puede iniciar sesión; nunca se borra. No se puede desactivar al último Gerente General ni a uno mismo.")
                    .font(.footnote).foregroundColor(.secondary)

                Text("Restablecer contraseña").font(.headline).foregroundColor(.gas76Blue).padding(.top, 8)
                CampoPassword(titulo: "Contraseña temporal", texto: $vm.passwordTemporal, nueva: true)
                Text("Deberá cambiarla al iniciar sesión.").font(.caption).foregroundColor(.secondary)
                BotonPrimario(titulo: "Restablecer contraseña", cargando: vm.trabajando, habilitado: vm.errorPassword == nil) {
                    Task { await vm.restablecer() }
                }
                MensajeAviso(texto: vm.aviso)
                MensajeError(texto: vm.error)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gas76Background)
        .navigationTitle("Usuario")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.passwordTemporal) { _, _ in vm.limpiarMensajes() }
        .onChange(of: vm.correoNuevo) { _, _ in vm.limpiarMensajes() }
    }
}
