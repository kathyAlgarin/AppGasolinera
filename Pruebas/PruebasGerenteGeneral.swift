import Foundation

@MainActor
func pruebasGerenteGeneral() async {
    let suc1 = Sucursal(id: Ejemplo.sucursalId, nombre: "Centro", direccion: "San Salvador", tieneTienda: true, activa: true)
    let suc2 = Sucursal(id: Ejemplo.sucursal2Id, nombre: "Aeropuerto", direccion: "Comalapa", tieneTienda: false, activa: true)
    let inactiva = Sucursal(id: UUID(), nombre: "Antigua", direccion: "Santa Ana", tieneTienda: false, activa: false)

    await grupo("SucursalesViewModel") {
        let fake = SucursalesFalso()
        fake.sucursales = [inactiva, suc1, suc2]
        let vm = SucursalesViewModel(servicio: fake)
        await vm.cargar()
        igual(vm.estado.valor?.map(\.nombre) ?? [], ["Aeropuerto", "Centro", "Antigua"], "activas primero, por nombre")
        fake.error = ErrorDePrueba(mensaje: "sin red")
        await vm.cargar()
        verificar(vm.estado.valor != nil, "un error al recargar no borra lo que ya se mostraba... ")
    }

    await grupo("NuevaSucursalViewModel") {
        let fake = SucursalesFalso()
        var creada = false
        let vm = NuevaSucursalViewModel(servicio: fake) { creada = true }
        await vm.crear()
        verificar(!creada && vm.error != nil, "vacío no se envía")
        vm.nombre = "Norte"
        vm.direccion = "Av. Principal"
        for c in Combustible.allCases { vm.capacidades[c] = "10000"; vm.niveles[c] = "2500.5" }
        vm.niveles[.diesel] = "10001"
        verificar(vm.errorNivel(.diesel) != nil, "nivel sobre la capacidad se rechaza")
        verificar(!vm.esValido, "no es válido con un nivel mayor")
        vm.niveles[.diesel] = "0"
        verificar(vm.errorNivel(.diesel) == nil, "nivel 0 es válido")
        vm.niveles[.diesel] = ""
        verificar(vm.errorNivel(.diesel) == nil && vm.nivelInicial(.diesel) == 0, "nivel inicial vacío vale 0")
        vm.niveles[.diesel] = "0"
        vm.capacidades[.regular] = "0"
        verificar(vm.errorCapacidad(.regular) != nil, "capacidad 0 se rechaza")
        vm.capacidades[.regular] = "5000"
        vm.tieneTienda = true
        vm.niveles[.regular] = ""            // vacío = 0
        await vm.crear()
        verificar(creada, "crea")
        igual(fake.ultimoCrear?.3.first { $0.combustible == .regular }?.nivelInicialGal, 0, "el nivel vacío se envía como 0")
        igual(fake.ultimoCrear?.3.count ?? 0, 3, "envía 3 tanques")
        igual(fake.ultimoCrear?.3.first?.combustible, .superior, "orden de combustibles")
        igual(fake.ultimoCrear?.3.first?.nivelInicialGal, Decimal(string: "2500.5"), "nivel inicial")
        igual(fake.ultimoCrear?.2, true, "tiene tienda")
    }

    await grupo("NuevaSucursalViewModel: error del servidor") {
        let fake = SucursalesFalso()
        fake.error = ErrorDePrueba(mensaje: "Ya existe una sucursal con ese nombre.")
        var creada = false
        let vm = NuevaSucursalViewModel(servicio: fake) { creada = true }
        vm.nombre = "Norte"; vm.direccion = "Av. Principal"
        for c in Combustible.allCases { vm.capacidades[c] = "100"; vm.niveles[c] = "10" }
        await vm.crear()
        verificar(!creada, "no cierra la hoja")
        igual(vm.error, "Ya existe una sucursal con ese nombre.", "muestra el mensaje exacto del servidor")
    }

    await grupo("EditarSucursalViewModel") {
        let fake = SucursalesFalso()
        var guardo = false
        let vm = EditarSucursalViewModel(sucursal: suc1, servicio: fake) { guardo = true }
        verificar(!vm.hayCambios, "sin cambios al abrir")
        vm.nombre = "Centro Histórico"
        vm.tieneTienda = false
        vm.activa = false
        await vm.guardar()
        verificar(guardo, "guardó")
        igual(fake.llamadas, ["editar", "configurarTienda:false", "cambiarEstado:false"], "llama solo a lo que cambió, en orden")

        let fake2 = SucursalesFalso()
        fake2.error = ErrorDePrueba(mensaje: "No se puede desactivar la tienda con cajas abiertas.")
        var guardo2 = false
        let vm2 = EditarSucursalViewModel(sucursal: suc1, servicio: fake2) { guardo2 = true }
        vm2.tieneTienda = false
        await vm2.guardar()
        verificar(!guardo2, "no cierra con error")
        igual(vm2.error, "No se puede desactivar la tienda con cajas abiertas.", "mensaje del servidor")

        let vm3 = EditarSucursalViewModel(sucursal: suc1, servicio: fake) {}
        vm3.nombre = " "
        verificar(!vm3.esValido, "nombre vacío no válido")
    }

    await grupo("PreciosViewModel: precio vigente") {
        let s = SucursalesFalso(); s.sucursales = [suc1, suc2]
        let p = PreciosFalso()
        let ahora = Date()
        func precio(_ suc: UUID, _ c: Combustible, _ v: String, hace dias: Double) -> Precio {
            Precio(id: UUID(), sucursalId: suc, combustible: c, precioGal: Decimal(string: v)!,
                   vigenteDesde: ahora.addingTimeInterval(-dias * 86400), creadoPor: nil)
        }
        p.filas = [
            precio(suc1.id, .superior, "3.50", hace: 10),
            precio(suc1.id, .superior, "3.80", hace: 2),
            precio(suc1.id, .superior, "9.99", hace: -3),      // futuro: todavía no vigente
            precio(suc1.id, .regular, "3.20", hace: 5),
            precio(suc2.id, .diesel, "3.00", hace: 1),
        ]
        let vm = PreciosViewModel(sucursales: s, precios: p)
        await vm.cargar()
        igual(vm.sucursalId, suc2.id, "elige la primera por nombre (Aeropuerto)")
        igual(vm.vigente(.diesel)?.precioGal, Decimal(string: "3.00"), "diésel de Aeropuerto")
        igual(vm.combustiblesSinPrecio, [.superior, .regular], "faltan súper y regular")
        vm.sucursalId = suc1.id
        igual(vm.vigente(.superior)?.precioGal, Decimal(string: "3.80"), "vigente = el más reciente que ya empezó")
        igual(vm.combustiblesSinPrecio, [.diesel], "a Centro le falta el diésel")
        igual(vm.historialDeSucursal().count, 4, "historial de la sucursal")
        igual(vm.historialDeSucursal().first?.precioGal, Decimal(string: "9.99"), "historial más reciente primero")
    }

    await grupo("FijarPrecioViewModel") {
        let p = PreciosFalso()
        var ok = false
        let vm = FijarPrecioViewModel(sucursales: [suc1, suc2, inactiva], sucursalActual: suc1.id, servicio: p) { ok = true }
        verificar(!vm.puedeGuardar, "sin precio no se puede guardar")
        vm.precio = "3.756"
        igual(vm.precio, "3.756", "el filtro vive en la vista; el VM solo valida")
        vm.precio = "3.75"
        igual(vm.destino, [suc1.id], "esta sucursal")
        vm.alcance = .todas
        igual(Set(vm.destino), [suc1.id, suc2.id], "todas = solo las activas")
        vm.alcance = .elegir
        vm.alternar(suc2.id)
        igual(Set(vm.destino), [suc1.id, suc2.id], "elegidas")
        vm.alternar(suc1.id)
        igual(vm.destino, [suc2.id], "se desmarca una")
        vm.combustible = .diesel
        await vm.guardar()
        verificar(ok, "guardó")
        igual(p.ultimaLlamada?.1, .diesel, "combustible")
        igual(p.ultimaLlamada?.2, Decimal(string: "3.75"), "precio")
        vm.precio = "0"
        verificar(vm.errorPrecio != nil, "precio 0 se rechaza")
        vm.precio = "3.5"
        vm.alternar(suc2.id)
        verificar(!vm.puedeGuardar, "sin sucursales no se puede guardar")
    }

    await grupo("UsuariosViewModel: filtros") {
        let u = UsuariosFalso()
        let s = SucursalesFalso(); s.sucursales = [suc1, suc2]
        func perfil(_ n: String, _ r: RolUsuario, _ suc: UUID?, activo: Bool = true) -> Perfil {
            Perfil(id: UUID(), correo: "\(n)@x.com", nombre: n, rol: r, sucursalId: suc, activo: activo, debeCambiarPassword: false)
        }
        u.perfiles = [perfil("Zoe", .cajero, suc1.id), perfil("Ana", .gerenteGeneral, nil),
                      perfil("Beto", .gerenteSucursal, suc2.id, activo: false), perfil("Carla", .gerenteSucursal, suc1.id)]
        let vm = UsuariosViewModel(usuarios: u, sucursales: s)
        await vm.cargar()
        igual(vm.filtrados.map(\.nombre), ["Ana", "Carla", "Zoe", "Beto"], "activos primero, por nombre")
        vm.filtroRol = .gerenteSucursal
        igual(vm.filtrados.map(\.nombre), ["Carla", "Beto"], "filtro por rol")
        vm.filtroSucursal = suc1.id
        igual(vm.filtrados.map(\.nombre), ["Carla"], "filtro por rol y sucursal")
        igual(vm.nombreSucursal(suc2.id), "Aeropuerto", "nombre de sucursal")
    }

    await grupo("NuevoUsuarioViewModel: Gerente General") {
        let u = UsuariosFalso()
        var ok = false
        let gg = Ejemplo.perfil()
        let vm = NuevoUsuarioViewModel(creador: gg, sucursales: [suc1, suc2], servicio: u) { ok = true }
        igual(vm.rolesPermitidos, [.gerenteGeneral, .gerenteSucursal, .cajero], "roles que puede crear")
        vm.nombre = "Luis"; vm.correo = "  LUIS@x.com "; vm.passwordTemporal = "temporal123"
        verificar(vm.errorSucursal != nil, "Gerente de Sucursal exige sucursal")
        vm.sucursalId = suc1.id
        vm.rol = .cajero
        igual(vm.sucursalesElegibles.map(\.nombre), ["Centro"], "cajero: solo sucursales con tienda")
        vm.rol = .gerenteGeneral
        verificar(vm.sucursalId == nil && vm.errorSucursal == nil, "Gerente General no lleva sucursal")
        vm.passwordTemporal = "corta"
        verificar(vm.errorPassword != nil, "contraseña corta")
        vm.passwordTemporal = "temporal123"
        await vm.crear()
        verificar(ok, "creó")
        igual(u.ultimoCrear?.0, "luis@x.com", "correo normalizado")
        verificar(u.ultimoCrear?.3 == nil, "sin sucursal para Gerente General")
    }

    await grupo("NuevoUsuarioViewModel: Gerente de Sucursal crea cajeros") {
        let u = UsuariosFalso()
        let gs = Ejemplo.perfil(rol: .gerenteSucursal)
        let vm = NuevoUsuarioViewModel(creador: gs, sucursales: [suc1], servicio: u) {}
        igual(vm.rolesPermitidos, [.cajero], "solo cajeros")
        verificar(vm.esSucursalFija && vm.sucursalId == Ejemplo.sucursalId, "sucursal fija la suya")
        vm.nombre = "Caja Uno"; vm.correo = "caja@x.com"; vm.passwordTemporal = "temporal123"
        await vm.crear()
        igual(u.ultimoCrear?.2, .cajero, "rol cajero")
        igual(u.ultimoCrear?.3, Ejemplo.sucursalId, "en su sucursal")

        u.error = ErrorDePrueba(mensaje: "Ya existe un usuario con ese correo.")
        await vm.crear()
        igual(vm.error, "Ya existe un usuario con ese correo.", "error de correo repetido")
    }

    await grupo("EditarUsuarioViewModel") {
        let u = UsuariosFalso()
        var cambios = 0
        let usuario = Ejemplo.perfil(rol: .gerenteSucursal)
        let vm = EditarUsuarioViewModel(usuario: usuario, servicio: u) { cambios += 1 }
        await vm.restablecer()
        verificar(vm.error != nil && u.llamadas.isEmpty, "contraseña vacía no se envía")
        vm.passwordTemporal = "nueva-temporal"
        await vm.restablecer()
        verificar(vm.aviso?.contains("cambiarla") == true && u.llamadas == ["restablecer"], "restablecer")
        await vm.cambiarActivo(false)
        igual(vm.usuario.activo, false, "se desactiva")
        igual(cambios, 1, "avisa del cambio")
        u.error = ErrorDePrueba(mensaje: "No se puede desactivar al último Gerente General activo.")
        await vm.cambiarActivo(true)
        igual(vm.usuario.activo, false, "si el servidor rechaza, no cambia")
        igual(vm.error, "No se puede desactivar al último Gerente General activo.", "mensaje del servidor")
    }

    await grupo("EditarUsuarioViewModel: cambiar correo") {
        let u = UsuariosFalso()
        var cambios = 0
        let usuario = Ejemplo.perfil(rol: .cajero)
        let vm = EditarUsuarioViewModel(usuario: usuario, servicio: u) { cambios += 1 }
        igual(vm.correoNuevo, usuario.correo, "precarga el correo actual")
        verificar(!vm.hayCambioCorreo, "sin cambios al abrir")
        vm.correoNuevo = "  ANA@Correo.com "
        verificar(!vm.hayCambioCorreo, "mismo correo con otras mayúsculas/espacios no es un cambio")
        vm.correoNuevo = "no-es-correo"
        verificar(vm.errorCorreo != nil, "correo inválido")
        await vm.cambiarCorreo()
        verificar(u.llamadas.isEmpty, "correo inválido no llama al servidor")
        vm.correoNuevo = " Nuevo.Correo@Gmail.com "
        await vm.cambiarCorreo()
        igual(u.llamadas, ["correo:nuevo.correo@gmail.com"], "envía el correo limpio y en minúsculas")
        igual(vm.usuario.correo, "nuevo.correo@gmail.com", "actualiza el usuario en pantalla")
        verificar(vm.aviso?.contains("nuevo.correo@gmail.com") == true && cambios == 1, "avisa y refresca la lista")
        u.error = ErrorDePrueba(mensaje: "Ya existe un usuario con ese correo.")
        vm.correoNuevo = "otro@gmail.com"
        await vm.cambiarCorreo()
        igual(vm.error, "Ya existe un usuario con ese correo.", "mensaje del servidor")
        igual(vm.usuario.correo, "nuevo.correo@gmail.com", "si falla, no cambia")
    }

    await grupo("ArticuloFormViewModel") {
        let c = CatalogoFalso()
        var ok = false
        let vm = ArticuloFormViewModel(articulo: nil, servicio: c) { ok = true }
        verificar(!vm.esValido, "vacío no válido")
        vm.nombre = "Aceite 20W50"; vm.precio = "12.50"
        vm.categoria = .servicios
        igual(vm.tipo, .servicio, "categoría Servicios fuerza tipo Servicio")
        vm.categoria = .lubricantes
        igual(vm.tipo, .producto, "al volver a otra categoría vuelve a Producto")
        await vm.guardar()
        verificar(ok, "guardó")
        igual(c.llamadas, ["crear:Aceite 20W50:lubricantes:producto:12.5"], "alta")

        let existente = Articulo(id: UUID(), nombre: "Lavado", categoria: .servicios, tipo: .servicio, precioUsd: 5, activo: true)
        let ed = ArticuloFormViewModel(articulo: existente, servicio: c) {}
        igual(ed.precio, "5", "precarga el precio")
        ed.categoria = .bebidas
        igual(ed.tipo, .servicio, "al editar, el tipo no cambia")
        ed.precio = "6"
        ed.activo = false
        await ed.guardar()
        igual(c.llamadas.last, "editar:Lavado:6:false", "edición")
    }
}
