import Foundation

/// Alta o edición de un artículo. Al editar, tipo y categoría no cambian.
@MainActor
final class ArticuloFormViewModel: ObservableObject {
    @Published var nombre: String
    @Published var categoria: CategoriaArticulo {
        didSet { if categoria == .servicios { tipo = .servicio } else if tipo == .servicio && !esEdicion { tipo = .producto } }
    }
    @Published var tipo: TipoArticulo
    @Published var precio: String
    @Published var activo: Bool
    @Published private(set) var error: String?
    @Published private(set) var guardando = false

    let articulo: Articulo?
    private let servicio: CatalogoService
    private let alGuardar: () -> Void

    var esEdicion: Bool { articulo != nil }

    init(articulo: Articulo?, servicio: CatalogoService, alGuardar: @escaping () -> Void) {
        self.articulo = articulo
        self.servicio = servicio
        self.alGuardar = alGuardar
        nombre = articulo?.nombre ?? ""
        categoria = articulo?.categoria ?? .lubricantes
        tipo = articulo?.tipo ?? .producto
        precio = articulo.map { Formateadores.paraCampo($0.precioUsd) } ?? ""
        activo = articulo?.activo ?? true
    }

    var errorNombre: String? {
        (2...80).contains(Validadores.textoLimpio(nombre).count) ? nil : "El nombre debe tener entre 2 y 80 caracteres."
    }
    var errorPrecio: String? {
        guard let v = Validadores.decimal(precio), v > 0 else { return "El precio debe ser mayor que 0." }
        return nil
    }
    var esValido: Bool { errorNombre == nil && errorPrecio == nil }

    func limpiarError() { error = nil }

    func guardar() async {
        guard esValido, let valor = Validadores.decimal(precio) else {
            error = "Revisa los campos marcados."
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            if let articulo {
                try await servicio.editar(id: articulo.id, nombre: Validadores.textoLimpio(nombre), precioUsd: valor, activo: activo)
            } else {
                try await servicio.crear(nombre: Validadores.textoLimpio(nombre), categoria: categoria, tipo: tipo,
                                         precioUsd: valor, activo: activo)
            }
            alGuardar()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
