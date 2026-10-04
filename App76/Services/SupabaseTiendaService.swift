import Foundation
import Supabase

struct SupabaseTiendaService: TiendaService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func cajasAbiertas(sucursalId: UUID) async throws -> Int {
        try await Traductor.ejecutar {
            let filas: [SesionCaja] = try await cliente.from("sesiones_caja").select()
                .eq("sucursal_id", value: sucursalId).is("cerrada_en", value: nil).execute().value
            return filas.count
        }
    }

    func inventario(sucursalId: UUID) async throws -> [InventarioSucursal] {
        try await Traductor.ejecutar {
            try await cliente.from("inventario_sucursal").select().eq("sucursal_id", value: sucursalId).execute().value
        }
    }

    func entradas(corteId: UUID) async throws -> [EntradaInventario] {
        try await Traductor.ejecutar {
            try await cliente.from("entradas_inventario").select().eq("corte_id", value: corteId).order("creado_en", ascending: false).execute().value
        }
    }

    func bajas(corteId: UUID) async throws -> [BajaInventario] {
        try await Traductor.ejecutar {
            try await cliente.from("bajas_inventario").select().eq("corte_id", value: corteId).order("creado_en", ascending: false).execute().value
        }
    }

    private struct EntradaParams: Encodable {
        let pCorte: UUID
        let pArticulo: UUID
        let pCantidad: Int
        let pProveedor: String?
        enum CodingKeys: String, CodingKey { case pCorte = "p_corte", pArticulo = "p_articulo", pCantidad = "p_cantidad", pProveedor = "p_proveedor" }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pCorte, forKey: .pCorte)
            try c.encode(pArticulo, forKey: .pArticulo)
            try c.encode(pCantidad, forKey: .pCantidad)
            try c.encode(pProveedor, forKey: .pProveedor)
        }
    }

    func registrarEntrada(corteId: UUID, articuloId: UUID, cantidad: Int, proveedor: String?) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("registrar_entrada", params: EntradaParams(pCorte: corteId, pArticulo: articuloId, pCantidad: cantidad, pProveedor: proveedor)).execute()
        }
    }

    private struct IdParams: Encodable { let pId: UUID }

    func eliminarEntrada(id: UUID) async throws {
        try await Traductor.ejecutar { try await cliente.rpc("eliminar_entrada", params: IdParams(pId: id)).execute() }
    }

    private struct BajaParams: Encodable {
        let pCorte: UUID
        let pArticulo: UUID
        let pCantidad: Int
        let pMotivo: MotivoBaja
        let pNota: String?
        enum CodingKeys: String, CodingKey { case pCorte = "p_corte", pArticulo = "p_articulo", pCantidad = "p_cantidad", pMotivo = "p_motivo", pNota = "p_nota" }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pCorte, forKey: .pCorte)
            try c.encode(pArticulo, forKey: .pArticulo)
            try c.encode(pCantidad, forKey: .pCantidad)
            try c.encode(pMotivo, forKey: .pMotivo)
            try c.encode(pNota, forKey: .pNota)
        }
    }

    func registrarBaja(corteId: UUID, articuloId: UUID, cantidad: Int, motivo: MotivoBaja, nota: String?) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("registrar_baja", params: BajaParams(pCorte: corteId, pArticulo: articuloId, pCantidad: cantidad, pMotivo: motivo, pNota: nota)).execute()
        }
    }

    func eliminarBaja(id: UUID) async throws {
        try await Traductor.ejecutar { try await cliente.rpc("eliminar_baja", params: IdParams(pId: id)).execute() }
    }

    private struct MinimoParams: Encodable {
        let pArticulo: UUID
        let pMinimo: Int
    }

    func fijarStockMinimo(articuloId: UUID, minimo: Int) async throws {
        try await Traductor.ejecutar {
            try await cliente.rpc("fijar_stock_minimo", params: MinimoParams(pArticulo: articuloId, pMinimo: minimo)).execute()
        }
    }

    func ventas(corteId: UUID) async throws -> [Venta] {
        try await Traductor.ejecutar {
            try await cliente.from("ventas").select().eq("corte_id", value: corteId).order("numero", ascending: false).execute().value
        }
    }

    func lineas(ventaId: UUID) async throws -> [VentaLinea] {
        try await Traductor.ejecutar {
            try await cliente.from("venta_lineas").select().eq("venta_id", value: ventaId).execute().value
        }
    }

    private struct AnularParams: Encodable {
        let pVenta: UUID
        let pMotivo: String
    }

    func anularVenta(ventaId: UUID, motivo: String) async throws {
        try await Traductor.ejecutar { try await cliente.rpc("anular_venta", params: AnularParams(pVenta: ventaId, pMotivo: motivo)).execute() }
    }

    func cajas(corteId: UUID) async throws -> [CajaDelCorte] {
        try await Traductor.ejecutar {
            let sesiones: [SesionCaja] = try await cliente.from("sesiones_caja").select().eq("corte_id", value: corteId)
                .order("abierta_en", ascending: false).execute().value
            guard !sesiones.isEmpty else { return [] }
            let perfiles: [Perfil] = (try? await cliente.from("perfiles").select().in("id", values: Array(Set(sesiones.map(\.cajeroId)))).execute().value) ?? []
            let nombres = Dictionary(uniqueKeysWithValues: perfiles.map { ($0.id, $0.nombre) })
            return sesiones.map { CajaDelCorte(sesion: $0, cajeroNombre: nombres[$0.cajeroId] ?? "Cajero") }
        }
    }

    private struct ForzadoParams: Encodable {
        let pSesion: UUID
        let pContado: Decimal
        let pMotivo: String
    }

    func cerrarCajaForzado(sesionId: UUID, contado: Decimal, motivo: String) async throws -> ResultadoCierreCaja {
        try await Traductor.ejecutar {
            try await cliente.rpc("cerrar_caja_forzado", params: ForzadoParams(pSesion: sesionId, pContado: contado, pMotivo: motivo)).execute().value
        }
    }
}

struct SupabaseCajaService: CajaService {
    private var cliente: SupabaseClient { ClienteSupabase.compartido }

    func sesionAbierta() async throws -> SesionCaja? {
        try await Traductor.ejecutar {
            let filas: [SesionCaja] = try await cliente.from("sesiones_caja").select().is("cerrada_en", value: nil).limit(1).execute().value
            return filas.first
        }
    }

    private struct AbrirParams: Encodable { let pFondo: Decimal }

    func abrir(fondo: Decimal) async throws {
        try await Traductor.ejecutar { try await cliente.rpc("abrir_caja", params: AbrirParams(pFondo: fondo)).execute() }
    }

    func catalogo() async throws -> [ArticuloPOS] {
        try await Traductor.ejecutar {
            async let articulos: [Articulo] = cliente.from("articulos").select().eq("activo", value: true).order("nombre").execute().value
            async let inventario: [InventarioSucursal] = cliente.from("inventario_sucursal").select().execute().value
            let (a, i) = try await (articulos, inventario)
            let stock = Dictionary(uniqueKeysWithValues: i.map { ($0.articuloId, $0.stock) })
            return a.map { ArticuloPOS(articulo: $0, stock: $0.tipo == .servicio ? nil : (stock[$0.id] ?? 0)) }
        }
    }

    private struct VentaParams: Encodable {
        let pSesion: UUID
        let pMetodo: MetodoPago
        let pRecibido: Decimal?
        let pLineas: [LineaVenta]
        enum CodingKeys: String, CodingKey { case pSesion = "p_sesion", pMetodo = "p_metodo", pRecibido = "p_recibido", pLineas = "p_lineas" }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pSesion, forKey: .pSesion)
            try c.encode(pMetodo, forKey: .pMetodo)
            try c.encode(pRecibido, forKey: .pRecibido)   // con tarjeta va como null
            try c.encode(pLineas, forKey: .pLineas)
        }
    }

    func registrarVenta(sesionId: UUID, metodo: MetodoPago, recibido: Decimal?, lineas: [LineaVenta]) async throws -> ResultadoVenta {
        try await Traductor.ejecutar {
            try await cliente.rpc("registrar_venta", params: VentaParams(pSesion: sesionId, pMetodo: metodo, pRecibido: recibido, pLineas: lineas)).execute().value
        }
    }

    func ventas(sesionId: UUID) async throws -> [Venta] {
        try await Traductor.ejecutar {
            try await cliente.from("ventas").select().eq("sesion_caja_id", value: sesionId).order("numero", ascending: false).execute().value
        }
    }

    func lineas(ventaId: UUID) async throws -> [VentaLinea] {
        try await Traductor.ejecutar { try await cliente.from("venta_lineas").select().eq("venta_id", value: ventaId).execute().value }
    }

    private struct CerrarParams: Encodable {
        let pSesion: UUID
        let pContado: Decimal
    }

    func cerrar(sesionId: UUID, contado: Decimal) async throws -> ResultadoCierreCaja {
        try await Traductor.ejecutar {
            try await cliente.rpc("cerrar_caja", params: CerrarParams(pSesion: sesionId, pContado: contado)).execute().value
        }
    }
}
