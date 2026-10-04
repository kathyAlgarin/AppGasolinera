import Foundation

/// Guarda en el teléfono los niveles medidos tecleados antes de cerrar el corte (no se envían hasta cerrarlo).
protocol AlmacenNiveles {
    func leer(corteId: UUID) -> [UUID: String]
    func guardar(corteId: UUID, niveles: [UUID: String])
    func borrar(corteId: UUID)
}
