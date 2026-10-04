import Foundation

/// «Olvidé mi contraseña»: correo → código de 6 dígitos → nueva contraseña.
@MainActor
final class RecuperarPasswordViewModel: ObservableObject {
    enum Paso { case correo, codigo, nueva }

    @Published private(set) var paso: Paso = .correo
    @Published var correo = ""
    @Published var codigo = "" {
        didSet {
            let limpio = String(Validadores.filtrarEntero(codigo).prefix(6))
            if limpio != codigo { codigo = limpio }
        }
    }
    @Published var nueva = ""
    @Published var confirmar = ""
    @Published private(set) var error: String?
    @Published private(set) var cargando = false
    @Published private(set) var segundosParaReenviar = 0

    private let auth: AuthService
    private let alTerminar: (String) -> Void
    private let esperaReenvio: Int
    private var tareaEspera: Task<Void, Never>?

    init(auth: AuthService, esperaReenvio: Int = 60, alTerminar: @escaping (String) -> Void) {
        self.auth = auth
        self.esperaReenvio = esperaReenvio
        self.alTerminar = alTerminar
    }

    deinit { tareaEspera?.cancel() }

    var correoValido: Bool { Validadores.esCorreoValido(correo) }
    var codigoCompleto: Bool { codigo.count == 6 }
    var passwordValida: Bool { Validadores.passwordValida(nueva) }
    var coinciden: Bool { nueva == confirmar }
    var puedeGuardar: Bool { passwordValida && coinciden && !cargando }

    func limpiarError() { error = nil }

    func enviarCodigo() async {
        guard correoValido else {
            error = "Escribe un correo válido."
            return
        }
        guard await ejecutar({ try await self.auth.enviarCodigo(correo: Validadores.correo(self.correo)) }) else { return }
        codigo = ""
        paso = .codigo
        iniciarEspera()
    }

    func reenviarCodigo() async {
        guard segundosParaReenviar == 0 else { return }
        if await ejecutar({ try await self.auth.enviarCodigo(correo: Validadores.correo(self.correo)) }) {
            iniciarEspera()
        }
    }

    func verificarCodigo() async {
        guard codigoCompleto else {
            error = "Escribe los 6 dígitos del código."
            return
        }
        let ok = await ejecutar({ try await self.auth.verificarCodigo(correo: Validadores.correo(self.correo), codigo: self.codigo) })
        if ok { paso = .nueva }
    }

    func guardarPassword() async {
        guard passwordValida else {
            error = "La contraseña debe tener entre 8 y 72 caracteres."
            return
        }
        guard coinciden else {
            error = "Las contraseñas no coinciden."
            return
        }
        guard await ejecutar({ try await self.auth.cambiarPassword(self.nueva) }) else { return }
        await auth.cerrarSesion()
        alTerminar("Contraseña actualizada. Ya puedes iniciar sesión.")
    }

    func volverACorreo() {
        paso = .correo
        error = nil
    }

    private func ejecutar(_ operacion: () async throws -> Void) async -> Bool {
        cargando = true
        error = nil
        defer { cargando = false }
        do {
            try await operacion()
            return true
        } catch {
            self.error = mensajeDe(error)
            return false
        }
    }

    private func iniciarEspera() {
        tareaEspera?.cancel()
        segundosParaReenviar = esperaReenvio
        guard esperaReenvio > 0 else { return }
        tareaEspera = Task { [weak self] in
            while let self, self.segundosParaReenviar > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.segundosParaReenviar -= 1
            }
        }
    }
}
