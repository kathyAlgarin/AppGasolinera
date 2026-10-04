import Foundation

@MainActor
func pruebasTienda() async {
    let sid = Ejemplo.sucursalId
    let aceite = Articulo(id: UUID(), nombre: "Aceite 20W50", categoria: .lubricantes, tipo: .producto, precioUsd: Decimal(string: "12.5")!, activo: true)
    let agua = Articulo(id: UUID(), nombre: "Agua 500ml", categoria: .bebidas, tipo: .producto, precioUsd: 1, activo: true)
    let lavado = Articulo(id: UUID(), nombre: "Lavado", categoria: .servicios, tipo: .servicio, precioUsd: 5, activo: true)
    func sesion(abierta: Bool, cajero: UUID = UUID()) -> SesionCaja {
        SesionCaja(id: UUID(), sucursalId: sid, cajeroId: cajero, corteId: Ejemplo.corteId, fondoInicialUsd: 20, abiertaEn: Date(), cerradaEn: abierta ? nil : Date(),
                   efectivoContadoUsd: nil, efectivoEsperadoUsd: nil, diferenciaUsd: nil, cierreForzado: false, motivoCierreForzado: nil)
    }
    func venta(_ s: SesionCaja, _ n: Int, estado: EstadoVenta = .completada, total: Decimal = 10, metodo: MetodoPago = .efectivo) -> Venta {
        Venta(id: UUID(), sucursalId: sid, sesionCajaId: s.id, corteId: Ejemplo.corteId, cajeroId: s.cajeroId, numero: n, totalUsd: total, metodoPago: metodo,
              recibidoUsd: nil, vueltoUsd: nil, estado: estado, anuladaEn: nil, motivoAnulacion: nil, creadoEn: Date())
    }

    await grupo("TiendaGerenteViewModel: inventario y ventas") {
        let t = TiendaFalso()
        t.inv = [InventarioSucursal(sucursalId: sid, articuloId: aceite.id, stock: 3, stockMinimo: 5),
                 InventarioSucursal(sucursalId: sid, articuloId: agua.id, stock: 50, stockMinimo: 10)]
        let abierta = sesion(abierta: true), cerrada = sesion(abierta: false)
        t.cajasLista = [CajaDelCorte(sesion: abierta, cajeroNombre: "Luis"), CajaDelCorte(sesion: cerrada, cajeroNombre: "Marta")]
        t.ventasLista = [venta(abierta, 3), venta(abierta, 2, estado: .anulada), venta(cerrada, 1)]
        let c = CatalogoFalso(); c.articulos = [lavado, agua, aceite]
        let vm = TiendaGerenteViewModel(sucursalId: sid, corte: CorteFalso(), tienda: t, catalogo: c)
        await vm.cargar()
        igual(vm.filas.map(\.articulo.nombre), ["Aceite 20W50", "Agua 500ml"], "solo productos; el de stock bajo primero")
        verificar(vm.filas[0].stockBajo && !vm.filas[1].stockBajo, "indicador de stock bajo")
        verificar(vm.hayStockBajo, "hay stock bajo")
        igual(vm.cajasAbiertas.count, 1, "una caja abierta")
        let ventas = vm.ventasDelCorte
        igual(ventas.map(\.venta.numero), [3, 2, 1], "ventas del corte")
        verificar(ventas[0].anulable, "venta completada de una caja abierta se puede anular")
        verificar(!ventas[1].anulable, "una venta ya anulada no")
        verificar(!ventas[2].anulable, "una venta de una caja cerrada es definitiva")
        igual(ventas[0].cajero, "Luis", "nombre del cajero")
        igual(vm.nombre(de: agua.id), "Agua 500ml", "nombre del artículo")
    }

    await grupo("EntradaFormViewModel") {
        let t = TiendaFalso()
        var ok = false
        let vm = EntradaFormViewModel(corteId: Ejemplo.corteId, productos: [aceite, agua], servicio: t) { ok = true }
        verificar(!vm.esValido, "sin cantidad")
        vm.cantidad = "0"
        verificar(vm.errorCantidad != nil, "0 no vale")
        vm.cantidad = "12"
        vm.proveedor = "  Distribuidora X "
        await vm.guardar()
        verificar(ok, "guardó")
        igual(t.llamadas, ["entrada:12:Distribuidora X"], "proveedor recortado")
    }

    await grupo("BajaFormViewModel") {
        let t = TiendaFalso()
        let filas = [TiendaGerenteViewModel.FilaInventario(articulo: aceite, stock: 4, minimo: 2)]
        var ok = false
        let vm = BajaFormViewModel(corteId: Ejemplo.corteId, filas: filas, servicio: t) { ok = true }
        vm.cantidad = "5"
        verificar(vm.errorCantidad?.contains("stock (4)") == true, "no puede superar el stock")
        vm.cantidad = "2"
        verificar(vm.esValido, "vencido no pide nota")
        vm.motivo = .otro
        verificar(vm.errorNota != nil, "«Otro» exige nota")
        vm.nota = "Se cayó de la góndola"
        await vm.guardar()
        verificar(ok, "guardó")
        igual(t.llamadas, ["baja:2:otro:Se cayó de la góndola"], "baja con nota")
    }

    await grupo("StockMinimoViewModel, AnularVentaViewModel y CierreForzadoViewModel") {
        let t = TiendaFalso()
        var guardo = false
        let min = StockMinimoViewModel(fila: .init(articulo: aceite, stock: 1, minimo: 0), servicio: t) { guardo = true }
        min.minimo = "8"
        await min.guardar()
        verificar(guardo && t.llamadas == ["minimo:8"], "fija el stock mínimo")

        let s = sesion(abierta: true)
        var anulo = false
        let an = AnularVentaViewModel(venta: venta(s, 9), servicio: t) { anulo = true }
        verificar(!an.esValido, "motivo obligatorio")
        an.motivo = "Cobro duplicado"
        await an.anular()
        verificar(anulo && t.llamadas.last == "anular:Cobro duplicado", "anula con motivo")
        t.error = ErrorDePrueba(mensaje: "La caja de esta venta ya está cerrada: la venta es definitiva.")
        await an.anular()
        igual(an.error, "La caja de esta venta ya está cerrada: la venta es definitiva.", "error del servidor")

        t.error = nil
        var cerro = false
        let cf = CierreForzadoViewModel(caja: CajaDelCorte(sesion: s, cajeroNombre: "Luis"), servicio: t) { cerro = true }
        cf.contado = "75.50"
        verificar(cf.errorMotivo != nil && !cf.esValido, "motivo obligatorio")
        cf.motivo = "Cajero se fue sin cerrar"
        await cf.cerrar()
        verificar(cerro && cf.resultado != nil, "cerró")
        igual(t.llamadas.last, "forzado:75.5:Cajero se fue sin cerrar", "cierre forzado")
    }

    await grupo("CajaViewModel: resumen de la caja abierta") {
        let c = CajaFalso()
        let vm = CajaViewModel(servicio: c)
        await vm.cargar()
        verificar(vm.sesion == nil, "sin caja abierta")
        let s = sesion(abierta: true)
        c.sesion = s
        c.ventasLista = [venta(s, 1, total: 10, metodo: .efectivo), venta(s, 2, total: 6, metodo: .tarjeta), venta(s, 3, estado: .anulada, total: 99)]
        await vm.cargar()
        igual(vm.completadas.count, 2, "las anuladas no cuentan")
        igual(vm.totalVendido, 16, "total vendido")
        igual(vm.totalEfectivo, 10, "solo efectivo")
        igual(vm.efectivoEsperadoReferencia, 30, "fondo 20 + efectivo 10")
    }

    await grupo("AbrirCajaViewModel") {
        let c = CajaFalso()
        var abrio = false
        let vm = AbrirCajaViewModel(servicio: c) { abrio = true }
        await vm.abrir()
        verificar(!abrio && vm.error != nil, "sin fondo no abre")
        vm.fondo = "0"
        await vm.abrir()
        verificar(abrio && c.llamadas == ["abrir:0"], "fondo 0 es válido")
        c.error = ErrorDePrueba(mensaje: "Ya tienes una caja abierta.")
        await vm.abrir()
        igual(vm.error, "Ya tienes una caja abierta.", "error del servidor")
    }

    await grupo("PosViewModel: catálogo y carrito") {
        let c = CajaFalso()
        c.articulos = [ArticuloPOS(articulo: aceite, stock: 3), ArticuloPOS(articulo: agua, stock: 0), ArticuloPOS(articulo: lavado, stock: nil)]
        let vm = PosViewModel(servicio: c)
        await vm.cargar()
        igual(vm.filtrados.count, 3, "todo el catálogo")
        igual(vm.categoriasDisponibles, [.lubricantes, .bebidas, .servicios], "categorías con artículos")
        vm.categoria = .bebidas
        igual(vm.filtrados.map(\.articulo.nombre), ["Agua 500ml"], "filtra por categoría")
        vm.categoria = nil
        vm.busqueda = "ACEITE"
        igual(vm.filtrados.count, 1, "búsqueda sin distinguir mayúsculas")
        vm.busqueda = ""

        let a = vm.articulos[0]
        for _ in 0..<5 { vm.agregar(a) }
        igual(vm.cantidad(de: a), 3, "no pasa del stock")
        vm.agregar(vm.articulos[1])
        igual(vm.cantidad(de: vm.articulos[1]), 0, "sin stock no se agrega")
        for _ in 0..<4 { vm.agregar(vm.articulos[2]) }
        igual(vm.cantidad(de: vm.articulos[2]), 4, "los servicios no tienen límite")
        igual(vm.unidades, 7, "unidades")
        igual(vm.total, Decimal(string: "57.5")!, "total del carrito (3 × 12.50 + 4 × 5)")
        vm.cambiar(a, delta: -1)
        igual(vm.cantidad(de: a), 2, "resta")
        vm.cambiar(a, delta: -5)
        igual(vm.cantidad(de: a), 0, "no baja de 0 y se quita")
        igual(vm.lineasParaEnviar.count, 1, "solo lo que está en el carrito")
        vm.vaciar()
        verificar(vm.carritoVacio, "vaciar")
    }

    await grupo("PosViewModel: el stock cambia mientras tanto") {
        let c = CajaFalso()
        c.articulos = [ArticuloPOS(articulo: aceite, stock: 5)]
        let vm = PosViewModel(servicio: c)
        await vm.cargar()
        for _ in 0..<5 { vm.agregar(vm.articulos[0]) }
        c.articulos = [ArticuloPOS(articulo: aceite, stock: 2)]
        await vm.cargar()
        igual(vm.cantidad(de: vm.articulos[0]), 2, "el carrito se ajusta al stock nuevo")
        c.articulos = [ArticuloPOS(articulo: aceite, stock: 0)]
        await vm.cargar()
        verificar(vm.carritoVacio, "sin stock sale del carrito")
    }

    await grupo("CobroViewModel: efectivo, vuelto y animación") {
        let c = CajaFalso()
        let linea = PosViewModel.LineaCarrito(articulo: ArticuloPOS(articulo: aceite, stock: 3), cantidad: 1)
        let vm = CobroViewModel(sesionId: UUID(), total: Decimal(string: "12.5")!, lineas: [linea], servicio: c, duracionAnimacion: 0)
        verificar(!vm.puedePagar, "efectivo sin monto")
        vm.recibido = "10"
        verificar(!vm.puedePagar, "recibido menor que el total")
        igual(vm.faltante, Decimal(string: "2.5"), "falta 2.50")
        verificar(vm.vueltoPrevio == nil, "sin vuelto")
        vm.recibido = "20"
        verificar(vm.puedePagar, "recibido mayor")
        igual(vm.vueltoPrevio, Decimal(string: "7.5"), "vuelto en pantalla")
        vm.pagarExacto()
        igual(vm.recibido, "12.5", "pagar exacto")
        igual(vm.vueltoPrevio, 0, "sin vuelto al pagar exacto")
        vm.recibido = "20"
        await vm.pagar()
        if case .exito(let r) = vm.fase { igual(r.numero, 7, "ticket del servidor") } else { verificar(false, "debía terminar con éxito") }
        igual(c.ultimaVenta?.0, .efectivo, "método enviado")
        igual(c.ultimaVenta?.1, 20, "recibido enviado")
        igual(c.ultimaVenta?.2.count ?? 0, 1, "líneas enviadas")
    }

    await grupo("CobroViewModel: tarjeta simulada y errores") {
        let c = CajaFalso()
        let linea = PosViewModel.LineaCarrito(articulo: ArticuloPOS(articulo: lavado, stock: nil), cantidad: 2)
        let vm = CobroViewModel(sesionId: UUID(), total: 10, lineas: [linea], servicio: c, duracionAnimacion: 0)
        vm.metodo = .tarjeta
        verificar(vm.puedePagar, "tarjeta no pide monto")
        verificar(vm.vueltoPrevio == nil && vm.faltante == nil, "tarjeta sin vuelto")
        await vm.pagar()
        verificar(c.ultimaVenta?.1 == nil, "con tarjeta no se envía monto recibido")
        igual(c.ultimaVenta?.0, .tarjeta, "método tarjeta")

        let c2 = CajaFalso()
        c2.errorVenta = ErrorDePrueba(mensaje: "Stock insuficiente de Aceite 20W50.")
        let vm2 = CobroViewModel(sesionId: UUID(), total: 10, lineas: [linea], servicio: c2, duracionAnimacion: 0)
        vm2.recibido = "10"
        await vm2.pagar()
        igual(vm2.fase, .editando, "si el servidor rechaza, vuelve a editar")
        igual(vm2.error, "Stock insuficiente de Aceite 20W50.", "mensaje exacto del servidor")
    }

    await grupo("MisVentasViewModel y CerrarCajaViewModel") {
        let c = CajaFalso()
        let s = sesion(abierta: true)
        c.sesion = s
        c.ventasLista = [venta(s, 1)]
        c.articulos = [ArticuloPOS(articulo: aceite, stock: 1)]
        let vm = MisVentasViewModel(servicio: c)
        await vm.cargar()
        igual(vm.estado.valor?.ventas.count ?? 0, 1, "mis ventas")
        igual(vm.nombre(de: aceite.id), "Aceite 20W50", "nombre de artículo")
        c.sesion = nil
        let vacio = MisVentasViewModel(servicio: c)
        await vacio.cargar()
        igual(vacio.estado.valor?.ventas.count ?? -1, 0, "sin caja abierta no hay ventas")

        var cerro = false
        let cc = CerrarCajaViewModel(sesion: s, servicio: c) { cerro = true }
        verificar(!cc.esValido, "sin efectivo contado")
        cc.contado = "70"
        await cc.cerrar()
        verificar(cerro && cc.resultado?.diferenciaUsd == 0, "cierre con resultado del servidor")
        verificar(!cc.esValido, "ya cerrada: no se cierra otra vez")
    }

    await grupo("TiendaYCajasViewModel") {
        let suc1 = Sucursal(id: sid, nombre: "Centro", direccion: "x", tieneTienda: true, activa: true)
        let suc2 = Sucursal(id: Ejemplo.sucursal2Id, nombre: "Aeropuerto", direccion: "y", tieneTienda: false, activa: true)
        let s = SucursalesFalso(); s.sucursales = [suc1, suc2]
        let d = DashboardFalso()
        let ahora = Fechas.fecha(deDia: "2026-10-05")!.addingTimeInterval(12 * 3600)
        d.cajas = [TiendaCaja(sesionId: UUID(), sucursalId: sid, cajeroId: UUID(), cajeroNombre: "Luis", fechaOperativa: "2026-10-05", abiertaEn: ahora, cerradaEn: ahora,
                              fondoInicialUsd: 20, efectivoEsperadoUsd: 50, efectivoContadoUsd: 48, diferenciaUsd: -2, cierreForzado: true),
                   TiendaCaja(sesionId: UUID(), sucursalId: sid, cajeroId: UUID(), cajeroNombre: "Marta", fechaOperativa: nil, abiertaEn: ahora, cerradaEn: nil,
                              fondoInicialUsd: 20, efectivoEsperadoUsd: nil, efectivoContadoUsd: nil, diferenciaUsd: nil, cierreForzado: false)]
        d.anulaciones = [TiendaAnulacion(sucursalId: sid, fechaOperativa: "2026-10-05", ventasAnuladas: 3, totalUsd: 21)]
        let vm = TiendaYCajasViewModel(dashboard: d, sucursales: s, ahora: { ahora })
        await vm.cargar()
        igual(vm.estado.valor?.sucursales.map(\.nombre) ?? [], ["Centro"], "solo sucursales con tienda")
        igual(vm.cajasConDiferencia, 1, "una con diferencia")
        igual(vm.cajasForzadas, 1, "una forzada")
        igual(vm.cajasAbiertas, 1, "una abierta")
        igual(vm.anulacionesPorSucursal.first?.ventas, 3, "anulaciones por sucursal")
        igual(vm.anulacionesPorSucursal.first?.sucursal, "Centro", "nombre de sucursal")
    }
}
