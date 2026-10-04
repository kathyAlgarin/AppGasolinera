import Foundation

/// Precios vigentes por sucursal y combustible, a partir del historial completo de `precios`.
@MainActor
final class PreciosViewModel: ObservableObject {
    struct Datos: Equatable {
        var sucursales: [Sucursal]
        var historial: [Precio]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published var sucursalId: UUID?

    private let sucursalesServicio: SucursalesService
    private let preciosServicio: PreciosService

    init(sucursales: SucursalesService, precios: PreciosService) {
        self.sucursalesServicio = sucursales
        self.preciosServicio = precios
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            async let s = sucursalesServicio.listar()
            async let p = preciosServicio.historial()
            let (suc, hist) = try await (s, p)
            let ordenadas = suc.sorted { $0.nombre < $1.nombre }
            estado = .listo(Datos(sucursales: ordenadas, historial: hist))
            if sucursalId == nil || !ordenadas.contains(where: { $0.id == sucursalId }) {
                sucursalId = (ordenadas.first { $0.activa } ?? ordenadas.first)?.id
            }
        } catch {
            estado.registrarFallo(error)
        }
    }

    var sucursalActual: Sucursal? {
        estado.valor?.sucursales.first { $0.id == sucursalId }
    }

    /// El vigente es el de mayor `vigente_desde` que ya empezó.
    func vigente(_ combustible: Combustible, ahora: Date = Date()) -> Precio? {
        guard let datos = estado.valor, let id = sucursalId else { return nil }
        return datos.historial
            .filter { $0.sucursalId == id && $0.combustible == combustible && $0.vigenteDesde <= ahora }
            .max { $0.vigenteDesde < $1.vigenteDesde }
    }

    var combustiblesSinPrecio: [Combustible] {
        Combustible.allCases.filter { vigente($0) == nil }
    }

    /// Historial de la sucursal elegida (más reciente primero).
    func historialDeSucursal() -> [Precio] {
        guard let datos = estado.valor, let id = sucursalId else { return [] }
        return datos.historial.filter { $0.sucursalId == id }.sorted { $0.vigenteDesde > $1.vigenteDesde }
    }
}
