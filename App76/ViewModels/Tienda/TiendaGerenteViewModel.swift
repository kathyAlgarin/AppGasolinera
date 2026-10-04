import Foundation

/// 46–50 · Tienda del Gerente de Sucursal: inventario, entradas y bajas, ventas del corte y cajas.
@MainActor
final class TiendaGerenteViewModel: ObservableObject {
    struct Datos: Equatable {
        var corte: Corte
        var articulos: [Articulo]
        var inventario: [InventarioSucursal]
        var entradas: [EntradaInventario]
        var bajas: [BajaInventario]
        var ventas: [Venta]
        var cajas: [CajaDelCorte]
    }

    struct FilaInventario: Identifiable, Equatable {
        let articulo: Articulo
        let stock: Int
        let minimo: Int
        var stockBajo: Bool { stock <= minimo }
        var id: UUID { articulo.id }
    }

    struct FilaVenta: Identifiable, Equatable {
        let venta: Venta
        let cajero: String
        /// Solo se anula mientras la caja de esa venta siga abierta.
        let anulable: Bool
        var id: UUID { venta.id }
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published private(set) var error: String?

    let sucursalId: UUID
    private let corteServicio: CorteService
    private let tienda: TiendaService
    private let catalogo: CatalogoService

    init(sucursalId: UUID, corte: CorteService, tienda: TiendaService, catalogo: CatalogoService) {
        self.sucursalId = sucursalId
        self.corteServicio = corte
        self.tienda = tienda
        self.catalogo = catalogo
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            let corte = try await corteServicio.corteEnCurso(sucursalId: sucursalId)
            async let a = catalogo.listar()
            async let i = tienda.inventario(sucursalId: sucursalId)
            async let e = tienda.entradas(corteId: corte.id)
            async let b = tienda.bajas(corteId: corte.id)
            async let v = tienda.ventas(corteId: corte.id)
            async let c = tienda.cajas(corteId: corte.id)
            let (articulos, inv, ent, baj, ven, caj) = try await (a, i, e, b, v, c)
            estado = .listo(Datos(corte: corte, articulos: articulos, inventario: inv, entradas: ent, bajas: baj, ventas: ven, cajas: caj))
        } catch {
            estado.registrarFallo(error)
        }
    }

    var datos: Datos? { estado.valor }

    /// Productos (los servicios no llevan inventario) con su stock y mínimo.
    var filas: [FilaInventario] {
        guard let d = datos else { return [] }
        return d.articulos.filter { $0.tipo == .producto }.compactMap { a in
            d.inventario.first { $0.articuloId == a.id }.map { FilaInventario(articulo: a, stock: $0.stock, minimo: $0.stockMinimo) }
        }
        .sorted { ($0.stockBajo ? 0 : 1, $0.articulo.nombre) < ($1.stockBajo ? 0 : 1, $1.articulo.nombre) }
    }

    var productos: [Articulo] { filas.map(\.articulo) }
    var hayStockBajo: Bool { filas.contains(where: \.stockBajo) }

    func nombre(de articuloId: UUID) -> String { datos?.articulos.first { $0.id == articuloId }?.nombre ?? "Artículo" }

    var cajasAbiertas: [CajaDelCorte] { (datos?.cajas ?? []).filter { $0.sesion.estaAbierta } }

    var ventasDelCorte: [FilaVenta] {
        guard let d = datos else { return [] }
        let abiertas = Set(cajasAbiertas.map(\.sesion.id))
        return d.ventas.map { v in
            FilaVenta(venta: v, cajero: d.cajas.first { $0.sesion.id == v.sesionCajaId }?.cajeroNombre ?? "Cajero",
                      anulable: v.estado == .completada && abiertas.contains(v.sesionCajaId))
        }
    }

    func eliminarEntrada(_ e: EntradaInventario) async {
        await ejecutar { try await self.tienda.eliminarEntrada(id: e.id) }
    }

    func eliminarBaja(_ b: BajaInventario) async {
        await ejecutar { try await self.tienda.eliminarBaja(id: b.id) }
    }

    func limpiarError() { error = nil }

    private func ejecutar(_ operacion: () async throws -> Void) async {
        error = nil
        do {
            try await operacion()
            await cargar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}

/// 47 · Entrada de mercadería.
@MainActor
final class EntradaFormViewModel: ObservableObject {
    @Published var articuloId: UUID
    @Published var cantidad = ""
    @Published var proveedor = ""
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let productos: [Articulo]
    private let corteId: UUID
    private let servicio: TiendaService
    private let alGuardar: () -> Void

    init(corteId: UUID, productos: [Articulo], articuloInicial: UUID? = nil, servicio: TiendaService, alGuardar: @escaping () -> Void) {
        self.corteId = corteId
        self.productos = productos
        self.servicio = servicio
        self.alGuardar = alGuardar
        articuloId = articuloInicial ?? productos.first?.id ?? UUID()
    }

    var errorCantidad: String? {
        guard let n = Validadores.entero(cantidad), n > 0 else { return "La cantidad debe ser un entero mayor que 0." }
        return nil
    }
    var errorProveedor: String? { Validadores.textoLimpio(proveedor).count <= 80 ? nil : "El proveedor admite hasta 80 caracteres." }
    var esValido: Bool { errorCantidad == nil && errorProveedor == nil && !productos.isEmpty }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido, let n = Validadores.entero(cantidad) else {
            error = "Revisa los campos marcados."
            return
        }
        let prov = Validadores.textoLimpio(proveedor)
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.registrarEntrada(corteId: corteId, articuloId: articuloId, cantidad: n, proveedor: prov.isEmpty ? nil : prov)
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}

/// 48 · Baja de mercadería (vencido, dañado u otro). La cantidad no puede superar el stock.
@MainActor
final class BajaFormViewModel: ObservableObject {
    @Published var articuloId: UUID
    @Published var cantidad = ""
    @Published var motivo: MotivoBaja = .vencido
    @Published var nota = ""
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let filas: [TiendaGerenteViewModel.FilaInventario]
    private let corteId: UUID
    private let servicio: TiendaService
    private let alGuardar: () -> Void

    init(corteId: UUID, filas: [TiendaGerenteViewModel.FilaInventario], articuloInicial: UUID? = nil, servicio: TiendaService, alGuardar: @escaping () -> Void) {
        self.corteId = corteId
        self.filas = filas
        self.servicio = servicio
        self.alGuardar = alGuardar
        articuloId = articuloInicial ?? filas.first?.id ?? UUID()
    }

    var stockActual: Int { filas.first { $0.id == articuloId }?.stock ?? 0 }

    var errorCantidad: String? {
        guard let n = Validadores.entero(cantidad), n > 0 else { return "La cantidad debe ser un entero mayor que 0." }
        return n > stockActual ? "No puede superar el stock (\(stockActual))." : nil
    }
    /// Con el motivo «Otro» la nota es obligatoria.
    var errorNota: String? {
        let n = Validadores.textoLimpio(nota)
        if motivo == .otro { return n.count >= 3 ? nil : "Con el motivo «Otro» la nota es obligatoria (mínimo 3 caracteres)." }
        return n.isEmpty || n.count >= 3 ? nil : "La nota debe tener al menos 3 caracteres."
    }
    var esValido: Bool { errorCantidad == nil && errorNota == nil && !filas.isEmpty }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido, let n = Validadores.entero(cantidad) else {
            error = "Revisa los campos marcados."
            return
        }
        let nt = Validadores.textoLimpio(nota)
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.registrarBaja(corteId: corteId, articuloId: articuloId, cantidad: n, motivo: motivo, nota: nt.isEmpty ? nil : nt)
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}

/// Stock mínimo de un producto (activa el indicador «Stock bajo»).
@MainActor
final class StockMinimoViewModel: ObservableObject {
    @Published var minimo: String
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let fila: TiendaGerenteViewModel.FilaInventario
    private let servicio: TiendaService
    private let alGuardar: () -> Void

    init(fila: TiendaGerenteViewModel.FilaInventario, servicio: TiendaService, alGuardar: @escaping () -> Void) {
        self.fila = fila
        self.servicio = servicio
        self.alGuardar = alGuardar
        minimo = String(fila.minimo)
    }

    var errorMinimo: String? { Validadores.entero(minimo) == nil ? "Escribe un entero mayor o igual a 0." : nil }

    func guardar() async {
        guard let n = Validadores.entero(minimo) else {
            error = errorMinimo
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.fijarStockMinimo(articuloId: fila.articulo.id, minimo: n)
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}

/// 49 · Anular una venta (solo mientras su caja siga abierta; motivo obligatorio).
@MainActor
final class AnularVentaViewModel: ObservableObject {
    @Published var motivo = ""
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let venta: Venta
    private let servicio: TiendaService
    private let alGuardar: () -> Void

    init(venta: Venta, servicio: TiendaService, alGuardar: @escaping () -> Void) {
        self.venta = venta
        self.servicio = servicio
        self.alGuardar = alGuardar
    }

    var errorMotivo: String? { Validadores.textoLimpio(motivo).count >= 3 ? nil : "El motivo es obligatorio (mínimo 3 caracteres)." }
    var esValido: Bool { errorMotivo == nil }

    func limpiarError() { error = nil }

    func anular() async {
        guard esValido else { return }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.anularVenta(ventaId: venta.id, motivo: Validadores.textoLimpio(motivo))
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}

/// 50 · Cierre forzado de una caja que el cajero dejó abierta.
@MainActor
final class CierreForzadoViewModel: ObservableObject {
    @Published var contado = ""
    @Published var motivo = ""
    @Published private(set) var error: String?
    @Published private(set) var guardando = false
    @Published private(set) var resultado: ResultadoCierreCaja?

    let caja: CajaDelCorte
    private let servicio: TiendaService
    private let alCerrar: () -> Void

    init(caja: CajaDelCorte, servicio: TiendaService, alCerrar: @escaping () -> Void) {
        self.caja = caja
        self.servicio = servicio
        self.alCerrar = alCerrar
    }

    var errorContado: String? { Validadores.decimal(contado) == nil ? "Escribe el efectivo contado (puede ser 0)." : nil }
    var errorMotivo: String? { Validadores.textoLimpio(motivo).count >= 3 ? nil : "El motivo es obligatorio (mínimo 3 caracteres)." }
    var esValido: Bool { errorContado == nil && errorMotivo == nil }

    func limpiarError() { error = nil }

    func cerrar() async {
        guard esValido, let c = Validadores.decimal(contado) else {
            error = "Revisa los campos marcados."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            resultado = try await servicio.cerrarCajaForzado(sesionId: caja.sesion.id, contado: c, motivo: Validadores.textoLimpio(motivo))
            alCerrar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
