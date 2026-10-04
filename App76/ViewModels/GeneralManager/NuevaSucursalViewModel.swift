import Foundation

/// Alta de sucursal: nombre, dirección, tienda y, por combustible, capacidad y nivel inicial del tanque.
@MainActor
final class NuevaSucursalViewModel: ObservableObject {
    @Published var nombre = ""
    @Published var direccion = ""
    @Published var tieneTienda = false
    @Published var capacidades: [Combustible: String] = [:]
    @Published var niveles: [Combustible: String] = [:]
    @Published private(set) var error: String?
    @Published private(set) var guardando = false
    @Published private(set) var intentado = false

    private let servicio: SucursalesService
    private let alCrear: () -> Void

    init(servicio: SucursalesService, alCrear: @escaping () -> Void) {
        self.servicio = servicio
        self.alCrear = alCrear
    }

    // MARK: Validación (el servidor la repite)

    var errorNombre: String? {
        let n = Validadores.textoLimpio(nombre).count
        return (2...80).contains(n) ? nil : "El nombre debe tener entre 2 y 80 caracteres."
    }

    var errorDireccion: String? {
        let n = Validadores.textoLimpio(direccion).count
        return (3...200).contains(n) ? nil : "La dirección debe tener entre 3 y 200 caracteres."
    }

    func errorCapacidad(_ c: Combustible) -> String? {
        guard let v = Validadores.decimal(capacidades[c] ?? ""), v > 0 else { return "La capacidad debe ser mayor que 0." }
        return nil
    }

    /// El nivel inicial es opcional: vacío vale 0. Si se escribe algo, no puede superar la capacidad.
    func nivelInicial(_ c: Combustible) -> Decimal? {
        let texto = niveles[c] ?? ""
        return texto.isEmpty ? 0 : Validadores.decimal(texto)
    }

    func errorNivel(_ c: Combustible) -> String? {
        guard let n = nivelInicial(c) else { return "Escribe un número válido." }
        if let cap = Validadores.decimal(capacidades[c] ?? ""), n > cap { return "El nivel no puede superar la capacidad." }
        return nil
    }

    var esValido: Bool {
        errorNombre == nil && errorDireccion == nil
            && Combustible.allCases.allSatisfy { errorCapacidad($0) == nil && errorNivel($0) == nil }
    }

    /// Muestra el error de un campo solo cuando ya se intentó guardar o el campo tiene algo escrito.
    func mostrar(_ mensaje: String?, vacio: Bool) -> String? {
        (intentado || !vacio) ? mensaje : nil
    }

    func limpiarError() { error = nil }

    func crear() async {
        intentado = true
        guard esValido else {
            error = "Revisa los campos marcados."
            return
        }
        let tanques = Combustible.allCases.compactMap { c -> TanqueNuevo? in
            guard let cap = Validadores.decimal(capacidades[c] ?? ""), let niv = nivelInicial(c) else { return nil }
            return TanqueNuevo(combustible: c, capacidadGal: cap, nivelInicialGal: niv)
        }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            _ = try await servicio.crear(nombre: Validadores.textoLimpio(nombre), direccion: Validadores.textoLimpio(direccion),
                                         tieneTienda: tieneTienda, tanques: tanques)
            alCrear()
        } catch {
            self.error = mensajeDe(error)
        }
    }
}
