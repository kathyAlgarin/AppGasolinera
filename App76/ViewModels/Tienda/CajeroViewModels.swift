import Foundation

/// 60 · Caja del cajero: sin caja abierta puede abrirla; con caja abierta ve su resumen.
@MainActor
final class CajaViewModel: ObservableObject {
    struct Datos: Equatable {
        var sesion: SesionCaja?
        var ventas: [Venta]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    private let servicio: CajaService

    init(servicio: CajaService) { self.servicio = servicio }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            let sesion = try await servicio.sesionAbierta()
            var ventas: [Venta] = []
            if let sesion { ventas = try await servicio.ventas(sesionId: sesion.id) }
            estado = .listo(Datos(sesion: sesion, ventas: ventas))
        } catch {
            estado.registrarFallo(error)
        }
    }

    var sesion: SesionCaja? { estado.valor?.sesion }
    var completadas: [Venta] { (estado.valor?.ventas ?? []).filter { $0.estado == .completada } }

    // Resúmenes para mostrar; el arqueo oficial (esperado y diferencia) lo calcula el servidor al cerrar la caja.
    var totalVendido: Decimal { completadas.reduce(0) { $0 + $1.totalUsd } }
    var totalEfectivo: Decimal { completadas.filter { $0.metodoPago == .efectivo }.reduce(0) { $0 + $1.totalUsd } }
    var efectivoEsperadoReferencia: Decimal { (sesion?.fondoInicialUsd ?? 0) + totalEfectivo }
}

/// 61 · Abrir caja.
@MainActor
final class AbrirCajaViewModel: ObservableObject {
    @Published var fondo = ""
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    private let servicio: CajaService
    private let alAbrir: () -> Void

    init(servicio: CajaService, alAbrir: @escaping () -> Void) {
        self.servicio = servicio
        self.alAbrir = alAbrir
    }

    var errorFondo: String? { Validadores.decimal(fondo) == nil ? "Escribe el fondo inicial (puede ser 0)." : nil }

    func limpiarError() { error = nil }

    func abrir() async {
        guard let f = Validadores.decimal(fondo) else {
            error = errorFondo
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await servicio.abrir(fondo: f)
            alAbrir()
        } catch {
            self.error = mensajeDe(error)   // p. ej. «Ya tienes una caja abierta.»
        }
    }
}

/// 62 · POS: catálogo y carrito. El total que se ve aquí es una vista previa; el servidor lo recalcula con los precios del catálogo.
@MainActor
final class PosViewModel: ObservableObject {
    @Published private(set) var estado: Carga<[ArticuloPOS]> = .inicial
    @Published var busqueda = ""
    @Published var categoria: CategoriaArticulo?
    @Published private(set) var carrito: [UUID: Int] = [:]

    private let servicio: CajaService

    init(servicio: CajaService) { self.servicio = servicio }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            let lista = try await servicio.catalogo()
            estado = .listo(lista)
            // Si el stock bajó mientras tanto, el carrito se ajusta.
            for (id, n) in carrito {
                guard let a = lista.first(where: { $0.id == id }), a.disponible else { carrito[id] = nil; continue }
                if let s = a.stock, n > s { carrito[id] = s }
            }
        } catch {
            estado.registrarFallo(error)
        }
    }

    var articulos: [ArticuloPOS] { estado.valor ?? [] }

    var filtrados: [ArticuloPOS] {
        let texto = busqueda.trimmingCharacters(in: .whitespaces)
        return articulos.filter { a in
            (categoria == nil || a.articulo.categoria == categoria)
                && (texto.isEmpty || a.articulo.nombre.range(of: texto, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }

    var categoriasDisponibles: [CategoriaArticulo] {
        CategoriaArticulo.allCases.filter { c in articulos.contains { $0.articulo.categoria == c } }
    }

    func cantidad(de a: ArticuloPOS) -> Int { carrito[a.id] ?? 0 }

    /// Suma uno al carrito sin pasar del stock.
    func agregar(_ a: ArticuloPOS) { cambiar(a, delta: 1) }

    func cambiar(_ a: ArticuloPOS, delta: Int) {
        guard a.disponible || delta < 0 else { return }
        var n = (carrito[a.id] ?? 0) + delta
        if let s = a.stock { n = min(n, s) }
        carrito[a.id] = n > 0 ? n : nil
    }

    func quitar(_ a: ArticuloPOS) { carrito[a.id] = nil }

    func vaciar() { carrito = [:] }

    struct LineaCarrito: Identifiable, Equatable {
        let articulo: ArticuloPOS
        let cantidad: Int
        var id: UUID { articulo.id }
        var subtotal: Decimal { articulo.articulo.precioUsd * Decimal(cantidad) }
    }

    var lineas: [LineaCarrito] {
        articulos.compactMap { a in carrito[a.id].map { LineaCarrito(articulo: a, cantidad: $0) } }
    }

    var unidades: Int { carrito.values.reduce(0, +) }
    var total: Decimal { lineas.reduce(0) { $0 + $1.subtotal } }
    var lineasParaEnviar: [LineaVenta] { lineas.map { LineaVenta(articuloId: $0.articulo.id, cantidad: $0.cantidad) } }
    var carritoVacio: Bool { carrito.isEmpty }
}

/// 63–65 · Cobro: método, monto recibido, vuelto en pantalla, animación de pago simulado y ticket.
@MainActor
final class CobroViewModel: ObservableObject {
    enum Fase: Equatable {
        case editando
        case pagando
        case exito(ResultadoVenta)
    }

    @Published var metodo: MetodoPago = .efectivo
    @Published var recibido = ""
    @Published private(set) var fase: Fase = .editando
    @Published private(set) var error: String?

    let sesionId: UUID
    let total: Decimal
    let lineas: [PosViewModel.LineaCarrito]
    private let servicio: CajaService
    private let duracionAnimacion: UInt64

    init(sesionId: UUID, total: Decimal, lineas: [PosViewModel.LineaCarrito], servicio: CajaService, duracionAnimacion: Double = 1.6) {
        self.sesionId = sesionId
        self.total = total
        self.lineas = lineas
        self.servicio = servicio
        self.duracionAnimacion = UInt64(duracionAnimacion * 1_000_000_000)
    }

    var recibidoDecimal: Decimal? { Validadores.decimal(recibido) }

    /// Vuelto que se previsualiza (el servidor lo recalcula al registrar la venta).
    var vueltoPrevio: Decimal? {
        guard metodo == .efectivo, let r = recibidoDecimal, r >= total else { return nil }
        return r - total
    }

    var faltante: Decimal? {
        guard metodo == .efectivo, let r = recibidoDecimal, r < total else { return nil }
        return total - r
    }

    var puedePagar: Bool {
        switch metodo {
        case .tarjeta: return true
        case .efectivo: return recibidoDecimal.map { $0 >= total } ?? false
        }
    }

    func limpiarError() { error = nil }

    /// Atajo: el cliente paga justo el total.
    func pagarExacto() { recibido = Formateadores.paraCampo(total) }

    func pagar() async {
        guard puedePagar, fase == .editando else { return }
        error = nil
        fase = .pagando
        let envio = lineas.map { LineaVenta(articuloId: $0.articulo.id, cantidad: $0.cantidad) }
        let recibidoEnviar: Decimal? = metodo == .efectivo ? recibidoDecimal : nil
        do {
            // El pago es simulado: la animación dura un mínimo aunque el servidor responda enseguida.
            async let respuesta = servicio.registrarVenta(sesionId: sesionId, metodo: metodo, recibido: recibidoEnviar, lineas: envio)
            try? await Task.sleep(nanoseconds: duracionAnimacion)
            fase = .exito(try await respuesta)
        } catch {
            fase = .editando
            self.error = mensajeDe(error)   // p. ej. «Stock insuficiente de …»: vuelve al carrito
        }
    }
}

/// 66 · Mis ventas de la caja abierta.
@MainActor
final class MisVentasViewModel: ObservableObject {
    struct Datos: Equatable {
        var ventas: [Venta]
        var nombres: [UUID: String]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published private(set) var lineas: Carga<[VentaLinea]> = .inicial

    private let servicio: CajaService

    init(servicio: CajaService) { self.servicio = servicio }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            guard let sesion = try await servicio.sesionAbierta() else {
                estado = .listo(Datos(ventas: [], nombres: [:]))
                return
            }
            async let v = servicio.ventas(sesionId: sesion.id)
            async let c = servicio.catalogo()
            let (ventas, catalogo) = try await (v, c)
            estado = .listo(Datos(ventas: ventas, nombres: Dictionary(uniqueKeysWithValues: catalogo.map { ($0.id, $0.articulo.nombre) })))
        } catch {
            estado.registrarFallo(error)
        }
    }

    func cargarLineas(de venta: Venta) async {
        lineas = .cargando
        do { lineas = .listo(try await servicio.lineas(ventaId: venta.id)) } catch { lineas.registrarFallo(error) }
    }

    func nombre(de articuloId: UUID) -> String { estado.valor?.nombres[articuloId] ?? "Artículo" }
}

/// 67 · Cerrar caja: calcula y muestra la diferencia en tiempo real antes del cierre;
/// el servidor devuelve esperado, contado y diferencia definitivos tras el arqueo oficial.
@MainActor
final class CerrarCajaViewModel: ObservableObject {
    enum EstadoDiferencia: Equatable {
        case cuadrado
        case faltante(Decimal)
        case sobrante(Decimal)

        var titulo: String {
            switch self {
            case .cuadrado: return "Cuadrado"
            case .faltante: return "Faltante"
            case .sobrante: return "Sobrante"
            }
        }

        var nombreIcono: String {
            switch self {
            case .cuadrado: return "checkmark.circle.fill"
            case .faltante: return "exclamationmark.triangle.fill"
            case .sobrante: return "plus.circle.fill"
            }
        }
    }

    @Published var contado = ""
    @Published private(set) var error: String?
    @Published private(set) var cerrando = false
    @Published private(set) var resultado: ResultadoCierreCaja?

    @Published private(set) var ventas: [Venta]?
    @Published private(set) var cargandoEsperado = false
    @Published private(set) var errorCargaEsperado: String?

    let sesion: SesionCaja
    private let servicio: CajaService
    private let alCerrar: () -> Void

    init(sesion: SesionCaja, servicio: CajaService, ventas: [Venta]? = nil, alCerrar: @escaping () -> Void) {
        self.sesion = sesion
        self.servicio = servicio
        self.ventas = ventas
        self.alCerrar = alCerrar
    }

    func cargar() async {
        guard resultado == nil else { return }
        cargandoEsperado = true
        errorCargaEsperado = nil
        do {
            ventas = try await servicio.ventas(sesionId: sesion.id)
            cargandoEsperado = false
        } catch {
            cargandoEsperado = false
            errorCargaEsperado = mensajeDe(error)
        }
    }

    var ventasEfectivo: [Venta] {
        (ventas ?? []).filter { $0.estado == .completada && $0.metodoPago == .efectivo }
    }

    var totalVentasEfectivo: Decimal {
        ventasEfectivo.reduce(Decimal.zero) { $0 + $1.totalUsd }
    }

    /// Efectivo esperado previo: fondo inicial + ventas completadas en efectivo.
    /// Es nil si aún no se han cargado las ventas de la sesión.
    var efectivoEsperado: Decimal? {
        guard ventas != nil else { return nil }
        return sesion.fondoInicialUsd + totalVentasEfectivo
    }

    /// Efectivo contado escrito por el cajero (nil si está vacío o no es un decimal válido).
    var efectivoContado: Decimal? {
        Validadores.decimal(contado)
    }

    /// diferencia = efectivoContado - efectivoEsperado
    /// Es nil si no se ha introducido un contado válido o si no se tiene el esperado.
    var diferencia: Decimal? {
        guard let contado = efectivoContado, let esperado = efectivoEsperado else { return nil }
        return contado - esperado
    }

    var estadoDiferencia: EstadoDiferencia? {
        guard let d = diferencia else { return nil }
        if d == 0 {
            return .cuadrado
        } else if d < 0 {
            return .faltante(-d)
        } else {
            return .sobrante(d)
        }
    }

    var errorContado: String? {
        Validadores.decimal(contado) == nil ? "Escribe el efectivo contado (puede ser 0)." : nil
    }

    var esValido: Bool {
        errorContado == nil && resultado == nil && !cerrando
    }

    var mensajeConfirmacion: String {
        guard let esperado = efectivoEsperado, let contado = efectivoContado, let diff = diferencia else {
            if let contado = efectivoContado {
                return "Efectivo contado: \(Formateadores.dolares(contado))\n\n¿Desea cerrar la caja con este importe? El servidor calculará el arqueo oficial."
            }
            return "¿Desea cerrar la caja?"
        }

        var lineas = [
            "Efectivo esperado: \(Formateadores.dolares(esperado))",
            "Efectivo contado: \(Formateadores.dolares(contado))"
        ]

        if diff < 0 {
            let absDiff = -diff
            lineas.append("Faltante: \(Formateadores.dolares(absDiff))")
            lineas.append("\n¿Desea cerrar la caja con esta diferencia?")
        } else if diff > 0 {
            lineas.append("Sobrante: \(Formateadores.dolares(diff))")
            lineas.append("\n¿Desea cerrar la caja con esta diferencia?")
        } else {
            lineas.append("Caja cuadrada ($0.00)")
            lineas.append("\n¿Desea confirmar el cierre de caja?")
        }

        return lineas.joined(separator: "\n")
    }

    func limpiarError() {
        error = nil
    }

    func cerrar() async {
        guard esValido, !cerrando, let c = Validadores.decimal(contado) else { return }
        cerrando = true
        error = nil
        defer { cerrando = false }
        do {
            resultado = try await servicio.cerrar(sesionId: sesion.id, contado: c)
            alCerrar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
