import SwiftUI

/// «Olvidé mi contraseña»: correo → código de 6 dígitos → nueva contraseña.
struct RecuperarPasswordView: View {
    @StateObject private var vm: RecuperarPasswordViewModel

    init(sesion: SesionViewModel, visible: Binding<Bool>, correoInicial: String) {
        let modelo = RecuperarPasswordViewModel(auth: Servicios.auth) { aviso in
            sesion.volverAlLogin(aviso: aviso)
            visible.wrappedValue = false
        }
        modelo.correo = correoInicial
        _vm = StateObject(wrappedValue: modelo)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch vm.paso {
                case .correo: pasoCorreo
                case .codigo: pasoCodigo
                case .nueva: pasoNueva
                }
                MensajeError(texto: vm.error)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gas76Background.ignoresSafeArea())
        .navigationTitle("Recuperar contraseña")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pasoCorreo: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Escribe el correo de tu cuenta y te enviaremos un código de 6 dígitos.")
                .foregroundColor(.secondary)
            CampoTexto(titulo: "Correo", texto: $vm.correo, teclado: .emailAddress,
                       capitalizacion: .never, contenido: .emailAddress)
                .onChange(of: vm.correo) { _, _ in vm.limpiarError() }
            BotonPrimario(titulo: "Enviar código", cargando: vm.cargando, habilitado: vm.correoValido) {
                Task { await vm.enviarCodigo() }
            }
        }
    }

    private var pasoCodigo: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Enviamos un código a \(Validadores.correo(vm.correo)). Escríbelo aquí.")
                .foregroundColor(.secondary)
            CodigoCasillas(codigo: $vm.codigo)
                .onChange(of: vm.codigo) { _, _ in vm.limpiarError() }
            BotonPrimario(titulo: "Verificar", cargando: vm.cargando, habilitado: vm.codigoCompleto) {
                Task { await vm.verificarCodigo() }
            }
            HStack {
                Button(vm.segundosParaReenviar > 0 ? "Reenviar código (\(vm.segundosParaReenviar) s)" : "Reenviar código") {
                    Task { await vm.reenviarCodigo() }
                }
                .disabled(vm.segundosParaReenviar > 0 || vm.cargando)
                Spacer()
                Button("Cambiar correo") { vm.volverACorreo() }
            }
            .font(.subheadline)
            .tint(.gas76Orange)
        }
    }

    private var pasoNueva: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Define tu nueva contraseña (de 8 a 72 caracteres).")
                .foregroundColor(.secondary)
            CampoPassword(titulo: "Nueva contraseña", texto: $vm.nueva, nueva: true)
            CampoPassword(titulo: "Confirmar contraseña", texto: $vm.confirmar, nueva: true)
            BotonPrimario(titulo: "Guardar", cargando: vm.cargando, habilitado: vm.puedeGuardar) {
                Task { await vm.guardarPassword() }
            }
        }
        .onChange(of: vm.nueva) { _, _ in vm.limpiarError() }
        .onChange(of: vm.confirmar) { _, _ in vm.limpiarError() }
    }
}

/// Seis casillas que se llenan con un solo teclado numérico.
struct CodigoCasillas: View {
    @Binding var codigo: String
    @FocusState private var enfocado: Bool

    var body: some View {
        ZStack {
            TextField("", text: $codigo)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($enfocado)
                .opacity(0.02)
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let caracter = i < codigo.count ? String(Array(codigo)[i]) : ""
                    Text(caracter)
                        .font(.title.monospacedDigit().bold())
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.gas76Card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(i == codigo.count && enfocado ? Color.gas76Orange : Color.clear, lineWidth: 2))
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { enfocado = true }
        .onAppear { enfocado = true }
        .accessibilityLabel("Código de 6 dígitos")
    }
}
