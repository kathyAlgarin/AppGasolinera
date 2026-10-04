import Foundation

struct AlmacenNivelesLocal: AlmacenNiveles {
    private func clave(_ corteId: UUID) -> String { "niveles.\(corteId.uuidString)" }

    func leer(corteId: UUID) -> [UUID: String] {
        guard let crudo = UserDefaults.standard.dictionary(forKey: clave(corteId)) as? [String: String] else { return [:] }
        return Dictionary(uniqueKeysWithValues: crudo.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
    }

    func guardar(corteId: UUID, niveles: [UUID: String]) {
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: niveles.map { ($0.key.uuidString, $0.value) }), forKey: clave(corteId))
    }

    func borrar(corteId: UUID) {
        UserDefaults.standard.removeObject(forKey: clave(corteId))
    }
}
