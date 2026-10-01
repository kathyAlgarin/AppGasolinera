import Foundation
import Combine

/// Repositorio central de la app. Mantiene todo el estado en memoria y expone
/// la lógica de negocio: autenticación, permisos por rol, gestión de
/// usuarios/sucursales/precios, y el cálculo automático de ventas a partir
/// de los cortes diarios y las recepciones de combustible.
///
/// NOTA: esta demo guarda todo en memoria (se reinicia al cerrar la app).
/// Para producción, reemplaza esta capa por persistencia real
/// (SwiftData / Core Data) y un backend con autenticación segura.
final class AppRepository: ObservableObject {

    static let shared = AppRepository()

    @Published var users: [AppUser] = []
    @Published var branches: [Branch] = []
    @Published var receptions: [Reception] = []
    @Published var losses: [FuelLoss] = []
    @Published var cuts: [FuelCut] = []
    @Published var prices: [FuelPrice] = []
    @Published var priceHistory: [PriceHistoryEntry] = []

    init() {
        seedDemoData()
    }

    // MARK: - Autenticación (solo verifica credenciales; la sesión la lleva SessionManager)

    func authenticate(email: String, password: String) -> AppUser? {
        users.first {
            $0.email.lowercased() == email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() &&
            $0.password == password &&
            $0.isActive
        }
    }

    // MARK: - Usuarios (solo Gerente General)

    /// Regla de negocio: solo puede existir un Gerente de Sucursal activo por sucursal.
    func canAssignBranchManager(to branchID: UUID, excluding userID: UUID? = nil) -> Bool {
        !users.contains {
            $0.branchID == branchID &&
            $0.role == .branchManager &&
            $0.isActive &&
            $0.id != userID
        }
    }

    @discardableResult
    func addUser(_ user: AppUser) -> Bool {
        if user.role == .branchManager, let branchID = user.branchID {
            guard canAssignBranchManager(to: branchID) else { return false }
        }
        users.append(user)
        return true
    }

    @discardableResult
    func updateUser(_ user: AppUser) -> Bool {
        if user.role == .branchManager, let branchID = user.branchID {
            guard canAssignBranchManager(to: branchID, excluding: user.id) else { return false }
        }
        guard let idx = users.firstIndex(where: { $0.id == user.id }) else { return false }
        users[idx] = user
        return true
    }

    func branch(for user: AppUser) -> Branch? {
        guard let branchID = user.branchID else { return nil }
        return branches.first(where: { $0.id == branchID })
    }

    // MARK: - Sucursales

    func branch(id: UUID) -> Branch? {
        branches.first { $0.id == id }
    }

    /// Inserta o reemplaza una sucursal.
    func saveBranch(_ branch: Branch) {
        if let idx = branches.firstIndex(where: { $0.id == branch.id }) {
            branches[idx] = branch
        } else {
            branches.append(branch)
        }
    }

    // MARK: - Precios (solo Gerente General, varían por sucursal)

    func currentPrice(branchID: UUID, fuelType: FuelType) -> Double? {
        prices.first(where: { $0.branchID == branchID && $0.fuelType == fuelType })?.pricePerLiter
    }

    func history(branchID: UUID, fuelType: FuelType) -> [PriceHistoryEntry] {
        priceHistory
            .filter { $0.branchID == branchID && $0.fuelType == fuelType }
            .sorted { $0.changedAt > $1.changedAt }
    }

    func updatePrice(branchID: UUID, fuelType: FuelType, newPrice: Double) {
        if let idx = prices.firstIndex(where: { $0.branchID == branchID && $0.fuelType == fuelType }) {
            let old = prices[idx].pricePerLiter
            prices[idx].pricePerLiter = newPrice
            prices[idx].updatedAt = Date()
            priceHistory.append(PriceHistoryEntry(branchID: branchID, fuelType: fuelType, oldPrice: old, newPrice: newPrice))
        } else {
            prices.append(FuelPrice(branchID: branchID, fuelType: fuelType, pricePerLiter: newPrice))
            priceHistory.append(PriceHistoryEntry(branchID: branchID, fuelType: fuelType, oldPrice: 0, newPrice: newPrice))
        }
    }

    // MARK: - Recepción de combustible

    /// Errores de validación contra la capacidad de los tanques.
    enum TankError: LocalizedError {
        case invalidQuantity
        case tankNotFound
        case receptionExceedsCapacity(fuel: FuelType, available: Double)
        case lossExceedsLevel(fuel: FuelType, current: Double)
        case levelOutOfRange(fuel: FuelType, capacity: Double)

        var errorDescription: String? {
            switch self {
            case .invalidQuantity:
                return "La cantidad debe ser mayor que 0."
            case .tankNotFound:
                return "La sucursal no tiene un tanque para ese combustible."
            case .receptionExceedsCapacity(let fuel, let available):
                return "La recepción excede la capacidad del tanque de \(fuel.rawValue): solo caben \(Int(available)) L más."
            case .lossExceedsLevel(let fuel, let current):
                return "La pérdida no puede ser mayor que el nivel actual del tanque de \(fuel.rawValue) (\(Int(current)) L)."
            case .levelOutOfRange(let fuel, let capacity):
                return "El nivel de \(fuel.rawValue) debe estar entre 0 y \(Int(capacity)) L (capacidad del tanque)."
            }
        }
    }

    /// Tanque de un combustible en una sucursal.
    func tank(branchID: UUID, fuelType: FuelType) -> Tank? {
        branch(id: branchID)?.tanks.first { $0.fuelType == fuelType }
    }

    /// Registra una recepción. No permite pasar de la capacidad del tanque.
    func addReception(branchID: UUID, fuelType: FuelType, quantity: Double, date: Date = Date()) throws {
        guard quantity > 0 else { throw TankError.invalidQuantity }
        guard let tank = tank(branchID: branchID, fuelType: fuelType) else { throw TankError.tankNotFound }
        let available = tank.capacity - tank.currentLevel
        guard quantity <= available else {
            throw TankError.receptionExceedsCapacity(fuel: fuelType, available: max(available, 0))
        }

        receptions.append(Reception(branchID: branchID, fuelType: fuelType, quantity: quantity, date: date))

        if let branchIdx = branches.firstIndex(where: { $0.id == branchID }),
           let tankIdx = branches[branchIdx].tanks.firstIndex(where: { $0.fuelType == fuelType }) {
            branches[branchIdx].tanks[tankIdx].currentLevel += quantity
        }
    }

    // MARK: - Cortes diarios (apertura / cierre)

    enum CutError: LocalizedError {
        case openingAlreadyExists
        case closingRequiresOpening
        case closingAlreadyExists
        case branchNotFound
        case incompleteReadings
        case negativeLiters

        var errorDescription: String? {
            switch self {
            case .openingAlreadyExists:
                return "Ya existe un corte de apertura registrado hoy para esta sucursal."
            case .closingRequiresOpening:
                return "Debes registrar el corte de apertura antes del corte de cierre."
            case .closingAlreadyExists:
                return "Ya existe un corte de cierre registrado hoy para esta sucursal."
            case .branchNotFound:
                return "No se encontró la sucursal."
            case .incompleteReadings:
                return "Faltan los litros vendidos de alguna bomba."
            case .negativeLiters:
                return "Los litros no pueden ser negativos."
            }
        }
    }

    /// Registra un corte (apertura o cierre). Valida que no se registre un cierre
    /// sin apertura previa y que no se dupliquen cortes del mismo tipo en el día.
    /// La apertura registra solo niveles de tanque; el cierre exige además los litros
    /// vendidos por cada bomba y combustible (6 × 3 = 18).
    @discardableResult
    func addCut(branchID: UUID,
                type: CutType,
                levels: [FuelType: Double],
                pumpReadings: [PumpReading] = [],
                date: Date = Date()) throws -> FuelCut {

        guard let branch = branch(id: branchID) else { throw CutError.branchNotFound }

        // Los niveles de tanque deben estar entre 0 y la capacidad del tanque.
        for tank in branch.tanks {
            guard let level = levels[tank.fuelType], level >= 0, level <= tank.capacity else {
                throw TankError.levelOutOfRange(fuel: tank.fuelType, capacity: tank.capacity)
            }
        }

        let calendar = Calendar.current
        let sameDay = cuts.filter {
            $0.branchID == branchID && calendar.isDate($0.date, inSameDayAs: date)
        }

        switch type {
        case .opening:
            if sameDay.contains(where: { $0.type == .opening }) {
                throw CutError.openingAlreadyExists
            }
        case .closing:
            guard sameDay.contains(where: { $0.type == .opening }) else {
                throw CutError.closingRequiresOpening
            }
            if sameDay.contains(where: { $0.type == .closing }) {
                throw CutError.closingAlreadyExists
            }
            guard pumpReadings.count == branch.pumps.count * FuelType.allCases.count else {
                throw CutError.incompleteReadings
            }
            guard pumpReadings.allSatisfy({ $0.liters >= 0 }) else { throw CutError.negativeLiters }
        }

        let cut = FuelCut(branchID: branchID, type: type, date: date, levels: levels,
                          pumpReadings: type == .closing ? pumpReadings : [])
        cuts.append(cut)

        // El corte refleja una lectura física del tanque: actualizamos el nivel actual.
        if let branchIdx = branches.firstIndex(where: { $0.id == branchID }) {
            for (fuelType, level) in levels {
                if let tankIdx = branches[branchIdx].tanks.firstIndex(where: { $0.fuelType == fuelType }) {
                    branches[branchIdx].tanks[tankIdx].currentLevel = level
                }
            }
        }

        return cut
    }

    /// Última info de cortes de una sucursal para un día dado (para mostrar en UI).
    func cuts(for branchID: UUID, on date: Date) -> (opening: FuelCut?, closing: FuelCut?) {
        let calendar = Calendar.current
        let sameDay = cuts.filter { $0.branchID == branchID && calendar.isDate($0.date, inSameDayAs: date) }
        return (sameDay.first(where: { $0.type == .opening }), sameDay.first(where: { $0.type == .closing }))
    }

    // MARK: - Pérdidas

    /// Registra una pérdida de combustible con su razón y descuenta los litros del tanque.
    func addLoss(branchID: UUID, fuelType: FuelType, liters: Double, reason: String, date: Date = Date()) throws {
        guard liters > 0 else { throw TankError.invalidQuantity }
        guard let tank = tank(branchID: branchID, fuelType: fuelType) else { throw TankError.tankNotFound }
        guard liters <= tank.currentLevel else {
            throw TankError.lossExceedsLevel(fuel: fuelType, current: tank.currentLevel)
        }

        losses.append(FuelLoss(branchID: branchID, fuelType: fuelType, liters: liters, reason: reason, date: date))

        if let branchIdx = branches.firstIndex(where: { $0.id == branchID }),
           let tankIdx = branches[branchIdx].tanks.firstIndex(where: { $0.fuelType == fuelType }) {
            let level = branches[branchIdx].tanks[tankIdx].currentLevel
            branches[branchIdx].tanks[tankIdx].currentLevel = max(level - liters, 0)
        }
    }

    func losses(for branchID: UUID, on date: Date) -> [FuelLoss] {
        let calendar = Calendar.current
        return losses
            .filter { $0.branchID == branchID && calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Reporte diario

    /// Reporte del día: nil si faltan la apertura o el cierre.
    func dailyReport(branchID: UUID, on date: Date) -> DailyReport? {
        let pair = cuts(for: branchID, on: date)
        guard let opening = pair.opening, let closing = pair.closing else { return nil }

        let dayReceptions = receptions.filter {
            $0.branchID == branchID && $0.date >= opening.date && $0.date <= closing.date
        }
        let dayLosses = losses.filter {
            $0.branchID == branchID && $0.date >= opening.date && $0.date <= closing.date
        }
        var prices: [FuelType: Double] = [:]
        for fuel in FuelType.allCases {
            prices[fuel] = currentPrice(branchID: branchID, fuelType: fuel) ?? 0
        }
        return SalesCalculator.report(branchID: branchID, opening: opening, closing: closing,
                                      receptions: dayReceptions, losses: dayLosses, prices: prices)
    }

    // MARK: - Datos de demostración

    private func seedDemoData() {
        let branch1 = Branch(
            name: "76 Centro",
            address: "Av. Principal 123",
            tanks: [
                Tank(fuelType: .regular, capacity: 10000, currentLevel: 6500),
                Tank(fuelType: .premium, capacity: 8000, currentLevel: 4200),
                Tank(fuelType: .diesel, capacity: 12000, currentLevel: 9000)
            ]
        )

        let branch2 = Branch(
            name: "76 Norte",
            address: "Carretera Norte km 5",
            tanks: [
                Tank(fuelType: .regular, capacity: 9000, currentLevel: 5000),
                Tank(fuelType: .premium, capacity: 7000, currentLevel: 3000),
                Tank(fuelType: .diesel, capacity: 11000, currentLevel: 7000)
            ]
        )

        let branch3 = Branch(
            name: "76 Sur",
            address: "Bulevar del Sur 456",
            tanks: [
                Tank(fuelType: .regular, capacity: 9500, currentLevel: 4800),
                Tank(fuelType: .premium, capacity: 7500, currentLevel: 3200),
                Tank(fuelType: .diesel, capacity: 10500, currentLevel: 6200)
            ]
        )

        // Sucursal vacía para probar cortes: no tiene cortes de hoy, así que se puede
        // registrar apertura y cierre desde cero con el usuario prueba@gas76.com.
        let branch4 = Branch(
            name: "76 Pruebas",
            address: "Calle de Prueba 1",
            tanks: [
                Tank(fuelType: .regular, capacity: 8000, currentLevel: 5000),
                Tank(fuelType: .premium, capacity: 6000, currentLevel: 3000),
                Tank(fuelType: .diesel, capacity: 9000, currentLevel: 4000)
            ]
        )

        branches = [branch1, branch2, branch3, branch4]

        let gm = AppUser(name: "María Gómez", email: "gerente.general@gas76.com", password: "1234", role: .generalManager)
        let bm1 = AppUser(name: "Carlos Pérez", email: "centro@gas76.com", password: "1234", role: .branchManager, branchID: branch1.id)
        let bm2 = AppUser(name: "Ana Torres", email: "norte@gas76.com", password: "1234", role: .branchManager, branchID: branch2.id)
        let bm3 = AppUser(name: "Luis Ramírez", email: "sur@gas76.com", password: "1234", role: .branchManager, branchID: branch3.id)
        let bm4 = AppUser(name: "Usuario Pruebas", email: "prueba@gas76.com", password: "1234", role: .branchManager, branchID: branch4.id)
        users = [gm, bm1, bm2, bm3, bm4]

        for branch in branches {
            updatePrice(branchID: branch.id, fuelType: .regular, newPrice: 1.05)
            updatePrice(branchID: branch.id, fuelType: .premium, newPrice: 1.25)
            updatePrice(branchID: branch.id, fuelType: .diesel, newPrice: 0.98)
        }

        // Cortes y recepciones de ejemplo para el día de hoy, para que los
        // dashboards muestren datos al abrir la app por primera vez.
        let calendar = Calendar.current
        let today = Date()
        let morning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: today) ?? today
        let midday = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: today) ?? today
        let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today) ?? today

        // Litros vendidos por bomba (posición 0 = Bomba 1 ... posición 5 = Bomba 6)
        let soldByPump: [FuelType: [Double]] = [
            .regular: [150, 120, 100, 130, 110, 90],   // = 700
            .premium: [80, 60, 70, 50, 90, 50],        // = 400
            .diesel:  [100, 90, 110, 80, 120, 100]     // = 600
        ]

        // Solo las tres sucursales con historial de hoy; "76 Pruebas" queda sin cortes.
        for branch in [branch1, branch2, branch3] {
            let closingReadings = branch.pumps.flatMap { pump in
                FuelType.allCases.map { fuel in
                    PumpReading(pumpID: pump.id, fuelType: fuel,
                                liters: soldByPump[fuel]?[pump.number - 1] ?? 0)
                }
            }

            let openingLevels: [FuelType: Double] = [
                .regular: branch.tanks.first(where: { $0.fuelType == .regular })?.currentLevel ?? 0,
                .premium: branch.tanks.first(where: { $0.fuelType == .premium })?.currentLevel ?? 0,
                .diesel: branch.tanks.first(where: { $0.fuelType == .diesel })?.currentLevel ?? 0
            ]
            _ = try? addCut(branchID: branch.id, type: .opening, levels: openingLevels, date: morning)

            try? addReception(branchID: branch.id, fuelType: .regular, quantity: 1000, date: midday)

            if let updatedBranch = branches.first(where: { $0.id == branch.id }) {
                let closingLevels: [FuelType: Double] = [
                    .regular: max((updatedBranch.tanks.first(where: { $0.fuelType == .regular })?.currentLevel ?? 0) - 700, 0),
                    .premium: max((updatedBranch.tanks.first(where: { $0.fuelType == .premium })?.currentLevel ?? 0) - 400, 0),
                    .diesel: max((updatedBranch.tanks.first(where: { $0.fuelType == .diesel })?.currentLevel ?? 0) - 600, 0)
                ]
                _ = try? addCut(branchID: branch.id, type: .closing, levels: closingLevels,
                            pumpReadings: closingReadings, date: evening)
            }
        }
    }
}
