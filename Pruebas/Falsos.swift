import Foundation

/// Datos de ejemplo y servicios falsos para probar ViewModels sin red.
enum Ejemplo {
    static let sucursalId = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    static let sucursal2Id = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!

    static func perfil(rol: RolUsuario = .gerenteGeneral, activo: Bool = true, debeCambiar: Bool = false) -> Perfil {
        Perfil(id: UUID(), correo: "ana@correo.com", nombre: "Ana", rol: rol,
               sucursalId: rol == .gerenteGeneral ? nil : sucursalId, activo: activo, debeCambiarPassword: debeCambiar)
    }
}

struct ErrorDePrueba: LocalizedError {
    let mensaje: String
    var errorDescription: String? { mensaje }
}

final class AuthFalso: AuthService, @unchecked Sendable {
    var perfil: Perfil?
    var errorAlIniciar: Error?
    var errorAlEnviar: Error?
    var errorAlVerificar: Error?
    var errorAlCambiar: Error?
    var errorAlMarcar: Error?
    var llamadas: [String] = []

    func perfilActual() async throws -> Perfil? { llamadas.append("perfilActual"); return perfil }
    func iniciarSesion(correo: String, password: String) async throws {
        llamadas.append("iniciarSesion:\(correo)")
        if let e = errorAlIniciar { throw e }
    }
    func cerrarSesion() async { llamadas.append("cerrarSesion"); perfil = nil }
    func enviarCodigo(correo: String) async throws {
        llamadas.append("enviarCodigo:\(correo)")
        if let e = errorAlEnviar { throw e }
    }
    func verificarCodigo(correo: String, codigo: String) async throws {
        llamadas.append("verificarCodigo:\(codigo)")
        if let e = errorAlVerificar { throw e }
    }
    func cambiarPassword(_ nueva: String) async throws {
        llamadas.append("cambiarPassword")
        if let e = errorAlCambiar { throw e }
    }
    func marcarPasswordCambiada() async throws {
        llamadas.append("marcarPasswordCambiada")
        if let e = errorAlMarcar { throw e }
    }
}

final class SucursalesFalso: SucursalesService, @unchecked Sendable {
    var sucursales: [Sucursal] = []
    var tanquesLista: [Tanque] = []
    var error: Error?
    var llamadas: [String] = []
    var ultimoCrear: (String, String, Bool, [TanqueNuevo])?

    func listar() async throws -> [Sucursal] { if let e = error { throw e }; return sucursales }
    func tanques() async throws -> [Tanque] { if let e = error { throw e }; return tanquesLista }
    func crear(nombre: String, direccion: String, tieneTienda: Bool, tanques: [TanqueNuevo]) async throws -> UUID {
        llamadas.append("crear")
        if let e = error { throw e }
        ultimoCrear = (nombre, direccion, tieneTienda, tanques)
        return UUID()
    }
    func editar(id: UUID, nombre: String, direccion: String) async throws {
        llamadas.append("editar"); if let e = error { throw e }
    }
    func cambiarEstado(id: UUID, activa: Bool) async throws {
        llamadas.append("cambiarEstado:\(activa)"); if let e = error { throw e }
    }
    func configurarTienda(id: UUID, tieneTienda: Bool) async throws {
        llamadas.append("configurarTienda:\(tieneTienda)"); if let e = error { throw e }
    }
}

final class PreciosFalso: PreciosService, @unchecked Sendable {
    var filas: [Precio] = []
    var error: Error?
    var ultimaLlamada: ([UUID], Combustible, Decimal)?
    func historial() async throws -> [Precio] { if let e = error { throw e }; return filas }
    func fijar(sucursales: [UUID], combustible: Combustible, precio: Decimal) async throws -> Int {
        if let e = error { throw e }
        ultimaLlamada = (sucursales, combustible, precio)
        return sucursales.count
    }
}

final class UsuariosFalso: UsuariosService, @unchecked Sendable {
    var perfiles: [Perfil] = []
    var error: Error?
    var llamadas: [String] = []
    var ultimoCrear: (String, String, RolUsuario, UUID?, String)?
    func listar() async throws -> [Perfil] { if let e = error { throw e }; return perfiles }
    func crear(correo: String, nombre: String, rol: RolUsuario, sucursalId: UUID?, passwordTemporal: String) async throws -> UUID {
        if let e = error { throw e }
        ultimoCrear = (correo, nombre, rol, sucursalId, passwordTemporal)
        return UUID()
    }
    func restablecerPassword(usuarioId: UUID, passwordTemporal: String) async throws {
        llamadas.append("restablecer"); if let e = error { throw e }
    }
    func cambiarEstado(usuarioId: UUID, activo: Bool) async throws {
        llamadas.append("estado:\(activo)"); if let e = error { throw e }
    }
    func cambiarCorreo(usuarioId: UUID, correo: String) async throws {
        if let e = error { throw e }
        llamadas.append("correo:\(correo)")
    }
}

final class CatalogoFalso: CatalogoService, @unchecked Sendable {
    var articulos: [Articulo] = []
    var error: Error?
    var llamadas: [String] = []
    func listar() async throws -> [Articulo] { if let e = error { throw e }; return articulos }
    func crear(nombre: String, categoria: CategoriaArticulo, tipo: TipoArticulo, precioUsd: Decimal, activo: Bool) async throws {
        if let e = error { throw e }
        llamadas.append("crear:\(nombre):\(categoria.rawValue):\(tipo.rawValue):\(precioUsd)")
    }
    func editar(id: UUID, nombre: String, precioUsd: Decimal, activo: Bool) async throws {
        if let e = error { throw e }
        llamadas.append("editar:\(nombre):\(precioUsd):\(activo)")
    }
}

// MARK: - Corte y combustible

extension Ejemplo {
    static let corteId = UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001")!

    static func corte(secuencia: Int = 1, estado: EstadoCorte = .enCurso, tipo: TipoCorte? = nil, fecha: String? = nil, cerradoPor: UUID? = nil) -> Corte {
        Corte(id: secuencia == 1 && estado == .enCurso ? corteId : UUID(), sucursalId: sucursalId, secuencia: secuencia, estado: estado,
              abiertoEn: Date(), cerradoEn: estado == .cerrado ? Date() : nil, cerradoPor: cerradoPor, tipo: tipo, fechaOperativa: fecha)
    }

    /// 6 bombas × 3 mangueras.
    static let infra: Infraestructura = {
        var bombas: [Bomba] = []
        var mangueras: [Manguera] = []
        for n in 1...6 {
            let b = Bomba(id: UUID(), sucursalId: sucursalId, numero: n)
            bombas.append(b)
            for c in Combustible.allCases {
                mangueras.append(Manguera(id: UUID(), bombaId: b.id, sucursalId: sucursalId, combustible: c))
            }
        }
        return Infraestructura(bombas: bombas, mangueras: mangueras)
    }()

    static let tanques: [EstadoTanque] = Combustible.allCases.map { c in
        EstadoTanque(tanqueId: UUID(), sucursalId: sucursalId, combustible: c, capacidadGal: 1000, nivelEstimadoGal: 500, porcentaje: 50,
                     nCompras: 0, nPerdidas: 0, baseEn: nil, autonomiaDias: nil, autonomiaDisponible: false, estado: .optimo)
    }

    static func borrador(para bombas: [Bomba], infra: Infraestructura = Ejemplo.infra, corte: Corte) -> [LecturaManguera] {
        bombas.flatMap { b in
            infra.mangueras(de: b).map {
                LecturaManguera(id: UUID(), corteId: corte.id, mangueraId: $0.id, lecturaInicialManualGal: nil, lecturaFinalGal: 100)
            }
        }
    }
}

final class CorteFalso: CorteService, @unchecked Sendable {
    var corte = Ejemplo.corte()
    var infra = Ejemplo.infra
    var borrador: [LecturaManguera] = []
    var iniciales: [UUID: Decimal] = [:]
    var cambios: [CambioMedidor] = []
    var previo: [ResumenPrevio] = []
    var error: Error?
    var errorAlCerrar: Error?
    var guardadas: [(UUID, [LecturaCaptura])] = []
    var cierre: (UUID, [NivelMedido], TipoCorte?)?
    var llamadas: [String] = []

    func corteEnCurso(sucursalId: UUID) async throws -> Corte { if let e = error { throw e }; return corte }
    func infraestructura(sucursalId: UUID) async throws -> Infraestructura { infra }
    func borradorLecturas(corteId: UUID) async throws -> [LecturaManguera] { borrador }
    func inicialesDerivadas(corte: Corte) async throws -> [UUID: Decimal] { iniciales }
    func guardarLecturas(corteId: UUID, bombaId: UUID, lecturas: [LecturaCaptura]) async throws {
        if let e = error { throw e }
        guardadas.append((bombaId, lecturas))
    }
    func cambiosMedidor(corteId: UUID) async throws -> [CambioMedidor] { cambios }
    func registrarCambioMedidor(corteId: UUID, mangueraId: UUID, finalViejo: Decimal, inicialNuevo: Decimal, nota: String) async throws {
        if let e = error { throw e }
        llamadas.append("cambio:\(finalViejo):\(inicialNuevo):\(nota)")
    }
    func eliminarCambioMedidor(corteId: UUID, mangueraId: UUID) async throws { llamadas.append("eliminarCambio") }
    func resumenPrevio(corteId: UUID, niveles: [NivelMedido]) async throws -> [ResumenPrevio] { if let e = error { throw e }; return previo }
    func cerrar(corteId: UUID, niveles: [NivelMedido], tipoInicial: TipoCorte?) async throws -> ResultadoCierreCorte {
        if let e = errorAlCerrar { throw e }
        cierre = (corteId, niveles, tipoInicial)
        return ResultadoCierreCorte(corteId: corteId, tipo: tipoInicial ?? .matutino, fechaOperativa: "2026-10-04", siguienteCorteId: UUID())
    }
}

final class LineasFalso: LineasCorteService, @unchecked Sendable {
    var comprasLista: [CompraCombustible] = []
    var perdidasLista: [PerdidaCombustible] = []
    var vaciadosLista: [VaciadoTanque] = []
    var error: Error?
    var llamadas: [String] = []
    var ultimoVaciado: (MotivoVaciado, Decimal, Combustible?, Decimal?, String)?

    func compras(corteId: UUID) async throws -> [CompraCombustible] { if let e = error { throw e }; return comprasLista }
    func registrarCompra(corteId: UUID, tanqueId: UUID, galones: Decimal, proveedor: String?) async throws {
        if let e = error { throw e }
        llamadas.append("compra:\(galones):\(proveedor ?? "nil")")
    }
    func editarCompra(id: UUID, galones: Decimal, proveedor: String?) async throws {
        if let e = error { throw e }
        llamadas.append("editarCompra:\(galones)")
    }
    func eliminarCompra(id: UUID) async throws {
        if let e = error { throw e }
        llamadas.append("eliminarCompra"); comprasLista.removeAll { $0.id == id }
    }
    func perdidas(corteId: UUID) async throws -> [PerdidaCombustible] { if let e = error { throw e }; return perdidasLista }
    func registrarPerdida(corteId: UUID, tanqueId: UUID, tipo: TipoPerdida, galones: Decimal, bombaId: UUID?, nota: String) async throws {
        if let e = error { throw e }
        llamadas.append("perdida:\(tipo.rawValue):\(galones):\(bombaId == nil ? "sinBomba" : "conBomba")")
    }
    func editarPerdida(id: UUID, tipo: TipoPerdida, galones: Decimal, bombaId: UUID?, nota: String) async throws {
        if let e = error { throw e }
        llamadas.append("editarPerdida")
    }
    func eliminarPerdida(id: UUID) async throws { if let e = error { throw e }; llamadas.append("eliminarPerdida") }
    func vaciados(corteId: UUID) async throws -> [VaciadoTanque] { vaciadosLista }
    func registrarVaciado(corteId: UUID, tanqueId: UUID, motivo: MotivoVaciado, nivelMedido: Decimal,
                          combustibleErroneo: Combustible?, galonesErroneos: Decimal?, nota: String) async throws {
        if let e = error { throw e }
        ultimoVaciado = (motivo, nivelMedido, combustibleErroneo, galonesErroneos, nota)
    }
}

final class TanquesFalso: TanquesService, @unchecked Sendable {
    var lista = Ejemplo.tanques
    func estado(sucursalId: UUID?) async throws -> [EstadoTanque] { lista }
}

final class DashboardFalso: DashboardService, @unchecked Sendable {
    var filas: [DashboardCombustible] = []
    var cortes: [Corte] = []
    var ingresos: [TiendaIngreso] = []
    var anulaciones: [TiendaAnulacion] = []
    var cajas: [TiendaCaja] = []
    var stock: [StockBajo] = []
    var error: Error?
    var ultimoRango: (String, String, UUID?)?
    func combustible(desde: String, hasta: String, sucursalId: UUID?) async throws -> [DashboardCombustible] {
        if let e = error { throw e }
        ultimoRango = (desde, hasta, sucursalId)
        return filas.filter { $0.fechaOperativa >= desde && $0.fechaOperativa <= hasta && (sucursalId == nil || $0.sucursalId == sucursalId) }
    }
    var soloDelDia: Bool = false
    func cortesFiltro() { soloDelDia = true }
    func cortesCerrados(desde: String, hasta: String, sucursalId: UUID?) async throws -> [Corte] {
        // Imita al servidor: solo los cortes cuya fecha operativa cae en el rango y que son de la sucursal pedida.
        cortes.filter { c in
            guard let f = c.fechaOperativa else { return false }
            return f >= desde && f <= hasta && (sucursalId == nil || c.sucursalId == sucursalId)
        }
    }
    func tiendaIngresos(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaIngreso] { ingresos }
    func tiendaAnulaciones(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaAnulacion] { anulaciones }
    func tiendaCajas(desde: String, hasta: String, sucursalId: UUID?) async throws -> [TiendaCaja] { cajas }
    func stockBajo(sucursalId: UUID?) async throws -> [StockBajo] { stock }
}

final class TiendaFalso: TiendaService, @unchecked Sendable {
    var abiertas = 0
    var inv: [InventarioSucursal] = []
    var entradasLista: [EntradaInventario] = []
    var bajasLista: [BajaInventario] = []
    var ventasLista: [Venta] = []
    var lineasLista: [VentaLinea] = []
    var cajasLista: [CajaDelCorte] = []
    var error: Error?
    var llamadas: [String] = []
    var resultadoCaja = ResultadoCierreCaja(esperadoUsd: 50, contadoUsd: 48, diferenciaUsd: -2)
    func cajasAbiertas(sucursalId: UUID) async throws -> Int { abiertas }
    func inventario(sucursalId: UUID) async throws -> [InventarioSucursal] { if let e = error { throw e }; return inv }
    func entradas(corteId: UUID) async throws -> [EntradaInventario] { entradasLista }
    func bajas(corteId: UUID) async throws -> [BajaInventario] { bajasLista }
    func registrarEntrada(corteId: UUID, articuloId: UUID, cantidad: Int, proveedor: String?) async throws {
        if let e = error { throw e }
        llamadas.append("entrada:\(cantidad):\(proveedor ?? "nil")")
    }
    func eliminarEntrada(id: UUID) async throws { if let e = error { throw e }; llamadas.append("eliminarEntrada") }
    func registrarBaja(corteId: UUID, articuloId: UUID, cantidad: Int, motivo: MotivoBaja, nota: String?) async throws {
        if let e = error { throw e }
        llamadas.append("baja:\(cantidad):\(motivo.rawValue):\(nota ?? "nil")")
    }
    func eliminarBaja(id: UUID) async throws { if let e = error { throw e }; llamadas.append("eliminarBaja") }
    func fijarStockMinimo(articuloId: UUID, minimo: Int) async throws {
        if let e = error { throw e }
        llamadas.append("minimo:\(minimo)")
    }
    func ventas(corteId: UUID) async throws -> [Venta] { ventasLista }
    func lineas(ventaId: UUID) async throws -> [VentaLinea] { lineasLista }
    func anularVenta(ventaId: UUID, motivo: String) async throws {
        if let e = error { throw e }
        llamadas.append("anular:\(motivo)")
    }
    func cajas(corteId: UUID) async throws -> [CajaDelCorte] { cajasLista }
    func cerrarCajaForzado(sesionId: UUID, contado: Decimal, motivo: String) async throws -> ResultadoCierreCaja {
        if let e = error { throw e }
        llamadas.append("forzado:\(contado):\(motivo)")
        return resultadoCaja
    }
}

final class CajaFalso: CajaService, @unchecked Sendable {
    var sesion: SesionCaja?
    var articulos: [ArticuloPOS] = []
    var ventasLista: [Venta] = []
    var lineasLista: [VentaLinea] = []
    var error: Error?
    var errorVenta: Error?
    var llamadas: [String] = []
    var ultimaVenta: (MetodoPago, Decimal?, [LineaVenta])?
    var resultadoVenta = ResultadoVenta(ventaId: UUID(), numero: 7, totalUsd: Decimal(string: "4.5")!, recibidoUsd: 5, vueltoUsd: Decimal(string: "0.5")!)
    var resultadoCierre = ResultadoCierreCaja(esperadoUsd: 70, contadoUsd: 70, diferenciaUsd: 0)
    func sesionAbierta() async throws -> SesionCaja? { if let e = error { throw e }; return sesion }
    func abrir(fondo: Decimal) async throws {
        if let e = error { throw e }
        llamadas.append("abrir:\(fondo)")
    }
    func catalogo() async throws -> [ArticuloPOS] { if let e = error { throw e }; return articulos }
    func registrarVenta(sesionId: UUID, metodo: MetodoPago, recibido: Decimal?, lineas: [LineaVenta]) async throws -> ResultadoVenta {
        if let e = errorVenta { throw e }
        ultimaVenta = (metodo, recibido, lineas)
        return resultadoVenta
    }
    func ventas(sesionId: UUID) async throws -> [Venta] { ventasLista }
    func lineas(ventaId: UUID) async throws -> [VentaLinea] { lineasLista }
    func cerrar(sesionId: UUID, contado: Decimal) async throws -> ResultadoCierreCaja {
        if let e = error { throw e }
        llamadas.append("cerrar:\(contado)")
        return resultadoCierre
    }
}

final class AlmacenFalso: AlmacenNiveles, @unchecked Sendable {
    var datos: [UUID: [UUID: String]] = [:]
    func leer(corteId: UUID) -> [UUID: String] { datos[corteId] ?? [:] }
    func guardar(corteId: UUID, niveles: [UUID: String]) { datos[corteId] = niveles }
    func borrar(corteId: UUID) { datos[corteId] = nil }
}

final class ReportesFalso: ReportesService, @unchecked Sendable {
    var cortes: [Corte] = []
    var resumen: [ResumenCorte] = []
    var reporteDevuelto: ReporteCorte?
    var error: Error?
    var ajuste: (UUID, Decimal, String)?
    func historial(sucursalId: UUID?, limite: Int) async throws -> [Corte] { if let e = error { throw e }; return cortes }
    func resumenes(corteIds: [UUID]) async throws -> [ResumenCorte] { resumen.filter { corteIds.contains($0.corteId) } }
    func corte(id: UUID) async throws -> Corte { cortes.first { $0.id == id } ?? Ejemplo.corte() }
    func reporte(corte: Corte) async throws -> ReporteCorte {
        if let e = error { throw e }
        return reporteDevuelto!
    }
    func registrarAjuste(corteId: UUID, mangueraId: UUID, valor: Decimal, motivo: String) async throws {
        if let e = error { throw e }
        ajuste = (mangueraId, valor, motivo)
    }
    var perdidasLista: [PerdidaCombustible] = []
    var ultimoFiltroPerdidas: (UUID?, TipoPerdida?, String?, String?)?
    func perdidas(sucursalId: UUID?, tipo: TipoPerdida?, desde: String?, hasta: String?, limite: Int) async throws -> [PerdidaCombustible] {
        if let e = error { throw e }
        ultimoFiltroPerdidas = (sucursalId, tipo, desde, hasta)
        return perdidasLista
    }
}

final class PersonalFalso: PersonalService, @unchecked Sendable {
    var emp: [Empleado] = []
    var tur: [Turno] = []
    var asig: [AsignacionTurno] = []
    var turnoAhora: [EmpleadoEnTurno] = []
    var error: Error?
    var llamadas: [String] = []
    var momentoConsultado: Date?
    func empleados(sucursalId: UUID) async throws -> [Empleado] { if let e = error { throw e }; return emp }
    func turnos(sucursalId: UUID) async throws -> [Turno] { tur }
    func asignaciones(sucursalId: UUID) async throws -> [AsignacionTurno] { asig }
    func crearEmpleado(sucursalId: UUID, nombre: String, cargo: CargoEmpleado, telefono: String?, fechaIngreso: String?, activo: Bool) async throws {
        if let e = error { throw e }
        llamadas.append("crearEmpleado:\(nombre):\(cargo.rawValue):\(telefono ?? "nil"):\(fechaIngreso ?? "nil"):\(activo)")
    }
    func editarEmpleado(id: UUID, nombre: String, cargo: CargoEmpleado, telefono: String?, fechaIngreso: String?, activo: Bool) async throws {
        if let e = error { throw e }
        llamadas.append("editarEmpleado:\(nombre):\(telefono ?? "nil"):\(activo)")
    }
    func crearTurno(sucursalId: UUID, nombre: String, horaInicio: String, horaFin: String, activo: Bool) async throws {
        if let e = error { throw e }
        llamadas.append("crearTurno:\(nombre):\(horaInicio):\(horaFin)")
    }
    func editarTurno(id: UUID, nombre: String, horaInicio: String, horaFin: String, activo: Bool) async throws {
        if let e = error { throw e }
        llamadas.append("editarTurno:\(horaInicio):\(horaFin):\(activo)")
    }
    func asignar(empleadoId: UUID, turnoId: UUID, sucursalId: UUID, dias: [Int]) async throws {
        if let e = error { throw e }
        llamadas.append("asignar:\(dias)")
    }
    func quitarAsignacion(empleadoId: UUID) async throws { llamadas.append("quitar") }
    func enTurno(sucursalId: UUID, momento: Date) async throws -> [EmpleadoEnTurno] {
        momentoConsultado = momento
        return turnoAhora
    }
}
