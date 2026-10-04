import Foundation

@MainActor
func pruebasViewModels() async {
    await pruebasAcceso()
    await pruebasGerenteGeneral()
    await pruebasCorte()
    await pruebasCierreYReportes()
    await pruebasPanel()
    await pruebasPersonal()
    await pruebasTienda()
}

@MainActor
func pruebasAcceso() async {
    await grupo("SesionViewModel: arranque y enrutamiento") {
        let auth = AuthFalso()
        let vm = SesionViewModel(auth: auth)
        await vm.iniciar()
        igual(vm.estado, .sinSesion, "sin sesión guardada va al login")

        let gg = Ejemplo.perfil()
        auth.perfil = gg
        await vm.iniciar()
        igual(vm.estado, .dentro(gg), "sesión válida entra al inicio")

        let temporal = Ejemplo.perfil(rol: .cajero, debeCambiar: true)
        auth.perfil = temporal
        await vm.iniciar()
        igual(vm.estado, .cambioObligatorio(temporal), "contraseña temporal obliga el cambio")

        auth.perfil = Ejemplo.perfil(activo: false)
        await vm.iniciar()
        igual(vm.estado, .sinSesion, "usuario inactivo no entra")
        verificar(vm.aviso?.contains("desactivado") == true, "avisa que está desactivado")
        verificar(auth.llamadas.contains("cerrarSesion"), "cierra la sesión del inactivo")

        vm.entrar(gg)
        igual(vm.estado, .dentro(gg), "entrar() tras login")
        await vm.cerrarSesion()
        igual(vm.estado, .sinSesion, "cerrar sesión")
    }

    await grupo("SesionViewModel: error de conexión") {
        struct SinRed: LocalizedError { var errorDescription: String? { "No hay conexión" } }
        final class AuthCaido: AuthService, @unchecked Sendable {
            func perfilActual() async throws -> Perfil? { throw SinRed() }
            func iniciarSesion(correo: String, password: String) async throws {}
            func cerrarSesion() async {}
            func enviarCodigo(correo: String) async throws {}
            func verificarCodigo(correo: String, codigo: String) async throws {}
            func cambiarPassword(_ nueva: String) async throws {}
            func marcarPasswordCambiada() async throws {}
        }
        let vm = SesionViewModel(auth: AuthCaido())
        await vm.iniciar()
        igual(vm.estado, .errorConexion("No hay conexión"), "error de conexión con reintento")
    }

    await grupo("LoginViewModel") {
        let auth = AuthFalso()
        var entrada: Perfil?
        let vm = LoginViewModel(auth: auth) { entrada = $0 }
        verificar(!vm.puedeIngresar, "vacío no se puede enviar")
        vm.correo = "  Ana@Correo.com "
        vm.password = "secreto"
        verificar(vm.puedeIngresar, "con datos sí")

        auth.errorAlIniciar = ErrorDePrueba(mensaje: "Correo o contraseña incorrectos.")
        await vm.ingresar()
        igual(vm.error, "Correo o contraseña incorrectos.", "muestra el error del servidor")
        verificar(entrada == nil, "no entra")

        auth.errorAlIniciar = nil
        auth.perfil = Ejemplo.perfil(rol: .gerenteSucursal)
        await vm.ingresar()
        verificar(entrada != nil, "login correcto entra")
        verificar(auth.llamadas.contains("iniciarSesion:ana@correo.com"), "el correo se normaliza")
        igual(vm.password, "", "limpia la contraseña")

        entrada = nil
        auth.perfil = Ejemplo.perfil(activo: false)
        vm.password = "x"
        await vm.ingresar()
        verificar(entrada == nil, "inactivo no entra")
        verificar(vm.error?.contains("desactivado") == true, "avisa desactivado")

        vm.correo = "no-es-correo"
        vm.password = "x"
        await vm.ingresar()
        igual(vm.error, "Escribe un correo válido.", "correo inválido no llama al servidor")
    }

    await grupo("RecuperarPasswordViewModel") {
        let auth = AuthFalso()
        var mensajeFinal: String?
        let vm = RecuperarPasswordViewModel(auth: auth, esperaReenvio: 0) { mensajeFinal = $0 }
        vm.correo = "mal"
        await vm.enviarCodigo()
        igual(vm.paso, .correo, "correo inválido se queda")
        vm.correo = "ana@correo.com"
        await vm.enviarCodigo()
        igual(vm.paso, .codigo, "avanza al código")

        vm.codigo = "12a3456789"
        igual(vm.codigo, "123456", "el código solo admite 6 dígitos")
        auth.errorAlVerificar = ErrorDePrueba(mensaje: "Código incorrecto o vencido.")
        await vm.verificarCodigo()
        igual(vm.error, "Código incorrecto o vencido.", "código incorrecto")
        igual(vm.paso, .codigo, "se queda en código")

        auth.errorAlVerificar = nil
        await vm.verificarCodigo()
        igual(vm.paso, .nueva, "código bueno pasa a nueva contraseña")

        vm.nueva = "corta"
        vm.confirmar = "corta"
        await vm.guardarPassword()
        verificar(vm.error != nil && mensajeFinal == nil, "contraseña corta rechazada")
        vm.nueva = "larga-y-buena"
        vm.confirmar = "otra-distinta"
        await vm.guardarPassword()
        igual(vm.error, "Las contraseñas no coinciden.", "no coinciden")
        vm.confirmar = "larga-y-buena"
        await vm.guardarPassword()
        verificar(mensajeFinal?.contains("actualizada") == true, "termina con aviso de éxito")
        verificar(auth.llamadas.contains("cerrarSesion"), "cierra la sesión temporal de recuperación")
    }

    await grupo("CambioPasswordViewModel") {
        let auth = AuthFalso()
        var termino = false
        let vm = CambioPasswordViewModel(auth: auth, obligatorio: true) { termino = true }
        vm.nueva = "1234567"
        vm.confirmar = "1234567"
        verificar(!vm.puedeGuardar, "7 caracteres no alcanza")
        vm.nueva = "12345678"
        vm.confirmar = "12345678"
        await vm.guardar()
        verificar(termino, "termina")
        verificar(auth.llamadas == ["cambiarPassword", "marcarPasswordCambiada"], "obligatorio marca la contraseña como cambiada: \(auth.llamadas)")

        let auth2 = AuthFalso()
        var termino2 = false
        let vm2 = CambioPasswordViewModel(auth: auth2, obligatorio: false) { termino2 = true }
        vm2.nueva = "12345678"; vm2.confirmar = "12345678"
        await vm2.guardar()
        verificar(termino2 && auth2.llamadas == ["cambiarPassword"], "voluntario no llama a marcar")

        let auth3 = AuthFalso()
        auth3.errorAlCambiar = ErrorDePrueba(mensaje: "La nueva contraseña debe ser distinta de la actual.")
        let vm3 = CambioPasswordViewModel(auth: auth3, obligatorio: true) {}
        vm3.nueva = "12345678"; vm3.confirmar = "12345678"
        await vm3.guardar()
        verificar(vm3.error != nil && !auth3.llamadas.contains("marcarPasswordCambiada"), "si falla el cambio no marca")
    }

    await grupo("PerfilViewModel") {
        let suc = SucursalesFalso()
        suc.sucursales = [Sucursal(id: Ejemplo.sucursalId, nombre: "Centro", direccion: "x", tieneTienda: true, activa: true)]
        let vm = PerfilViewModel(perfil: Ejemplo.perfil(rol: .gerenteSucursal), sucursales: suc)
        await vm.cargar()
        igual(vm.sucursal.valor ?? nil, "Centro", "muestra el nombre de la sucursal")
        let gg = PerfilViewModel(perfil: Ejemplo.perfil(), sucursales: suc)
        await gg.cargar()
        verificar(gg.sucursal.valor != nil && (gg.sucursal.valor ?? "x") == nil, "gerente general sin sucursal")
    }
}
