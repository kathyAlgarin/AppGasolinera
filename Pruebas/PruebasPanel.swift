import Foundation

@MainActor
func pruebasPanel() async {
    let suc1 = Sucursal(id: Ejemplo.sucursalId, nombre: "Centro", direccion: "x", tieneTienda: true, activa: true)
    let suc2 = Sucursal(id: Ejemplo.sucursal2Id, nombre: "Aeropuerto", direccion: "y", tieneTienda: false, activa: true)
    let sucInactiva = Sucursal(id: UUID(), nombre: "Antigua", direccion: "z", tieneTienda: false, activa: false)
    // 2026-10-05 12:00 en El Salvador
    let ahora = Fechas.fecha(deDia: "2026-10-05")!.addingTimeInterval(12 * 3600)

    func fila(_ s: Sucursal, _ dia: String, _ c: Combustible, gal: Decimal, usd: Decimal, comp: Decimal = 0, perd: Decimal = 0) -> DashboardCombustible {
        DashboardCombustible(sucursalId: s.id, fechaOperativa: dia, combustible: c, galonesVendidos: gal, ingresoUsd: usd,
                             comprasGal: comp, perdidasGal: perd, cortesCerrados: 1, cortesConDiferencia: 0)
    }
    func corte(_ s: Sucursal, _ dia: String) -> Corte {
        Corte(id: UUID(), sucursalId: s.id, secuencia: 2, estado: .cerrado, abiertoEn: ahora, cerradoEn: ahora, cerradoPor: nil, tipo: .matutino,
              fechaOperativa: dia)
    }
    func panel(_ dash: DashboardFalso, _ rep: ReportesFalso = ReportesFalso(), tanques: TanquesFalso = TanquesFalso()) -> PanelViewModel {
        let s = SucursalesFalso()
        s.sucursales = [suc1, suc2, sucInactiva]
        return PanelViewModel(sucursales: s, dashboard: dash, tanques: tanques, reportes: rep, ahora: { ahora })
    }

    await grupo("PanelViewModel: periodos") {
        let vm = panel(DashboardFalso())
        igual(vm.rango.desde, "2026-10-05", "hoy: desde")
        igual(vm.rango.hasta, "2026-10-05", "hoy: hasta")
        vm.periodo = .sieteDias
        igual(vm.rango.desde, "2026-09-29", "7 días: incluye hoy y 6 anteriores")
        igual(vm.dias.count, 7, "7 días")
        vm.periodo = .treintaDias
        igual(vm.rango.desde, "2026-09-06", "30 días")
        igual(vm.dias.count, 30, "30 días")
        vm.periodo = .personalizado
        vm.desdePersonalizado = Fechas.fecha(deDia: "2026-10-01")!
        vm.hastaPersonalizado = Fechas.fecha(deDia: "2026-10-20")!      // futuro: se recorta a hoy
        igual(vm.rango.hasta, "2026-10-05", "el personalizado no llega al futuro")
        igual(vm.dias.count, 5, "del 1 al 5 de octubre")
        vm.desdePersonalizado = Fechas.fecha(deDia: "2026-10-10")!       // desde > hasta: se corrige
        verificar(vm.rango.desde <= vm.rango.hasta, "el rango nunca se invierte")
    }

    await grupo("PanelViewModel: sin sucursales activas no es lo mismo que sin cortes") {
        let s = SucursalesFalso(); s.sucursales = []
        let vacio = PanelViewModel(sucursales: s, dashboard: DashboardFalso(), tanques: TanquesFalso(), reportes: ReportesFalso(), ahora: { ahora })
        verificar(!vacio.sinSucursales, "antes de cargar no se afirma nada")
        await vacio.cargar()
        verificar(vacio.sinSucursales, "sin sucursales")
        s.sucursales = [sucInactiva]
        await vacio.cargar()
        verificar(vacio.sinSucursales, "solo hay una inactiva: tampoco hay datos")
        s.sucursales = [suc1]
        await vacio.cargar()
        verificar(!vacio.sinSucursales, "con una sucursal activa ya hay datos que mostrar (aunque sin cortes)")
    }

    await grupo("PanelViewModel: sin cortes cerrados") {
        let dash = DashboardFalso()
        let vm = panel(dash)
        await vm.cargar()
        verificar(vm.sinCortesCerrados, "sin cortes cerrados")
        igual(vm.textoSinCortes, "Sin cortes cerrados hoy", "texto de hoy")
        igual(vm.galonesTotales, 0, "ceros")
        igual(vm.cortesEsperados, 4, "2 cortes × 2 sucursales activas (la inactiva no cuenta)")
        igual(vm.sucursalesSinCorteHoy.map(\.nombre), ["Aeropuerto", "Centro"], "ambas sin corte hoy")
        vm.periodo = .sieteDias
        igual(vm.textoSinCortes, "Sin cortes cerrados en este periodo", "texto de periodo")
        igual(vm.cortesEsperados, 28, "2 × 7 días × 2 sucursales")
    }

    await grupo("PanelViewModel: totales, tendencia y ranking") {
        let dash = DashboardFalso()
        dash.filas = [
            fila(suc1, "2026-10-05", .superior, gal: 100, usd: 350, comp: 500, perd: 2),
            fila(suc1, "2026-10-05", .diesel, gal: 40, usd: 120),
            fila(suc2, "2026-10-05", .superior, gal: 300, usd: 1050),
            fila(suc2, "2026-10-04", .superior, gal: 10, usd: 35),
        ]
        dash.cortes = [corte(suc1, "2026-10-05"), corte(suc2, "2026-10-05"), corte(suc2, "2026-10-04")]
        dash.cortesFiltro()
        let vm = panel(dash)
        vm.periodo = .sieteDias
        await vm.cargar()
        igual(vm.galonesTotales, 450, "galones totales")
        igual(vm.ingresoTotal, 1555, "ingreso total")
        let sup = vm.totales.first { $0.combustible == .superior }!
        igual(sup.galones, 410, "súper")
        igual(sup.compras, 500, "compras de súper")
        igual(sup.perdidas, 2, "pérdidas de súper")
        igual(vm.ranking.map(\.sucursal.nombre), ["Aeropuerto", "Centro"], "ranking por galones")
        igual(vm.ranking.first?.galones, 310, "galones de Aeropuerto")
        let t = vm.tendencia
        igual(t.count, 7 * 3, "7 días × 3 combustibles")
        igual(t.first { $0.dia == "2026-10-05" && $0.combustible == .superior }?.galones, 400, "tendencia del 5 de octubre")
        igual(t.first { $0.dia == "2026-10-01" && $0.combustible == .superior }?.galones, 0, "días sin datos en cero")
        igual(vm.cortesCerrados, 3, "cortes con datos")
        verificar(!vm.sinCortesCerrados, "hay cortes")
        // Con la sucursal 2 solamente: el ranking solo muestra esa sucursal.
        vm.sucursalId = suc2.id
        igual(vm.ranking.map(\.sucursal.nombre), ["Aeropuerto"], "filtro de sucursal")
    }

    await grupo("PanelViewModel: sucursales sin corte hoy y tanques críticos") {
        let dash = DashboardFalso()
        dash.cortes = [corte(suc1, "2026-10-05")]
        let tanques = TanquesFalso()
        func t(_ s: Sucursal, _ c: Combustible, _ pct: Decimal, _ e: NivelAlerta) -> EstadoTanque {
            EstadoTanque(tanqueId: UUID(), sucursalId: s.id, combustible: c, capacidadGal: 1000, nivelEstimadoGal: pct * 10, porcentaje: pct,
                         nCompras: 0, nPerdidas: 0, baseEn: nil, autonomiaDias: nil, autonomiaDisponible: false, estado: e)
        }
        tanques.lista = [t(suc1, .superior, 15, .critico), t(suc2, .diesel, 5, .critico), t(suc2, .regular, 40, .medio), t(suc1, .regular, 90, .optimo)]
        let vm = panel(dash, tanques: tanques)
        await vm.cargar()
        igual(vm.sucursalesSinCorteHoy.map(\.nombre), ["Aeropuerto"], "Aeropuerto no cerró hoy")
        igual(vm.tanquesCriticos.map(\.porcentaje), [5, 15], "críticos, el más bajo primero")
        let det = vm.detalle(de: .diesel)
        igual(det.count, 2, "detalle por sucursal")
        igual(det.first { $0.sucursal.id == suc2.id }?.tanque?.estado, .critico, "tanque de diésel en Aeropuerto")
    }

    await grupo("PanelViewModel: cortes con diferencia (distintos, no por combustible)") {
        let dash = DashboardFalso()
        let c1 = corte(suc1, "2026-10-05"), c2 = corte(suc2, "2026-10-05")
        dash.cortes = [c1, c2]
        let rep = ReportesFalso()
        func res(_ c: Corte, _ comb: Combustible, _ dif: Bool) -> ResumenCorte {
            ResumenCorte(corteId: c.id, sucursalId: c.sucursalId, combustible: comb, tanqueId: UUID(), galonesVendidos: 1, ingresoUsd: 1, comprasGal: 0,
                         perdidasGal: 0, nivelInicialGal: 0, nivelTeoricoGal: 0, nivelMedidoGal: 0, diferenciaGal: 0, hayDiferencia: dif, hayAjuste: false, hayCambioMedidor: false)
        }
        rep.resumen = [res(c1, .superior, true), res(c1, .regular, true), res(c1, .diesel, true), res(c2, .superior, false)]
        let vm = panel(dash, rep)
        await vm.cargar()
        igual(vm.datos?.cortesConDiferencia, 1, "un solo corte con diferencia aunque 3 combustibles difieran")
    }

    await grupo("PanelViewModel: bloque de tienda") {
        let dash = DashboardFalso()
        dash.ingresos = [TiendaIngreso(sucursalId: suc1.id, fechaOperativa: "2026-10-05", categoria: .bebidas, unidades: 10, ingresoUsd: 25),
                         TiendaIngreso(sucursalId: suc1.id, fechaOperativa: "2026-10-05", categoria: .lubricantes, unidades: 2, ingresoUsd: 40)]
        dash.anulaciones = [TiendaAnulacion(sucursalId: suc1.id, fechaOperativa: "2026-10-05", ventasAnuladas: 2, totalUsd: 7)]
        func caja(_ dif: Decimal?, forzado: Bool) -> TiendaCaja {
            TiendaCaja(sesionId: UUID(), sucursalId: suc1.id, cajeroId: UUID(), cajeroNombre: "Luis", fechaOperativa: "2026-10-05", abiertaEn: ahora,
                       cerradaEn: ahora, fondoInicialUsd: 20, efectivoEsperadoUsd: 50, efectivoContadoUsd: 50, diferenciaUsd: dif, cierreForzado: forzado)
        }
        dash.cajas = [caja(0, forzado: false), caja(-2, forzado: false), caja(1, forzado: true)]
        dash.stock = [StockBajo(sucursalId: suc1.id, articuloId: UUID(), nombre: "Aceite", categoria: .lubricantes, stock: 1, stockMinimo: 5)]
        let vm = panel(dash)
        await vm.cargar()
        igual(vm.ingresoTienda, 65, "ingreso total de tienda")
        igual(vm.ingresoTiendaPorCategoria.map(\.categoria), [.lubricantes, .bebidas], "por categoría en orden")
        igual(vm.ventasAnuladas, 2, "anulaciones")
        igual(vm.totalAnulado, 7, "total anulado")
        igual(vm.cajasConDiferencia, 2, "cajas con diferencia")
        igual(vm.cajasForzadas, 1, "cierres forzados")
        verificar(vm.hayActividadTienda, "hay actividad")
    }

    await grupo("DetalleSucursalViewModel") {
        let u = UsuariosFalso()
        u.perfiles = [
            Perfil(id: UUID(), correo: "a@x.com", nombre: "Gerente Viejo", rol: .gerenteSucursal, sucursalId: suc1.id, activo: false, debeCambiarPassword: false),
            Perfil(id: UUID(), correo: "b@x.com", nombre: "Gerente Actual", rol: .gerenteSucursal, sucursalId: suc1.id, activo: true, debeCambiarPassword: false),
            Perfil(id: UUID(), correo: "c@x.com", nombre: "Otro", rol: .gerenteSucursal, sucursalId: suc2.id, activo: true, debeCambiarPassword: false),
        ]
        let p = PreciosFalso()
        func precio(_ c: Combustible, _ v: String, dias: Double) -> Precio {
            Precio(id: UUID(), sucursalId: suc1.id, combustible: c, precioGal: Decimal(string: v)!, vigenteDesde: ahora.addingTimeInterval(-dias * 86400), creadoPor: nil)
        }
        p.filas = [precio(.superior, "3.50", dias: 9), precio(.superior, "3.80", dias: 1), precio(.superior, "9.00", dias: -2)]
        let s = SucursalesFalso()
        let tanqueSuper = Tanque(id: UUID(), sucursalId: suc1.id, combustible: .superior, numero: 1, capacidadGal: 1000, nivelInicialGal: 0)
        s.tanquesLista = [tanqueSuper]
        let r = ReportesFalso()
        r.perdidasLista = [PerdidaCombustible(id: UUID(), corteId: UUID(), sucursalId: suc1.id, tanqueId: tanqueSuper.id, tipo: .fuga, galones: 3, bombaId: nil,
                                              nota: "Fuga en la línea", origen: .manual, vaciadoId: nil, creadoEn: ahora)]
        let vm = DetalleSucursalViewModel(sucursal: suc1, usuarios: u, tanques: TanquesFalso(), reportes: r, precios: p, sucursales: s, ahora: { ahora })
        await vm.cargar()
        igual(vm.estado.valor?.gerente?.nombre, "Gerente Actual", "el gerente activo de esta sucursal")
        igual(vm.estado.valor?.preciosVigentes[.superior]?.precioGal, Decimal(string: "3.80"), "precio vigente (ignora el futuro)")
        verificar(vm.estado.valor?.preciosVigentes[.diesel] == nil, "sin precio de diésel")
        igual(vm.combustible(de: r.perdidasLista[0]), .superior, "combustible de la pérdida por tanque")
    }

    await grupo("PerdidasGlobalesViewModel") {
        let r = ReportesFalso()
        let s = SucursalesFalso(); s.sucursales = [suc1, suc2]
        let vm = PerdidasGlobalesViewModel(reportes: r, sucursales: s, ahora: ahora)
        await vm.cargar()
        verificar(r.ultimoFiltroPerdidas?.2 == nil, "sin filtro de fechas por defecto")
        vm.sucursalId = suc2.id
        vm.tipo = .contaminacion
        vm.usarFechas = true
        vm.desde = Fechas.fecha(deDia: "2026-10-03")!
        vm.hasta = Fechas.fecha(deDia: "2026-10-01")!
        await vm.cargar()
        igual(r.ultimoFiltroPerdidas?.0, suc2.id, "filtra por sucursal")
        igual(r.ultimoFiltroPerdidas?.1, .contaminacion, "filtra por tipo")
        igual(r.ultimoFiltroPerdidas?.2, "2026-10-01", "fechas invertidas se corrigen: desde")
        igual(r.ultimoFiltroPerdidas?.3, "2026-10-03", "fechas invertidas se corrigen: hasta")
    }
}
