import Foundation

func pruebasModelos() async {
    await grupo("Modelos: lectura de JSON de PostgREST") {
        let sucursal = try decodificar(Sucursal.self, #"{"id":"11111111-1111-1111-1111-111111111111","nombre":"Centro","direccion":"San Salvador","tiene_tienda":true,"activa":true,"creado_en":"2026-10-04T04:31:21.123456+00:00"}"#)
        igual(sucursal.nombre, "Centro", "sucursal.nombre")
        verificar(sucursal.tieneTienda, "sucursal.tieneTienda")

        let perfil = try decodificar(Perfil.self, #"{"id":"11111111-1111-1111-1111-111111111111","correo":"a@b.com","nombre":"Ana","rol":"gerente_sucursal","sucursal_id":"22222222-2222-2222-2222-222222222222","activo":true,"debe_cambiar_password":false,"creado_en":"2026-10-04T04:31:21+00:00"}"#)
        igual(perfil.rol, .gerenteSucursal, "perfil.rol")
        verificar(perfil.sucursalId != nil, "perfil.sucursalId")

        let gg = try decodificar(Perfil.self, #"{"id":"11111111-1111-1111-1111-111111111111","correo":"a@b.com","nombre":"Ana","rol":"gerente_general","sucursal_id":null,"activo":true,"debe_cambiar_password":true}"#)
        verificar(gg.sucursalId == nil, "GG sin sucursal")

        let tanque = try decodificar(EstadoTanque.self, #"{"tanque_id":"11111111-1111-1111-1111-111111111111","sucursal_id":"22222222-2222-2222-2222-222222222222","combustible":"super","capacidad_gal":10000.00,"nivel_estimado_gal":1234.56,"porcentaje":12.35,"n_compras":2,"n_perdidas":1,"base_en":"2026-10-04T10:00:00.5+00:00","autonomia_dias":1.5,"autonomia_disponible":true,"estado":"critico"}"#)
        igual(tanque.estado, .critico, "estado tanque")
        igual(tanque.nivelEstimadoGal, Decimal(string: "1234.56")!, "decimal exacto")
        igual(tanque.combustible, .superior, "combustible super")

        let sinHistorial = try decodificar(EstadoTanque.self, #"{"tanque_id":"11111111-1111-1111-1111-111111111111","sucursal_id":"22222222-2222-2222-2222-222222222222","combustible":"diesel","capacidad_gal":5000,"nivel_estimado_gal":null,"porcentaje":null,"n_compras":0,"n_perdidas":0,"base_en":null,"autonomia_dias":null,"autonomia_disponible":false,"estado":"optimo"}"#)
        verificar(sinHistorial.autonomiaDias == nil && sinHistorial.baseEn == nil, "autonomía y base nulas")
        igual(sinHistorial.nivelEstimadoGal, 0, "nivel nulo = 0")

        let resumen = try decodificar(ResumenCorte.self, #"{"corte_id":"11111111-1111-1111-1111-111111111111","sucursal_id":"22222222-2222-2222-2222-222222222222","combustible":"regular","tanque_id":"33333333-3333-3333-3333-333333333333","galones_vendidos":null,"ingreso_usd":null,"compras_gal":0,"perdidas_gal":0,"nivel_inicial_gal":100,"nivel_teorico_gal":100,"nivel_medido_gal":99.5,"diferencia_gal":-0.5,"hay_diferencia":false,"hay_ajuste":false,"hay_cambio_medidor":true}"#)
        igual(resumen.galonesVendidos, 0, "galones nulos = 0")
        verificar(resumen.hayCambioMedidor, "hay cambio medidor")
        igual(resumen.diferenciaGal, Decimal(string: "-0.5")!, "diferencia negativa")

        let corte = try decodificar(Corte.self, #"{"id":"11111111-1111-1111-1111-111111111111","sucursal_id":"22222222-2222-2222-2222-222222222222","secuencia":3,"estado":"cerrado","abierto_en":"2026-10-04T04:31:21.123456+00:00","cerrado_en":"2026-10-04T18:00:00+00:00","cerrado_por":"33333333-3333-3333-3333-333333333333","tipo":"matutino","fecha_operativa":"2026-10-04","creado_en":"2026-10-04T04:31:21+00:00"}"#)
        igual(corte.tipo, .matutino, "tipo corte")
        igual(corte.fechaOperativa, "2026-10-04", "fecha operativa")
        verificar(corte.estaCerrado, "cerrado")

        let enCurso = try decodificar(Corte.self, #"{"id":"11111111-1111-1111-1111-111111111111","sucursal_id":"22222222-2222-2222-2222-222222222222","secuencia":1,"estado":"en_curso","abierto_en":"2026-10-04T04:31:21.1+00:00","cerrado_en":null,"cerrado_por":null,"tipo":null,"fecha_operativa":null}"#)
        verificar(!enCurso.estaCerrado && enCurso.tipo == nil, "corte en curso")

        let turno = try decodificar(Turno.self, #"{"id":"11111111-1111-1111-1111-111111111111","sucursal_id":"22222222-2222-2222-2222-222222222222","nombre":"Noche","hora_inicio":"22:00:00","hora_fin":"06:00:00","activo":true}"#)
        verificar(turno.cruzaMedianoche, "turno cruza medianoche")

        let asign = try decodificar(AsignacionTurno.self, #"{"empleado_id":"11111111-1111-1111-1111-111111111111","turno_id":"22222222-2222-2222-2222-222222222222","sucursal_id":"33333333-3333-3333-3333-333333333333","dias":[1,2,3]}"#)
        igual(asign.dias, [1, 2, 3], "dias del turno")

        let cierre = try decodificar(ResultadoCierreCorte.self, #"{"corte_id":"11111111-1111-1111-1111-111111111111","tipo":"vespertino","fecha_operativa":"2026-10-04","siguiente_corte_id":"22222222-2222-2222-2222-222222222222"}"#)
        igual(cierre.tipo, .vespertino, "resultado cierre")

        let venta = try decodificar(ResultadoVenta.self, #"{"venta_id":"11111111-1111-1111-1111-111111111111","numero":12,"total_usd":4.50,"recibido_usd":5,"vuelto_usd":0.50}"#)
        igual(venta.vueltoUsd, Decimal(string: "0.5"), "vuelto")

        let cajaTarjeta = try decodificar(ResultadoVenta.self, #"{"venta_id":"11111111-1111-1111-1111-111111111111","numero":13,"total_usd":4.50,"recibido_usd":null,"vuelto_usd":null}"#)
        verificar(cajaTarjeta.vueltoUsd == nil, "tarjeta sin vuelto")

        let le = try decodificar(LecturaEfectiva.self, #"{"corte_id":"11111111-1111-1111-1111-111111111111","sucursal_id":"22222222-2222-2222-2222-222222222222","manguera_id":"33333333-3333-3333-3333-333333333333","bomba_id":"44444444-4444-4444-4444-444444444444","bomba_numero":2,"combustible":"diesel","lectura_inicial_gal":100,"final_original":150,"lectura_final_gal":155,"ajustada":true,"cambio_medidor":false,"galones":55}"#)
        verificar(le.ajustada, "ajustada")
        igual(le.galones, 55, "galones lectura")
    }

    await grupo("Codificador: parámetros de las funciones") {
        struct Params: Encodable { let pCorte: UUID; let pGalones: Decimal; let pProveedor: String? }
        let id = UUID()
        let datos = try JSONSupabase.codificador.encode(Params(pCorte: id, pGalones: Decimal(string: "12.34")!, pProveedor: nil))
        let texto = String(decoding: datos, as: UTF8.self)
        verificar(texto.contains("\"p_corte\""), "p_corte en snake_case")
        verificar(texto.contains("\"p_galones\":12.34"), "decimal exacto como número: \(texto)")

        let lineas = try JSONSupabase.codificador.encode([NivelMedido(tanqueId: id, nivelMedidoGal: 100)])
        verificar(String(decoding: lineas, as: UTF8.self).contains("\"nivel_medido_gal\":100"), "niveles")
    }

    await grupo("Fechas de El Salvador") {
        // 2026-10-05 03:00 UTC = 2026-10-04 21:00 en El Salvador (UTC−6)
        let f = Date(timeIntervalSince1970: 1791169200)
        igual(Fechas.hoy(ahora: f), "2026-10-04", "el día se calcula en zona de El Salvador")
        igual(Fechas.hace(dias: 6, desde: f), "2026-09-28", "hace 6 días")
        igual(Fechas.hora(deTexto: "22:00:00"), Fechas.hora(deTexto: "22:00:00"), "hora estable")
        verificar(Fechas.parsearTimestamp("2026-10-04T04:31:21.123456+00:00") != nil, "timestamp con microsegundos")
        verificar(Fechas.parsearTimestamp("2026-10-04T04:31:21+00:00") != nil, "timestamp sin fracción")
        verificar(Fechas.parsearTimestamp("2026-10-04T04:31:21.5+00:00") != nil, "timestamp con 1 decimal")
        igual(Fechas.diaIso(Fechas.fecha(deDia: "2026-10-05")!), 1, "5-oct-2026 es lunes")
        igual(Fechas.diaIso(Fechas.fecha(deDia: "2026-10-04")!), 7, "4-oct-2026 es domingo")
    }
}
