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
    @Published var cuts: [FuelCut] = []
    @Published var prices: [FuelPrice] = []
    @Published var priceHistory: [PriceHistoryEntry] = []

    init() {
        seedDemoData()
    }

    // MARK: - Autenticación (solo verifica credenciales; la sesión la lleva SessionManager)

    func authenticate(email: String, password: String) -> AppUser? {
        users.first {
            $0.email.lowercased() == email.lowercased() &&
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

    func addReception(branchID: UUID, fuelType: FuelType, quantity: Double, date: Date = Date()) {
        let reception = Reception(branchID: branchID, fuelType: fuelType, quantity: quantity, date: date)
        receptions.append(reception)

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
        case meterDecreased(pump: Int, fuel: FuelType)

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
                return "Faltan lecturas de contador de alguna bomba."
            case .meterDecreased(let pump, let fuel):
                return "El contador de cierre de la Bomba \(pump) (\(fuel.rawValue)) no puede ser menor que el de apertura."
            }
        }
    }

    /// Registra un corte (apertura o cierre). Valida que no se registre un cierre
    /// sin apertura previa, que no se dupliquen cortes del mismo tipo en el día y
    /// que los contadores de las bombas estén completos y no retrocedan.
    @discardableResult
    func addCut(branchID: UUID,
                type: CutType,
                levels: [FuelType: Double],
                pumpReadings: [PumpReading],
                date: Date = Date()) throws -> FuelCut {

        guard let branch = branch(id: branchID) else { throw CutError.branchNotFound }

        // Debe haber una lectura por cada bomba y cada combustible (6 × 3 = 18).
        guard pumpReadings.count == branch.pumps.count * FuelType.allCases.count else {
            throw CutError.incompleteReadings
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
            guard let opening = sameDay.first(where: { $0.type == .opening }) else {
                throw CutError.closingRequiresOpening
            }
            if sameDay.contains(where: { $0.type == .closing }) {
                throw CutError.closingAlreadyExists
            }

            // Un contador acumulado nunca puede bajar.
            for reading in pumpReadings {
                if let start = opening.meter(pumpID: reading.pumpID, fuelType: reading.fuelType),
                   reading.meterLiters < start {
                    let number = branch.pumps.first { $0.id == reading.pumpID }?.number ?? 0
                    throw CutError.meterDecreased(pump: number, fuel: reading.fuelType)
                }
            }
        }

        let cut = FuelCut(branchID: branchID, type: type, date: date, levels: levels, pumpReadings: pumpReadings)
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

    // MARK: - Contadores y reporte diario

    /// Último contador conocido de una bomba/combustible (para precargar el formulario).
    func lastMeter(branchID: UUID, pumpID: UUID, fuelType: FuelType) -> Double {
        cuts.filter { $0.branchID == branchID }
            .sorted { $0.date > $1.date }
            .lazy
            .compactMap { $0.meter(pumpID: pumpID, fuelType: fuelType) }
            .first ?? 0
    }

    /// Reporte del día: nil si faltan la apertura o el cierre.
    func dailyReport(branchID: UUID, on date: Date) -> DailyReport? {
        let pair = cuts(for: branchID, on: date)
        guard let opening = pair.opening, let closing = pair.closing else { return nil }

        let dayReceptions = receptions.filter {
            $0.branchID == branchID && $0.date >= opening.date && $0.date <= closing.date
        }
        var prices: [FuelType: Double] = [:]
        for fuel in FuelType.allCases {
            prices[fuel] = currentPrice(branchID: branchID, fuelType: fuel) ?? 0
        }
        return SalesCalculator.report(branchID: branchID, opening: opening, closing: closing,
                                      receptions: dayReceptions, prices: prices)
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

        branches = [branch1, branch2, branch3]

        let gm = AppUser(name: "María Gómez", email: "gerente.general@gas76.com", password: "1234", role: .generalManager)
        let bm1 = AppUser(name: "Carlos Pérez", email: "centro@gas76.com", password: "1234", role: .branchManager, branchID: branch1.id)
        let bm2 = AppUser(name: "Ana Torres", email: "norte@gas76.com", password: "1234", role: .branchManager, branchID: branch2.id)
        let bm3 = AppUser(name: "Luis Ramírez", email: "sur@gas76.com", password: "1234", role: .branchManager, branchID: branch3.id)
        users = [gm, bm1, bm2, bm3]

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

        func meterBase(_ pump: Pump) -> Double { 50_000 + 1_000 * Double(pump.number) }

        for branch in branches {
            let openingReadings = branch.pumps.flatMap { pump in
                FuelType.allCases.map { PumpReading(pumpID: pump.id, fuelType: $0, meterLiters: meterBase(pump)) }
            }
            let closingReadings = branch.pumps.flatMap { pump in
                FuelType.allCases.map { fuel in
                    PumpReading(pumpID: pump.id, fuelType: fuel,
                                meterLiters: meterBase(pump) + (soldByPump[fuel]?[pump.number - 1] ?? 0))
                }
            }

            let openingLevels: [FuelType: Double] = [
                .regular: branch.tanks.first(where: { $0.fuelType == .regular })?.currentLevel ?? 0,
                .premium: branch.tanks.first(where: { $0.fuelType == .premium })?.currentLevel ?? 0,
                .diesel: branch.tanks.first(where: { $0.fuelType == .diesel })?.currentLevel ?? 0
            ]
            _ = try? addCut(branchID: branch.id, type: .opening, levels: openingLevels,
                        pumpReadings: openingReadings, date: morning)

            addReception(branchID: branch.id, fuelType: .regular, quantity: 1000, date: midday)

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
