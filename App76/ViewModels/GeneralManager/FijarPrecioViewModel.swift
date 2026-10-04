import Foundation

@MainActor
final class FijarPrecioViewModel: ObservableObject {
    enum Alcance: String, CaseIterable, Identifiable {
        case estaSucursal = "Esta sucursal"
        case elegir = "Elegir sucursales"
        case todas = "Todas"
        var id: String { rawValue }
    }

    @Published var combustible: Combustible
    @Published var precio = ""
    @Published var alcance: Alcance = .estaSucursal
    @Published var elegidas: Set<UUID> = []
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let sucursales: [Sucursal]
    let sucursalActual: UUID?
    private let servicio: PreciosService
    private let alGuardar: () -> Void

    init(sucursales: [Sucursal], sucursalActual: UUID?, combustible: Combustible = .superior,
         servicio: PreciosService, alGuardar: @escaping () -> Void) {
        self.sucursales = sucursales.filter { $0.activa }
        self.sucursalActual = sucursalActual
        self.combustible = combustible
        self.servicio = servicio
        self.alGuardar = alGuardar
        if let s = sucursalActual { elegidas = [s] }
    }

    var errorPrecio: String? {
        guard let v = Validadores.decimal(precio), v > 0 else { return "El precio debe ser mayor que 0." }
        return nil
    }

    /// Sucursales a las que se aplicará, según el alcance.
    var destino: [UUID] {
        switch alcance {
        case .estaSucursal: return sucursalActual.map { [$0] } ?? []
        case .elegir: return sucursales.filter { elegidas.contains($0.id) }.map(\.id)
        case .todas: return sucursales.map(\.id)
        }
    }

    var puedeGuardar: Bool { errorPrecio == nil && !destino.isEmpty && !guardando }

    func alternar(_ id: UUID) {
        if elegidas.contains(id) { elegidas.remove(id) } else { elegidas.insert(id) }
    }

    func limpiarError() { error = nil }

    func guardar() async {
        guard let valor = Validadores.decimal(precio), valor > 0 else {
            error = "El precio debe ser mayor que 0."
            return
        }
        guard !destino.isEmpty else {
            error = "Elige al menos una sucursal."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            _ = try await servicio.fijar(sucursales: destino, combustible: combustible, precio: valor)
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
