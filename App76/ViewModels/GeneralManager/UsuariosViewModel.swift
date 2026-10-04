import Foundation

@MainActor
final class UsuariosViewModel: ObservableObject {
    struct Datos: Equatable {
        var usuarios: [Perfil]
        var sucursales: [Sucursal]
    }

    @Published private(set) var estado: Carga<Datos> = .inicial
    @Published var filtroRol: RolUsuario?
    @Published var filtroSucursal: UUID?

    private let usuariosServicio: UsuariosService
    private let sucursalesServicio: SucursalesService

    init(usuarios: UsuariosService, sucursales: SucursalesService) {
        self.usuariosServicio = usuarios
        self.sucursalesServicio = sucursales
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            async let u = usuariosServicio.listar()
            async let s = sucursalesServicio.listar()
            let (usuarios, sucursales) = try await (u, s)
            estado = .listo(Datos(usuarios: usuarios, sucursales: sucursales.sorted { $0.nombre < $1.nombre }))
        } catch {
            estado.registrarFallo(error)
        }
    }

    func nombreSucursal(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return estado.valor?.sucursales.first { $0.id == id }?.nombre
    }

    var filtrados: [Perfil] {
        (estado.valor?.usuarios ?? []).filter { u in
            (filtroRol == nil || u.rol == filtroRol) && (filtroSucursal == nil || u.sucursalId == filtroSucursal)
        }
        .sorted { ($0.activo ? 0 : 1, $0.nombre) < ($1.activo ? 0 : 1, $1.nombre) }
    }
}
