import SwiftUI

struct LoginView: View {
    @ObservedObject var sesion: SesionViewModel
    @StateObject private var vm: LoginViewModel
    @State private var mostrarRecuperar = false
    @FocusState private var campo: Campo?
    private enum Campo { case correo, password }

    init(sesion: SesionViewModel) {
        self.sesion = sesion
        _vm = StateObject(wrappedValue: LoginViewModel(auth: Servicios.auth, alEntrar: { sesion.entrar($0) }))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image("Logo76")
                        .resizable().scaledToFit()
                        .frame(width: 110, height: 110)
                        .padding(.top, 40)
                    Text("Gasolineras 76")
                        .font(.title.bold()).foregroundColor(.gas76Blue)
                    Text("Inicia sesión para continuar")
                        .foregroundColor(.secondary)

                    MensajeAviso(texto: sesion.aviso)

                    VStack(spacing: 14) {
                        CampoTexto(titulo: "Correo", texto: $vm.correo, teclado: .emailAddress,
                                   capitalizacion: .never, contenido: .username)
                            .focused($campo, equals: .correo)
                            .submitLabel(.next)
                            .onSubmit { campo = .password }
                        CampoPassword(titulo: "Contraseña", texto: $vm.password)
                            .focused($campo, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await vm.ingresar() } }
                    }
                    .onChange(of: vm.correo) { _, _ in vm.limpiarError() }
                    .onChange(of: vm.password) { _, _ in vm.limpiarError() }

                    MensajeError(texto: vm.error)

                    BotonPrimario(titulo: "Ingresar", cargando: vm.cargando, habilitado: vm.puedeIngresar) {
                        campo = nil
                        Task { await vm.ingresar() }
                    }

                    Button("¿Olvidaste tu contraseña?") { mostrarRecuperar = true }
                        .font(.subheadline)
                        .foregroundColor(.gas76Orange)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.gas76Background.ignoresSafeArea())
            .navigationDestination(isPresented: $mostrarRecuperar) {
                RecuperarPasswordView(sesion: sesion, visible: $mostrarRecuperar, correoInicial: vm.correo)
            }
        }
    }
}
