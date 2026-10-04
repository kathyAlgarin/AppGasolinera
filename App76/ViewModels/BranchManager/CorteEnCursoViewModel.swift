import Foundation

/// 31 · Centro del flujo del corte: estado de cada sección y niveles medidos de los tanques.
@MainActor
final class CorteEnCursoViewModel: ObservableObject {
    struct Datos: Equatable {
        var corte: Corte
        var infra: Infraestructura
        var borrador: [LecturaManguera]
        var tanques: [EstadoTanque]
        var cambios: [CambioMedidor]
        var compras: Int
        var perdidas: Int
        var vaciados: Int
        var iniciales: [UUID: Decimal]
        var tieneTienda: Bool
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    /// Niveles medidos tecleados (texto), por tanque. Se envían al cerrar el corte.
    @Published var niveles: [UUID: String] = [:]
    @Published private(set) var errorNiveles: [UUID: String] = [:]

    let sucursalId: UUID
    private let corteServicio: CorteService
    private let lineasServicio: LineasCorteService
    private let tanquesServicio: TanquesService
    private let sucursalesServicio: SucursalesService
    private let almacen: AlmacenNiveles

    init(sucursalId: UUID, corte: CorteService, lineas: LineasCorteService, tanques: TanquesService,
         sucursales: SucursalesService, almacen: AlmacenNiveles) {
        self.sucursalId = sucursalId
        self.corteServicio = corte
        self.lineasServicio = lineas
        self.tanquesServicio = tanques
        self.sucursalesServicio = sucursales
        self.almacen = almacen
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            let corte = try await corteServicio.corteEnCurso(sucursalId: sucursalId)
            async let infra = corteServicio.infraestructura(sucursalId: sucursalId)
            async let borrador = corteServicio.borradorLecturas(corteId: corte.id)
            async let tanques = tanquesServicio.estado(sucursalId: sucursalId)
            async let cambios = corteServicio.cambiosMedidor(corteId: corte.id)
            async let compras = lineasServicio.compras(corteId: corte.id)
            async let perdidas = lineasServicio.perdidas(corteId: corte.id)
            async let vaciados = lineasServicio.vaciados(corteId: corte.id)
            async let iniciales = corteServicio.inicialesDerivadas(corte: corte)
            async let sucursales = sucursalesServicio.listar()
            let datos = try await Datos(
                corte: corte, infra: infra, borrador: borrador,
                tanques: tanques.sorted { $0.combustible.orden < $1.combustible.orden },
                cambios: cambios, compras: compras.count, perdidas: perdidas.count, vaciados: vaciados.count,
                iniciales: iniciales,
                tieneTienda: sucursales.first { $0.id == sucursalId }?.tieneTienda ?? false)
            if niveles.isEmpty { niveles = almacen.leer(corteId: corte.id) }
            estado = .listo(datos)
        } catch {
            estado.registrarFallo(error)
        }
    }

    // MARK: Bombas

    var datos: Datos? { estado.valor }
    var esPrimerCorte: Bool { datos?.corte.secuencia == 1 }

    var bombasGuardadas: Set<UUID> {
        guard let d = datos else { return [] }
        return d.infra.bombasGuardadas(borrador: d.borrador)
    }

    var bombasFaltantes: [Int] {
        guard let d = datos else { return [] }
        let guardadas = bombasGuardadas
        return d.infra.bombas.filter { !guardadas.contains($0.id) }.map(\.numero).sorted()
    }

    // MARK: Niveles de tanque

    /// Error de un nivel tecleado (vacío no cuenta como error hasta que se intente guardar).
    func errorNivel(_ tanque: EstadoTanque) -> String? {
        let texto = niveles[tanque.tanqueId] ?? ""
        guard !texto.isEmpty else { return nil }
        guard let v = Validadores.decimal(texto) else { return "Escribe un número válido." }
        if v > tanque.capacidadGal { return "No puede superar la capacidad (\(Formateadores.galones(tanque.capacidadGal)))." }
        return nil
    }

    func nivelCompleto(_ tanque: EstadoTanque) -> Bool {
        guard let v = Validadores.decimal(niveles[tanque.tanqueId] ?? "") else { return false }
        return v <= tanque.capacidadGal
    }

    var nivelesCompletos: Bool {
        guard let d = datos, !d.tanques.isEmpty else { return false }
        return d.tanques.allSatisfy(nivelCompleto)
    }

    var tanquesSinNivel: [Combustible] {
        (datos?.tanques ?? []).filter { !nivelCompleto($0) }.map(\.combustible)
    }

    /// Guarda en el teléfono los niveles (válidos o no) y reporta los errores por tanque.
    @discardableResult
    func guardarNiveles() -> Bool {
        guard let d = datos else { return false }
        var errores: [UUID: String] = [:]
        for t in d.tanques {
            let texto = niveles[t.tanqueId] ?? ""
            if texto.isEmpty { errores[t.tanqueId] = "Escribe el nivel medido." } else if let e = errorNivel(t) { errores[t.tanqueId] = e }
        }
        errorNiveles = errores
        guard errores.isEmpty else { return false }
        almacen.guardar(corteId: d.corte.id, niveles: niveles)
        return true
    }

    /// Niveles listos para enviar a `cerrar_corte`; `nil` si falta alguno.
    func nivelesParaEnviar() -> [NivelMedido]? {
        guard nivelesCompletos, let d = datos else { return nil }
        return d.tanques.compactMap { t in
            Validadores.decimal(niveles[t.tanqueId] ?? "").map { NivelMedido(tanqueId: t.tanqueId, nivelMedidoGal: $0) }
        }
    }

    /// Qué falta para poder cerrar el corte (nil si ya se puede).
    var motivoNoCierra: String? {
        var faltan: [String] = []
        let bombas = bombasFaltantes
        if !bombas.isEmpty { faltan.append(bombas.map { "Bomba \($0)" }.joined(separator: ", ")) }
        let tanques = tanquesSinNivel
        if !tanques.isEmpty { faltan.append("nivel de \(tanques.map(\.nombre).joined(separator: ", "))") }
        return faltan.isEmpty ? nil : "Faltan: " + faltan.joined(separator: " · ")
    }

    var puedeCerrar: Bool { datos != nil && motivoNoCierra == nil }

    /// Tras cerrar el corte, el borrador de niveles ya no sirve.
    func olvidarNiveles() {
        if let d = datos { almacen.borrar(corteId: d.corte.id) }
        niveles = [:]
    }
}
