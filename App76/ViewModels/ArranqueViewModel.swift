import Foundation

@MainActor
final class ArranqueViewModel: ObservableObject {
    enum Estado: Equatable {
        case cargando
        case listo
        case sinConfigurar
        case error(String)
    }

    @Published private(set) var estado: Estado = .cargando
    private let servicio: ConexionService

    init(servicio: ConexionService = ConexionSupabaseService()) {
        self.servicio = servicio
    }

    func iniciar() async {
        guard Configuracion.estaConfigurada else {
            estado = .sinConfigurar
            return
        }
        estado = .cargando
        do {
            try await servicio.verificar()
            estado = .listo
        } catch {
            estado = .error(error.localizedDescription)
        }
    }
}
