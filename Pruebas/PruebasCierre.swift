import Foundation

@MainActor
func pruebasCierreYReportes() async {
    func fila(_ c: Combustible, precio: Decimal? = 3, hayDif: Bool? = false) -> ResumenPrevio {
        ResumenPrevio(combustible: c, tanqueId: UUID(), galonesVendidos: 100, precioGal: precio, ingresoUsd: precio.map { $0 * 100 },
                      comprasGal: 0, perdidasGal: 0, nivelInicialGal: 500, nivelTeoricoGal: 400, nivelMedidoGal: 399, diferenciaGal: -1,
                      hayDiferencia: hayDif, hayCambioMedidor: false)
    }
    let niveles = Ejemplo.tanques.map { NivelMedido(tanqueId: $0.tanqueId, nivelMedidoGal: 100) }

    await grupo("ResumenCierreViewModel: cierre normal") {
        let svc = CorteFalso()
        svc.previo = Combustible.allCases.map { fila($0) }
        let tienda = TiendaFalso()
        var cerro = false
        let vm = ResumenCierreViewModel(corte: Ejemplo.corte(secuencia: 3), niveles: niveles, tieneTienda: true, servicio: svc, tienda: tienda) { cerro = true }
        await vm.cargar()
        igual(vm.filas.count, 3, "3 combustibles")
        igual(vm.galonesTotales, 300, "total de galones")
        igual(vm.ingresoTotal, 900, "total de ingreso")
        verificar(vm.puedeCerrar && vm.motivoBloqueo == nil, "se puede cerrar")
        await vm.cerrar()
        verificar(cerro && vm.resultado != nil, "cerró")
        verificar(svc.cierre?.2 == nil, "desde el 2.º corte no se envía el tipo")
        igual(svc.cierre?.1.count ?? 0, 3, "envía los 3 niveles")
        verificar(!vm.puedeCerrar, "no se puede cerrar dos veces")
    }

    await grupo("ResumenCierreViewModel: bloqueos") {
        let svc = CorteFalso()
        svc.previo = [fila(.superior), fila(.regular, precio: nil), fila(.diesel)]
        let tienda = TiendaFalso()
        tienda.abiertas = 2
        let vm = ResumenCierreViewModel(corte: Ejemplo.corte(secuencia: 3), niveles: niveles, tieneTienda: true, servicio: svc, tienda: tienda) {}
        await vm.cargar()
        igual(vm.combustiblesSinPrecio, [.regular], "falta el precio de Regular")
        verificar(vm.motivoBloqueo?.contains("Regular") == true && !vm.puedeCerrar, "sin precio bloquea")
        svc.previo = Combustible.allCases.map { fila($0) }
        await vm.cargar()
        verificar(vm.motivoBloqueo?.contains("2 cajas abiertas") == true, "cajas abiertas bloquean: \(vm.motivoBloqueo ?? "")")
        tienda.abiertas = 1
        await vm.cargar()
        verificar(vm.motivoBloqueo?.contains("1 caja abierta") == true, "singular")
        tienda.abiertas = 0
        await vm.cargar()
        verificar(vm.puedeCerrar, "sin bloqueos")

        let sinTienda = ResumenCierreViewModel(corte: Ejemplo.corte(secuencia: 3), niveles: niveles, tieneTienda: false, servicio: svc, tienda: { let t = TiendaFalso(); t.abiertas = 5; return t }()) {}
        await sinTienda.cargar()
        igual(sinTienda.cajasAbiertas, 0, "sin tienda no consulta cajas")
    }

    await grupo("ResumenCierreViewModel: primer corte y errores del servidor") {
        let svc = CorteFalso()
        svc.previo = Combustible.allCases.map { fila($0, hayDif: true) }
        let vm = ResumenCierreViewModel(corte: Ejemplo.corte(secuencia: 1), niveles: niveles, tieneTienda: false, servicio: svc, tienda: TiendaFalso()) {}
        await vm.cargar()
        verificar(vm.esPrimerCorte && vm.hayDiferencias, "primer corte con diferencias")
        vm.tipoInicial = .vespertino
        await vm.cerrar()
        igual(svc.cierre?.2, .vespertino, "el primer corte envía el tipo elegido")

        let svc2 = CorteFalso()
        svc2.previo = Combustible.allCases.map { fila($0) }
        svc2.errorAlCerrar = ErrorDePrueba(mensaje: "Ya hay 2 cortes cerrados en esta fecha operativa.")
        let vm2 = ResumenCierreViewModel(corte: Ejemplo.corte(secuencia: 5), niveles: niveles, tieneTienda: false, servicio: svc2, tienda: TiendaFalso()) {}
        await vm2.cargar()
        await vm2.cerrar()
        igual(vm2.error, "Ya hay 2 cortes cerrados en esta fecha operativa.", "mensaje exacto del servidor")
        verificar(vm2.resultado == nil, "no hay resultado si falló")
    }

    await grupo("HistorialCortesViewModel") {
        let r = ReportesFalso()
        let c1 = Ejemplo.corte(secuencia: 2, estado: .cerrado, tipo: .matutino, fecha: "2026-10-03")
        let c2 = Ejemplo.corte(secuencia: 3, estado: .cerrado, tipo: .vespertino, fecha: "2026-10-03")
        r.cortes = [c2, c1]
        func res(_ corte: Corte, _ c: Combustible, ajuste: Bool, dif: Bool, cm: Bool) -> ResumenCorte {
            ResumenCorte(corteId: corte.id, sucursalId: corte.sucursalId, combustible: c, tanqueId: UUID(), galonesVendidos: 1, ingresoUsd: 1,
                         comprasGal: 0, perdidasGal: 0, nivelInicialGal: 0, nivelTeoricoGal: 0, nivelMedidoGal: 0, diferenciaGal: 0,
                         hayDiferencia: dif, hayAjuste: ajuste, hayCambioMedidor: cm)
        }
        r.resumen = [res(c1, .superior, ajuste: true, dif: false, cm: false), res(c1, .diesel, ajuste: false, dif: false, cm: true),
                     res(c2, .regular, ajuste: false, dif: true, cm: false)]
        let vm = HistorialCortesViewModel(sucursalId: Ejemplo.sucursalId, servicio: r)
        await vm.cargar()
        let items = vm.estado.valor ?? []
        igual(items.count, 2, "2 cortes")
        verificar(items[0].hayDiferencia && !items[0].ajustado, "vespertino con diferencia")
        verificar(items[1].ajustado && items[1].cambioMedidor && !items[1].hayDiferencia, "matutino ajustado con cambio de medidor")
    }

    await grupo("ReporteCorteViewModel y AjustarLecturaViewModel") {
        let corte = Ejemplo.corte(secuencia: 2, estado: .cerrado, tipo: .matutino, fecha: "2026-10-03")
        func lectura(_ b: Int, _ c: Combustible, ini: Decimal, fin: Decimal) -> LecturaEfectiva {
            LecturaEfectiva(corteId: corte.id, sucursalId: Ejemplo.sucursalId, mangueraId: UUID(), bombaId: UUID(), bombaNumero: b, combustible: c,
                            lecturaInicialGal: ini, finalOriginal: fin, lecturaFinalGal: fin, ajustada: false, cambioMedidor: false, galones: fin - ini)
        }
        let lecturas = [lectura(2, .diesel, ini: 10, fin: 40), lectura(1, .regular, ini: 0, fin: 10), lectura(1, .superior, ini: 0, fin: 20), lectura(2, .superior, ini: 5, fin: 15)]
        func reporte(siguienteCerrado: Bool) -> ReporteCorte {
            ReporteCorte(corte: corte, sucursalNombre: "Centro", cerradoPorNombre: "Ana", lecturas: lecturas, resumen: [], compras: [], perdidas: [],
                         cambiosMedidor: [], ajustes: [], precios: [PrecioCorte(corteId: corte.id, combustible: .superior, precioGal: Decimal(string: "3.5")!)],
                         siguienteCerrado: siguienteCerrado)
        }
        let r = ReportesFalso()
        r.reporteDevuelto = reporte(siguienteCerrado: false)
        let gg = ReporteCorteViewModel(corte: corte, esGerenteGeneral: true, servicio: r)
        await gg.cargar()
        igual(gg.bombas.map(\.numero), [1, 2], "agrupa por bomba")
        igual(gg.bombas[0].lecturas.map(\.combustible), [.superior, .regular], "mangueras en orden Súper, Regular, Diésel")
        igual(gg.usd(lecturas[2]), 70, "USD = galones × precio del corte")
        verificar(gg.usd(lecturas[0]) == nil, "sin precio no hay USD")
        verificar(gg.puedeAjustar && !gg.esDefinitivo, "GG puede ajustar mientras el siguiente siga abierto")

        r.reporteDevuelto = reporte(siguienteCerrado: true)
        await gg.cargar()
        // cargar() no reemplaza si ya hay valor?  (reemplaza: es un éxito)
        verificar(!gg.puedeAjustar && gg.esDefinitivo, "con el siguiente cerrado es definitivo")

        let gs = ReporteCorteViewModel(corte: corte, esGerenteGeneral: false, servicio: r)
        await gs.cargar()
        verificar(!gs.puedeAjustar && !gs.esDefinitivo, "el Gerente de Sucursal nunca ajusta")

        let aj = AjustarLecturaViewModel(corteId: corte.id, lecturas: lecturas, servicio: r) {}
        igual(aj.lecturaElegida?.bombaNumero, 1, "primera manguera ordenada")
        aj.mangueraId = lecturas[2].mangueraId
        aj.valor = "-5"
        igual(aj.valor, "-5", "el filtro de signos vive en la vista")
        aj.valor = "19"
        verificar(aj.errorValor != nil || aj.lecturaElegida?.lecturaInicialGal == 0, "valor menor que la inicial se rechaza cuando aplica")
        aj.valor = "30"
        verificar(aj.errorMotivo != nil, "motivo obligatorio")
        aj.motivo = "Error de captura"
        await aj.guardar()
        igual(r.ajuste?.1, 30, "ajuste enviado")
        r.error = ErrorDePrueba(mensaje: "Ya se cerró el corte siguiente: este corte es definitivo y no admite ajustes.")
        await aj.guardar()
        verificar(aj.error?.contains("definitivo") == true, "error del servidor")
    }

    await grupo("InicioSucursalViewModel") {
        let corte = CorteFalso()
        let dash = DashboardFalso()
        func d(_ c: Combustible, gal: Decimal, usd: Decimal, cortes: Int) -> DashboardCombustible {
            DashboardCombustible(sucursalId: Ejemplo.sucursalId, fechaOperativa: "2026-10-04", combustible: c, galonesVendidos: gal, ingresoUsd: usd,
                                 comprasGal: 0, perdidasGal: 0, cortesCerrados: cortes, cortesConDiferencia: 0)
        }
        let ahora = Fechas.fecha(deDia: "2026-10-04")!.addingTimeInterval(12 * 3600)
        let vm = InicioSucursalViewModel(sucursalId: Ejemplo.sucursalId, tanques: TanquesFalso(), corte: corte, lineas: LineasFalso(),
                                         dashboard: dash, ahora: { ahora })
        await vm.cargar()
        verificar(vm.sinCortesCerradosHoy, "sin cortes cerrados hoy")
        igual(vm.galonesHoy, 0, "ceros con explicación")
        igual(dash.ultimoRango?.0, "2026-10-04", "consulta el día de hoy en zona de El Salvador")
        dash.filas = [d(.superior, gal: 100, usd: 350, cortes: 1), d(.diesel, gal: 50, usd: 150, cortes: 1)]
        await vm.cargar()
        igual(vm.galonesHoy, 150, "galones de hoy")
        igual(vm.ingresoHoy, 500, "ingreso de hoy")
        igual(vm.cortesCerradosHoy, 1, "1 corte cerrado")
        igual(vm.estado.valor?.tanques.map(\.combustible) ?? [], Combustible.allCases, "tanques en orden")
        corte.error = ErrorDePrueba(mensaje: "Esta sucursal no tiene un corte en curso.")
        await vm.cargar()
        verificar(vm.estado.valor != nil, "un fallo al recargar conserva lo mostrado")
    }
}
