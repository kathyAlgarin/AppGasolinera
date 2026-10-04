import SwiftUI

/// Cambio de contraseña. Obligatorio (pantalla completa, sin «atrás») o voluntario desde el perfil (hoja).
struct CambioPasswordView: View {
    @StateObject private var vm: CambioPasswordViewModel

    init(obligatorio: Bool, alTerminar: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: CambioPasswordViewModel(
            auth: Servicios.auth, obligatorio: obligatorio, alTerminar: alTerminar))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if vm.obligatorio {
                    Image("Logo76").resizable().scaledToFit().frame(width: 80, height: 80)
                        .frame(maxWidth: .infinity)
                    Text("Cambia tu contraseña")
                        .font(.title2.bold()).foregroundColor(.gas76Blue)
                    Text("Entraste con una contraseña temporal. Define una nueva para continuar.")
                        .foregroundColor(.secondary)
                } else {
                    Text("La nueva contraseña debe tener entre 8 y 72 caracteres.")
                        .foregroundColor(.secondary)
                }
                CampoPassword(titulo: "Nueva contraseña", texto: $vm.nueva, nueva: true)
                CampoPassword(titulo: "Confirmar contraseña", texto: $vm.confirmar, nueva: true)
                MensajeError(texto: vm.error)
                BotonPrimario(titulo: "Guardar", cargando: vm.cargando, habilitado: vm.puedeGuardar) {
                    Task { await vm.guardar() }
                }
            }
            .padding(24)
            .onChange(of: vm.nueva) { _, _ in vm.limpiarError() }
            .onChange(of: vm.confirmar) { _, _ in vm.limpiarError() }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gas76Background.ignoresSafeArea())
    }
}

/// Pantalla completa del cambio obligatorio, con la opción de salir.
struct CambioObligatorioView: View {
    @ObservedObject var sesion: SesionViewModel

    var body: some View {
        NavigationStack {
            CambioPasswordView(obligatorio: true) {
                Task { await sesion.passwordCambiada() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar sesión") { Task { await sesion.cerrarSesion() } }
                        .font(.subheadline)
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}
