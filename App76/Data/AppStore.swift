import Foundation
import Combine

/// Store central de la app. Mantiene todo el estado en memoria y expone
/// la lógica de negocio: autenticación, permisos por rol, gestión de
/// usuarios/sucursales/precios, y la consolidación de los cortes diarios
/// (ventas, compras y pérdidas por bomba).
///
/// NOTA: esta demo guarda todo en memoria (se reinicia al cerrar la app).
/// Para producción, reemplaza esta capa por persistencia real
/// (SwiftData / Core Data) y un backend con autenticación segura.
final class AppStore: ObservableObject {

    @Published var currentUser: AppUser?
    @Published var users: [AppUser] = []
    @Published var branches: [Branch] = []
    @Published var cuts: [FuelCut] = []
    @Published var prices: [FuelPrice] = []
    @Published var priceHistory: [PriceHistoryEntry] = []

    init() {
        seedDemoData()
    }

    // MARK: - Autenticación

    func login(email: String, password: String) -> Bool {
        guard let user = users.first(where: {
            $0.email.lowercased() == email.lowercased() &&
            $0.password == password &&
            $0.isActive
        }) else {
            return false
        }
        currentUser = user
        return true
    }

    func logout() {
        currentUser = nil
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
        if currentUser?.id == user.id {
            currentUser = user
        }
        return true
    }

    func branch(for user: AppUser) -> Branch? {
        guard let branchID = user.branchID else { return nil }
        return branches.first(where: { $0.id == branchID })
    }

    // MARK: - Precios (solo Gerente General, varían por sucursal)

    func currentPrice(branchID: UUID, fuelType: FuelType) -> Double? {
        prices.first(where: { $0.branchID == branchID && $0.fuelType == fuelType })?.pricePerLiter
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

    // MARK: - Cortes diarios (2 por día, con la información de las 6 bombas; se guardan con closeCut)

    enum CutError: LocalizedError {
        case eveningRequiresMorning
        case cutAlreadyClosed
        case cutIncomplete
        case exceedsStock(FuelType, Double)
        case exceedsCapacity(FuelType, Double)

        var errorDescription: String? {
            switch self {
            case .eveningRequiresMorning:
                return "Debes cerrar el corte matutino antes de registrar el vespertino."
            case .cutAlreadyClosed:
                return "Este corte ya fue guardado y no se puede editar."
            case .cutIncomplete:
                return "Debes registrar las 6 bombas antes de guardar el corte."
            case .exceedsStock(let fuel, let available):
                return "Las ventas y pérdidas de \(fuel.rawValue) superan el combustible disponible en el tanque (\(Int(available)) L)."
            case .exceedsCapacity(let fuel, let free):
                return "Las compras de \(fuel.rawValue) superan el espacio libre del tanque (máximo \(Int(free)) L)."
            }
        }
    }

    func cut(for branchID: UUID, shift: CutShift, on date: Date = Date()) -> FuelCut? {
        cuts.first {
            $0.branchID == branchID && $0.shift == shift &&
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    /// Nivel proyectado del tanque de un combustible: nivel actual + movimientos de las
    /// OTRAS bombas del corte en curso (los tanques solo se actualizan al guardar el corte).
    func projectedLevel(branchID: UUID, fuelType: FuelType, shift: CutShift,
                        excludingPump pump: Int, on date: Date = Date()) -> (level: Double, capacity: Double)? {
        guard let tank = branches.first(where: { $0.id == branchID })?.tanks.first(where: { $0.fuelType == fuelType }) else {
            return nil
        }
        let others = cut(for: branchID, shift: shift, on: date)?.readings.filter { $0.pumpNumber != pump } ?? []
        let level = others.reduce(tank.currentLevel) { partial, reading in
            let t = reading.amounts[fuelType] ?? FuelTotals()
            return partial + t.purchases - t.sales - t.losses
        }
        return (level, tank.capacity)
    }

    /// Guarda (o corrige) la información de UNA bomba (los 3 combustibles) dentro del corte
    /// del turno indicado; crea el corte con la primera bomba. Es editable mientras el corte
    /// no se haya guardado con `closeCut`. El vespertino exige el matutino guardado.
    @discardableResult
    func savePumpReading(branchID: UUID, shift: CutShift, pumpNumber: Int,
                         amounts: [FuelType: FuelTotals], date: Date = Date()) throws -> FuelCut {
        if shift == .evening, cut(for: branchID, shift: .morning, on: date)?.isClosed != true {
            throw CutError.eveningRequiresMorning
        }

        var current = cut(for: branchID, shift: shift, on: date)
            ?? FuelCut(branchID: branchID, shift: shift, date: date)
        guard !current.isClosed else { throw CutError.cutAlreadyClosed }

        // No se puede vender/perder más de lo que hay, ni comprar más de lo que cabe.
        for fuelType in FuelType.allCases {
            guard let t = amounts[fuelType],
                  let tank = projectedLevel(branchID: branchID, fuelType: fuelType, shift: shift,
                                            excludingPump: pumpNumber, on: date) else { continue }
            if tank.level + t.purchases - t.sales - t.losses < 0 {
                throw CutError.exceedsStock(fuelType, tank.level + t.purchases)
            }
            if tank.level + t.purchases - t.sales - t.losses > tank.capacity {
                throw CutError.exceedsCapacity(fuelType, tank.capacity - tank.level + t.sales + t.losses)
            }
        }

        let reading = PumpReading(pumpNumber: pumpNumber, amounts: amounts)
        if let i = current.readings.firstIndex(where: { $0.pumpNumber == pumpNumber }) {
            current.readings[i] = reading
        } else {
            current.readings.append(reading)
        }

        if let idx = cuts.firstIndex(where: { $0.id == current.id }) {
            cuts[idx] = current
        } else {
            cuts.append(current)
        }
        return current
    }

    /// "Guardar corte": exige las 6 bombas, bloquea la edición y actualiza los tanques.
    func closeCut(branchID: UUID, shift: CutShift, on date: Date = Date()) throws {
        guard let idx = cuts.firstIndex(where: {
            $0.branchID == branchID && $0.shift == shift && Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else { throw CutError.cutIncomplete }
        guard !cuts[idx].isClosed else { throw CutError.cutAlreadyClosed }
        guard cuts[idx].isComplete else { throw CutError.cutIncomplete }
        cuts[idx].isClosed = true
        applyToTanks(cuts[idx])
    }

    /// Al guardar un corte: nivel = nivel + compras − ventas − pérdidas (entre 0 y la capacidad).
    private func applyToTanks(_ cut: FuelCut) {
        guard let branchIdx = branches.firstIndex(where: { $0.id == cut.branchID }) else { return }
        for tankIdx in branches[branchIdx].tanks.indices {
            let tank = branches[branchIdx].tanks[tankIdx]
            let t = cut.totals(for: tank.fuelType)
            let level = tank.currentLevel + t.purchases - t.sales - t.losses
            branches[branchIdx].tanks[tankIdx].currentLevel = min(max(level, 0), tank.capacity)
        }
    }

    // MARK: - Consolidados (incluyen las bombas ya registradas de cortes en curso)

    /// Ventas / compras / pérdidas por tipo de combustible de un día.
    /// `branchID == nil` consolida todas las sucursales.
    func totals(branchID: UUID?, on date: Date) -> [FuelType: FuelTotals] {
        var result = Dictionary(uniqueKeysWithValues: FuelType.allCases.map { ($0, FuelTotals()) })
        for cut in cuts where (branchID == nil || cut.branchID == branchID)
            && Calendar.current.isDate(cut.date, inSameDayAs: date) {
            for fuelType in FuelType.allCases { result[fuelType]?.add(cut.totals(for: fuelType)) }
        }
        return result
    }

    /// true si ese día hay algún corte sin cerrar (los datos son parciales).
    func hasOpenCut(branchID: UUID?, on date: Date) -> Bool {
        cuts.contains {
            !$0.isClosed && !$0.readings.isEmpty
            && (branchID == nil || $0.branchID == branchID)
            && Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    /// Ingresos por combustible = litros vendidos × precio vigente de cada sucursal.
    func revenueByFuel(branchID: UUID?, on date: Date) -> [FuelType: Double] {
        var result: [FuelType: Double] = [:]
        for id in branchID.map({ [$0] }) ?? branches.map(\.id) {
            for (fuelType, t) in totals(branchID: id, on: date) {
                result[fuelType, default: 0] += t.sales * (currentPrice(branchID: id, fuelType: fuelType) ?? 0)
            }
        }
        return result
    }

    func revenue(branchID: UUID?, on date: Date) -> Double {
        revenueByFuel(branchID: branchID, on: date).values.reduce(0, +)
    }

    /// Historial diario (más reciente primero) de un combustible.
    func history(branchID: UUID?, fuelType: FuelType) -> [DayFuelSummary] {
        let calendar = Calendar.current
        let days = Set(cuts.filter { branchID == nil || $0.branchID == branchID }
            .map { calendar.startOfDay(for: $0.date) })
        return days.sorted(by: >).map { day in
            DayFuelSummary(day: day,
                           totals: totals(branchID: branchID, on: day)[fuelType] ?? FuelTotals(),
                           revenue: revenueByFuel(branchID: branchID, on: day)[fuelType] ?? 0,
                           isPartial: hasOpenCut(branchID: branchID, on: day))
        }
    }

    /// Días de autonomía = nivel actual / promedio diario vendido (según cortes cerrados).
    /// Sirve para anticipar el desabastecimiento; nil si aún no hay ventas registradas.
    func autonomyDays(branchID: UUID, tank: Tank) -> Double? {
        let closed = cuts.filter { $0.isClosed && $0.branchID == branchID }
        let days = Set(closed.map { Calendar.current.startOfDay(for: $0.date) }).count
        let sold = closed.reduce(0) { $0 + $1.totals(for: tank.fuelType).sales }
        guard days > 0, sold > 0 else { return nil }
        return tank.currentLevel / (sold / Double(days))
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
                Tank(fuelType: .premium, capacity: 7500, currentLevel: 1500),
                Tank(fuelType: .diesel, capacity: 10500, currentLevel: 6200)
            ]
        )

        // Sucursales de prueba SIN cortes de hoy, para probar el registro de cortes.
        let branch4 = Branch(
            name: "76 Oriente",
            address: "Calle Oriente 789",
            tanks: [
                Tank(fuelType: .regular, capacity: 10000, currentLevel: 8000),
                Tank(fuelType: .premium, capacity: 8000, currentLevel: 6000),
                Tank(fuelType: .diesel, capacity: 12000, currentLevel: 10000)
            ]
        )
        let branch5 = Branch(
            name: "76 Poniente",
            address: "Av. Poniente 321",
            tanks: [
                Tank(fuelType: .regular, capacity: 9000, currentLevel: 7000),
                Tank(fuelType: .premium, capacity: 7000, currentLevel: 5000),
                Tank(fuelType: .diesel, capacity: 11000, currentLevel: 9000)
            ]
        )

        branches = [branch1, branch2, branch3, branch4, branch5]

        let gm = AppUser(name: "María Gómez", email: "gerente.general@gas76.com", password: "1234", role: .generalManager)
        let bm1 = AppUser(name: "Carlos Pérez", email: "centro@gas76.com", password: "1234", role: .branchManager, branchID: branch1.id)
        let bm2 = AppUser(name: "Ana Torres", email: "norte@gas76.com", password: "1234", role: .branchManager, branchID: branch2.id)
        let bm3 = AppUser(name: "Luis Ramírez", email: "sur@gas76.com", password: "1234", role: .branchManager, branchID: branch3.id)
        let bm4 = AppUser(name: "Sofía Molina", email: "oriente@gas76.com", password: "1234", role: .branchManager, branchID: branch4.id)
        let bm5 = AppUser(name: "Diego Castro", email: "poniente@gas76.com", password: "1234", role: .branchManager, branchID: branch5.id)
        users = [gm, bm1, bm2, bm3, bm4, bm5]

        for branch in branches {
            updatePrice(branchID: branch.id, fuelType: .regular, newPrice: 1.05)
            updatePrice(branchID: branch.id, fuelType: .premium, newPrice: 1.25)
            updatePrice(branchID: branch.id, fuelType: .diesel, newPrice: 0.98)
        }


        // Cortes de ejemplo para hoy (matutino y vespertino con las 6 bombas),
        // para que los dashboards muestren datos al abrir la app.
        let calendar = Calendar.current
        let today = Date()
        let morning = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: today) ?? today
        let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today) ?? today
        let salesPerPump: [FuelType: Double] = [.regular: 90, .premium: 50, .diesel: 70]

        /// Movimientos de una bomba: cada una vende los 3 combustibles.
        func amounts(pump: Int, extra: Double, purchases: Double = 0, losses: Double = 0) -> [FuelType: FuelTotals] {
            Dictionary(uniqueKeysWithValues: FuelType.allCases.map { type in
                var t = FuelTotals(sales: (salesPerPump[type] ?? 0) + Double(pump * 4) + extra)
                if type == .regular {
                    t.purchases = purchases
                    t.losses = losses
                    t.lossReason = losses > 0 ? .shrinkage : nil
                }
                return (type, t)
            })
        }

        // Historial de los 3 días anteriores (no altera los niveles de tanque de hoy).
        let tanksBefore = branches.map(\.tanks)
        for i in branches.indices {
            for j in branches[i].tanks.indices { branches[i].tanks[j].currentLevel = branches[i].tanks[j].capacity }
        }
        for daysAgo in 1...3 {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            for branch in branches {
                for (shift, hour) in [(CutShift.morning, 6), (.evening, 20)] {
                    let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
                    for pump in 1...Pump.count {
                        try? savePumpReading(branchID: branch.id, shift: shift, pumpNumber: pump,
                                             amounts: amounts(pump: pump, extra: Double(daysAgo * 3)), date: date)
                    }
                    try? closeCut(branchID: branch.id, shift: shift, on: date)
                }
            }
        }
        for index in branches.indices { branches[index].tanks = tanksBefore[index] }

        // Cortes de hoy solo para la primera sucursal (76 Centro); el resto queda sin cortes.
        for branch in branches.prefix(1) {
            for (shift, date) in [(CutShift.morning, morning), (.evening, evening)] {
                for pump in 1...Pump.count {
                    let purchases: Double = shift == .morning && pump == 2 ? 800 : 0
                    let losses: Double = shift == .evening && pump == 3 ? 15 : 0
                    try? savePumpReading(branchID: branch.id, shift: shift, pumpNumber: pump,
                                         amounts: amounts(pump: pump, extra: 0, purchases: purchases, losses: losses),
                                         date: date)
                }
                try? closeCut(branchID: branch.id, shift: shift, on: date)
            }
        }
    }
}
