import Foundation

@MainActor
func pruebasCorte() async {
    func hub(corte: CorteFalso = CorteFalso(), almacen: AlmacenFalso = AlmacenFalso(), conTienda: Bool = true) -> (CorteEnCursoViewModel, CorteFalso, AlmacenFalso) {
        let s = SucursalesFalso()
        s.sucursales = [Sucursal(id: Ejemplo.sucursalId, nombre: "Centro", direccion: "x", tieneTienda: conTienda, activa: true)]
        let vm = CorteEnCursoViewModel(sucursalId: Ejemplo.sucursalId, corte: corte, lineas: LineasFalso(), tanques: TanquesFalso(),
                                       sucursales: s, almacen: almacen)
        return (vm, corte, almacen)
    }

    await grupo("CorteEnCursoViewModel: progreso del corte") {
        let (vm, corte, _) = hub()
        await vm.cargar()
        igual(vm.bombasFaltantes, [1, 2, 3, 4, 5, 6], "al inicio faltan las 6 bombas")
        verificar(!vm.puedeCerrar, "no se puede cerrar")
        igual(vm.motivoNoCierra, "Faltan: Bomba 1, Bomba 2, Bomba 3, Bomba 4, Bomba 5, Bomba 6 · nivel de Súper, Regular, Diésel", "motivo completo")

        corte.borrador = Ejemplo.borrador(para: Array(Ejemplo.infra.bombas.prefix(3)), corte: corte.corte)
        await vm.cargar()
        igual(vm.bombasFaltantes, [4, 5, 6], "con 3 bombas guardadas faltan 4, 5 y 6")
        igual(vm.bombasGuardadas.count, 3, "3 guardadas")

        // Una bomba con solo 2 mangueras guardadas no cuenta como guardada.
        let b4 = Ejemplo.infra.bombas[3]
        let dos = Ejemplo.infra.mangueras(de: b4).prefix(2).map {
            LecturaManguera(id: UUID(), corteId: corte.corte.id, mangueraId: $0.id, lecturaInicialManualGal: nil, lecturaFinalGal: 1)
        }
        corte.borrador += dos
        await vm.cargar()
        igual(vm.bombasFaltantes, [4, 5, 6], "bomba incompleta sigue pendiente")

        corte.borrador = Ejemplo.borrador(para: Ejemplo.infra.bombas, corte: corte.corte)
        await vm.cargar()
        igual(vm.motivoNoCierra, "Faltan: nivel de Súper, Regular, Diésel", "solo faltan niveles")
    }

    await grupo("CorteEnCursoViewModel: niveles de tanque") {
        let almacen = AlmacenFalso()
        let (vm, corte, _) = hub(almacen: almacen)
        corte.borrador = Ejemplo.borrador(para: Ejemplo.infra.bombas, corte: corte.corte)
        await vm.cargar()
        let t = vm.datos!.tanques
        vm.niveles[t[0].tanqueId] = "1500"
        verificar(vm.errorNivel(t[0])?.contains("capacidad") == true, "nivel sobre la capacidad")
        verificar(!vm.guardarNiveles(), "no guarda con errores")
        vm.niveles[t[0].tanqueId] = "800.5"
        vm.niveles[t[1].tanqueId] = "0"
        verificar(!vm.guardarNiveles(), "falta el tercero")
        verificar(vm.errorNiveles[t[2].tanqueId] != nil, "marca el que falta")
        vm.niveles[t[2].tanqueId] = "100"
        verificar(vm.guardarNiveles(), "guarda con los 3")
        verificar(vm.puedeCerrar && vm.motivoNoCierra == nil, "ya se puede cerrar")
        igual(almacen.datos[corte.corte.id]?.count ?? 0, 3, "persistidos en el teléfono")
        let enviar = vm.nivelesParaEnviar()
        igual(enviar?.count ?? 0, 3, "niveles para enviar")
        igual(enviar?.first?.nivelMedidoGal, Decimal(string: "800.5"), "valor enviado")

        // Una vista nueva recupera lo tecleado.
        let (vm2, _, _) = hub(corte: corte, almacen: almacen)
        await vm2.cargar()
        igual(vm2.niveles[t[0].tanqueId], "800.5", "recupera el borrador de niveles")
        vm2.olvidarNiveles()
        verificar(almacen.datos[corte.corte.id] == nil, "tras cerrar se borra el borrador")
    }

    await grupo("BombaFormViewModel: segundo corte (inicial derivada)") {
        let corte = Ejemplo.corte(secuencia: 2)
        let bomba = Ejemplo.infra.bombas[0]
        let ms = Ejemplo.infra.mangueras(de: bomba)
        let iniciales = Dictionary(uniqueKeysWithValues: ms.map { ($0.id, Decimal(1000)) })
        let svc = CorteFalso()
        var guardo = false
        let vm = BombaFormViewModel(bomba: bomba, mangueras: ms, corte: corte, borrador: [], iniciales: iniciales, cambios: [], servicio: svc) { guardo = true }
        verificar(!vm.esPrimerCorte, "no es el primero")
        verificar(!vm.esValido, "vacío no es válido")
        igual(vm.errorFinal(vm.lineas[0]), "Escribe la lectura final.", "final vacía")
        vm.lineas[0].final = "999"
        verificar(vm.errorFinal(vm.lineas[0])?.contains("no puede ser menor que la inicial (1,000.00)") == true, "final menor que la inicial: \(vm.errorFinal(vm.lineas[0]) ?? "")")
        vm.lineas[0].final = "1000"
        vm.lineas[1].final = "1250.5"
        vm.lineas[2].final = "1100"
        verificar(vm.esValido, "válido")
        await vm.guardar()
        verificar(guardo, "guardó")
        igual(svc.guardadas.first?.1.count ?? 0, 3, "envía 3 lecturas")
        verificar(svc.guardadas.first?.1.allSatisfy { $0.lecturaInicialGal == nil } == true, "no envía inicial en cortes posteriores")
        igual(svc.guardadas.first?.1[1].lecturaFinalGal, Decimal(string: "1250.5"), "valor final")
    }

    await grupo("BombaFormViewModel: primer corte pide la inicial") {
        let corte = Ejemplo.corte(secuencia: 1)
        let bomba = Ejemplo.infra.bombas[1]
        let ms = Ejemplo.infra.mangueras(de: bomba)
        let svc = CorteFalso()
        let vm = BombaFormViewModel(bomba: bomba, mangueras: ms, corte: corte, borrador: [], iniciales: [:], cambios: [], servicio: svc) {}
        verificar(vm.esPrimerCorte, "primer corte")
        igual(vm.errorInicial(vm.lineas[0]), "Escribe la lectura inicial.", "pide inicial")
        for i in 0..<3 { vm.lineas[i].inicial = "500"; vm.lineas[i].final = "400" }
        verificar(vm.errorFinal(vm.lineas[0]) != nil, "final < inicial tecleada")
        for i in 0..<3 { vm.lineas[i].final = "650" }
        await vm.guardar()
        verificar(svc.guardadas.first?.1.allSatisfy { $0.lecturaInicialGal == 500 } == true, "envía las iniciales del primer corte")
    }

    await grupo("BombaFormViewModel: recarga el borrador guardado y respeta cambio de medidor") {
        let corte = Ejemplo.corte(secuencia: 2)
        let bomba = Ejemplo.infra.bombas[0]
        let ms = Ejemplo.infra.mangueras(de: bomba)
        let guardada = LecturaManguera(id: UUID(), corteId: corte.id, mangueraId: ms[0].id, lecturaInicialManualGal: nil, lecturaFinalGal: Decimal(string: "1234.5")!)
        let cambio = CambioMedidor(id: UUID(), corteId: corte.id, mangueraId: ms[0].id, lecturaFinalViejoGal: 9999, lecturaInicialNuevoGal: 0,
                                   nota: "Medidor dañado", registradoPor: nil, creadoEn: Date())
        let iniciales = Dictionary(uniqueKeysWithValues: ms.map { ($0.id, Decimal(9000)) })
        let vm = BombaFormViewModel(bomba: bomba, mangueras: ms, corte: corte, borrador: [guardada], iniciales: iniciales, cambios: [cambio], servicio: CorteFalso()) {}
        igual(vm.lineas[0].final, "1234.5", "precarga la final guardada")
        verificar(vm.errorFinal(vm.lineas[0]) == nil, "con cambio de medidor, 1234.5 ≥ 0 (inicial del medidor nuevo) es válido")
        verificar(vm.cambio(de: vm.lineas[0]) != nil, "reconoce el cambio")
        verificar(vm.errorFinal(vm.lineas[1]) != nil, "las demás mangueras siguen con su regla")
    }

    await grupo("CambioMedidorViewModel") {
        let corte = Ejemplo.corte(secuencia: 2)
        let bomba = Ejemplo.infra.bombas[0]
        let ms = Ejemplo.infra.mangueras(de: bomba)
        let svc = CorteFalso()
        var ok = false
        let vm = CambioMedidorViewModel(corte: corte, mangueras: ms, borrador: [], iniciales: [ms[0].id: 500, ms[1].id: 500, ms[2].id: 500],
                                        existentes: [], servicio: svc) { ok = true }
        verificar(!vm.esValido, "vacío no válido")
        vm.finalViejo = "400"
        verificar(vm.errorFinalViejo != nil, "final del viejo menor que la inicial")
        vm.finalViejo = "950"
        verificar(vm.errorNota != nil, "nota obligatoria")
        vm.nota = "ab"
        verificar(vm.errorNota != nil, "nota de 2 caracteres no alcanza")
        vm.nota = "Medidor dañado"
        await vm.guardar()
        verificar(ok, "guardó")
        igual(svc.llamadas, ["cambio:950:0:Medidor dañado"], "llamada al servidor")
    }

    await grupo("CompraFormViewModel") {
        let l = LineasFalso()
        var ok = false
        let vm = CompraFormViewModel(corteId: Ejemplo.corteId, tanques: Ejemplo.tanques, compra: nil, servicio: l) { ok = true }
        verificar(!vm.esValido, "sin galones")
        vm.galones = "0"
        verificar(vm.errorGalones != nil, "0 no es válido")
        vm.galones = "300.25"
        vm.proveedor = "  "
        await vm.guardar()
        verificar(ok, "guardó")
        igual(l.llamadas, ["compra:300.25:nil"], "proveedor vacío se envía como nulo")
        l.error = ErrorDePrueba(mensaje: "La compra excede el espacio libre del tanque (libre: 120.00 gal).")
        await vm.guardar()
        igual(vm.error, "La compra excede el espacio libre del tanque (libre: 120.00 gal).", "mensaje exacto del servidor")
    }

    await grupo("ComprasViewModel: las generadas por vaciado están bloqueadas") {
        let l = LineasFalso()
        let manual = CompraCombustible(id: UUID(), corteId: Ejemplo.corteId, tanqueId: Ejemplo.tanques[0].tanqueId, galones: 10, proveedor: nil, origen: .manual, vaciadoId: nil, creadoEn: Date())
        let auto = CompraCombustible(id: UUID(), corteId: Ejemplo.corteId, tanqueId: Ejemplo.tanques[1].tanqueId, galones: 5, proveedor: nil, origen: .vaciado, vaciadoId: UUID(), creadoEn: Date())
        l.comprasLista = [manual, auto]
        let vm = ComprasViewModel(corteId: Ejemplo.corteId, tanques: Ejemplo.tanques, servicio: l)
        await vm.cargar()
        verificar(vm.esEditable(manual) && !vm.esEditable(auto), "solo la manual es editable")
        igual(vm.combustible(de: auto), .regular, "combustible de la compra")
        await vm.eliminar(manual)
        igual(vm.estado.valor?.count ?? 0, 1, "se eliminó y recargó")
        l.error = ErrorDePrueba(mensaje: "No se puede eliminar: el nivel estimado del tanque quedaría negativo.")
        await vm.eliminar(auto)
        verificar(vm.error != nil, "muestra el error de eliminar")
    }

    await grupo("PerdidaFormViewModel") {
        let l = LineasFalso()
        let vm = PerdidaFormViewModel(corteId: Ejemplo.corteId, tanques: Ejemplo.tanques, bombas: Ejemplo.infra.bombas, perdida: nil, servicio: l) {}
        verificar(!vm.esValido, "vacío")
        vm.galones = "5"
        verificar(vm.errorNota != nil, "nota obligatoria")
        vm.nota = "Derrame al despachar"
        vm.tipo = .derrame
        await vm.guardar()
        igual(l.llamadas, ["perdida:derrame:5:sinBomba"], "la bomba es opcional")
        vm.bombaId = Ejemplo.infra.bombas[2].id
        await vm.guardar()
        igual(l.llamadas.last, "perdida:derrame:5:conBomba", "con bomba")
        igual(TipoPerdida.manuales.contains(.contaminacion), false, "contaminación no es un tipo manual")
    }

    await grupo("VaciadoViewModel: descarga errónea") {
        let l = LineasFalso()
        var ok = false
        let vm = VaciadoViewModel(corteId: Ejemplo.corteId, tanques: Ejemplo.tanques, tanqueInicial: Ejemplo.tanques[1].tanqueId, servicio: l) { ok = true }
        igual(vm.tanqueActual?.combustible, .regular, "tanque de Regular")
        verificar(!vm.opcionesErroneo.contains(.regular), "el combustible equivocado debe ser distinto")
        verificar(vm.combustibleErroneo != nil && vm.combustibleErroneo != .regular, "elige uno distinto por defecto")
        vm.combustibleErroneo = .diesel
        vm.nivelMedido = "300"
        vm.galonesErroneos = "350"
        igual(vm.errorGalonesErroneos, "No pueden superar el nivel medido.", "galones erróneos > nivel medido")
        vm.galonesErroneos = "120"
        vm.nota = "Cisterna trajo Diésel"
        verificar(vm.esValido, "válido")
        igual(vm.vistaPrevia.count, 3, "3 líneas de vista previa")
        verificar(vm.vistaPrevia[0].contains("180.00 gal de Regular"), "pérdida del tanque = medido − erróneos: \(vm.vistaPrevia[0])")
        verificar(vm.vistaPrevia[1].contains("120.00 gal de Diésel"), "compra y pérdida del erróneo")
        verificar(vm.vistaPrevia[2].contains("quedará en 0"), "queda en 0")
        await vm.registrar()
        verificar(ok, "registró")
        igual(l.ultimoVaciado?.2, .diesel, "combustible erróneo enviado")
        igual(l.ultimoVaciado?.3, 120, "galones erróneos enviados")
    }

    await grupo("VaciadoViewModel: otra contaminación") {
        let l = LineasFalso()
        let vm = VaciadoViewModel(corteId: Ejemplo.corteId, tanques: Ejemplo.tanques, servicio: l) {}
        vm.motivo = .otraContaminacion
        vm.nivelMedido = "250"
        vm.nota = "Agua en el tanque"
        verificar(vm.esValido, "no pide combustible ni galones erróneos")
        igual(vm.vistaPrevia.count, 2, "2 líneas")
        await vm.registrar()
        verificar(l.ultimoVaciado?.2 == nil && l.ultimoVaciado?.3 == nil, "no envía combustible erróneo")
        vm.nivelMedido = "5000"
        verificar(vm.errorNivel?.contains("capacidad") == true, "nivel sobre la capacidad")
    }
}
