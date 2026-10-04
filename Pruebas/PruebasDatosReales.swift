import Foundation

/// Decodifica con los modelos de la app JSON **real** generado por el servidor (PostgREST/`to_jsonb`) en un escenario completo
/// (dos cortes, cambio de medidor, vaciado, ajuste, ventas, anulación y cajas), capturado en una transacción desechada.
func pruebasDatosReales() async {
    await grupo("Datos reales del servidor decodifican con los modelos") {
        let ruta = FileManager.default.currentDirectoryPath + "/Pruebas/datos_reales_vistas.json"
        let datos = try Data(contentsOf: URL(fileURLWithPath: ruta))
        let raiz = try JSONSerialization.jsonObject(with: datos) as! [String: Any]

        func filas<T: Decodable>(_ clave: String, _ tipo: T.Type) throws -> [T] {
            guard let crudo = raiz[clave], !(crudo is NSNull) else { return [] }
            let json = try JSONSerialization.data(withJSONObject: crudo)
            return try JSONSupabase.decodificador.decode([T].self, from: json)
        }
        func uno<T: Decodable>(_ clave: String, _ tipo: T.Type) throws -> T {
            let tablas = raiz["tablas"] as! [String: Any]
            let json = try JSONSerialization.data(withJSONObject: tablas[clave]!)
            return try JSONSupabase.decodificador.decode(T.self, from: json)
        }

        let tanques = try filas("v_estado_tanque", EstadoTanque.self)
        igual(tanques.count, 2, "v_estado_tanque")
        igual(tanques[1].estado, .critico, "tanque crítico")
        verificar(tanques[0].autonomiaDias == nil && !tanques[0].autonomiaDisponible, "sin autonomía (menos de 7 días de historial)")
        verificar(tanques[0].baseEn != nil, "base_en como fecha")
        igual(tanques[0].nivelEstimadoGal, 4600, "nivel estimado")
        igual(tanques[0].nCompras, 1, "n_compras")

        let cuadre = try filas("v_cuadre", CuadreTanque.self)
        igual(cuadre.count, 2, "v_cuadre_tanque_corte")
        igual(cuadre[0].diferenciaGal, -4240, "diferencia negativa")
        verificar(cuadre[1].hayDiferencia, "hay diferencia")

        let resumen = try filas("v_resumen", ResumenCorte.self)
        igual(resumen.count, 2, "v_resumen_corte")
        verificar(resumen[0].hayAjuste && !resumen[1].hayAjuste, "marca de ajuste")
        verificar(resumen[1].hayCambioMedidor, "marca de cambio de medidor")
        igual(resumen[1].ingresoUsd, 8484, "ingreso")

        let lecturas = try filas("v_lecturas", LecturaEfectiva.self)
        igual(lecturas.count, 2, "v_lecturas_efectivas")
        igual(lecturas[1].lecturaInicialGal, 1101, "lectura inicial derivada")
        igual(lecturas[1].galones, 200, "galones")

        let dash = try filas("v_dashboard", DashboardCombustible.self)
        igual(dash.count, 2, "v_dashboard_combustible")
        igual(dash[0].fechaOperativa, "2026-10-04", "fecha operativa")
        igual(dash[0].cortesConDiferencia, 1, "cortes con diferencia")

        let ingresos = try filas("v_tienda_ingresos", TiendaIngreso.self)
        igual(ingresos.map(\.categoria), [.lubricantes, .servicios], "v_tienda_ingresos")
        let anul = try filas("v_tienda_anulaciones", TiendaAnulacion.self)
        igual(anul.first?.ventasAnuladas, 1, "v_tienda_anulaciones")
        let cajas = try filas("v_tienda_cajas", TiendaCaja.self)
        igual(cajas.count, 2, "v_tienda_cajas")
        igual(cajas[0].diferenciaUsd, 3, "caja con sobrante")
        verificar(cajas[1].cerradaEn == nil && cajas[1].fechaOperativa == nil && cajas[1].efectivoEsperadoUsd == nil, "caja abierta con nulos")
        igual((try filas("v_stock_bajo", StockBajo.self)).count, 0, "vista vacía (null) = sin filas")

        let venta = try uno("venta", Venta.self)
        verificar(venta.estado == .anulada && venta.vueltoUsd == nil && venta.anuladaEn != nil, "venta anulada con tarjeta")
        igual(venta.motivoAnulacion, "Cobro duplicado", "motivo")
        let ef = try uno("venta_efectivo", Venta.self)
        igual(ef.vueltoUsd, 6, "vuelto de efectivo")
        let cerrado = try uno("corte_cerrado", Corte.self)
        verificar(cerrado.estaCerrado && cerrado.tipo == .matutino && cerrado.fechaOperativa == "2026-10-04", "corte cerrado")
        let curso = try uno("corte_en_curso", Corte.self)
        verificar(!curso.estaCerrado && curso.tipo == nil && curso.cerradoEn == nil, "corte en curso")
        let baja = try uno("baja_otro", BajaInventario.self)
        igual(baja.motivo, .otro, "baja con motivo otro")
        igual(baja.nota, "Se cayo de la gondola", "nota de la baja")
        let ajuste = try uno("ajuste", AjusteLectura.self)
        igual(ajuste.valorCorrectoGal, 2060, "ajuste")
        let compra = try uno("compra_sin_proveedor", CompraCombustible.self)
        verificar(compra.proveedor == nil && compra.origen == .manual, "compra sin proveedor")
        let turno = try uno("turno", Turno.self)
        verificar(turno.cruzaMedianoche, "turno nocturno real")
        let cambio = try uno("cambio_medidor", CambioMedidor.self)
        igual(cambio.lecturaInicialNuevoGal, 0, "cambio de medidor")
        let lm = try uno("lectura_manguera", LecturaManguera.self)
        igual(lm.lecturaInicialManualGal, 2000, "lectura inicial manual del primer corte")
        let vt = try uno("r_venta_tarjeta", ResultadoVenta.self)
        verificar(vt.vueltoUsd == nil && vt.recibidoUsd == nil, "resultado de venta con tarjeta")
    }
}
