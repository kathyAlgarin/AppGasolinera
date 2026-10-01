import Foundation
import SwiftUI   // solo para Binding

struct PumpFuelKey: Hashable {
    let pumpID: UUID
    let fuelType: FuelType
}

final class CutFormViewModel: ViewModel {
    private let repository: AppRepository
    let branchID: UUID

    @Published var cutType: CutType { didSet { loadValues() } }
    @Published var levelTexts: [FuelType: String] = [:]
    @Published var saleTexts: [PumpFuelKey: String] = [:]
    @Published var errorMessage: String?
    @Published var didSave = false

    init(branchID: UUID, repository: AppRepository = .shared) {
        self.branchID = branchID
        self.repository = repository
        // Por defecto se ofrece el corte que falta: apertura y, ya hecha esta, cierre.
        let today = repository.cuts(for: branchID, on: Date())
        cutType = (today.opening != nil && today.closing == nil) ? .closing : .opening
        super.init()
        forwardChanges(from: repository)
        loadValues()
    }

    var pumps: [Pump] { repository.branch(id: branchID)?.pumps ?? [] }

    // MARK: Estado de los cortes de hoy

    private var todayCuts: (opening: FuelCut?, closing: FuelCut?) {
        repository.cuts(for: branchID, on: Date())
    }

    func isRegistered(_ type: CutType) -> Bool {
        let cuts = todayCuts
        return (type == .opening ? cuts.opening : cuts.closing) != nil
    }

    /// El corte seleccionado ya se guardó hoy: el formulario queda de solo lectura.
    var isLocked: Bool { isRegistered(cutType) }

    /// El cierre exige la apertura previa del día.
    var closingBlocked: Bool { cutType == .closing && !isRegistered(.opening) }

    var showsSales: Bool { cutType == .closing }

    func label(for type: CutType) -> String {
        isRegistered(type) ? "\(type.rawValue) ✓" : type.rawValue
    }

    var lockedMessage: String {
        "Ya registraste el corte de \(cutType.rawValue.lowercased()) de hoy. Se muestra solo para consulta y no se puede modificar."
    }

    // MARK: Valores del formulario

    /// Si el corte ya existe, muestra lo guardado; si no, precarga los niveles actuales de
    /// tanque y deja las ventas de cada bomba en 0.
    private func loadValues() {
        errorMessage = nil
        guard let branch = repository.branch(id: branchID) else { return }
        let saved = cutType == .opening ? todayCuts.opening : todayCuts.closing

        for tank in branch.tanks {
            let level = saved?.levels[tank.fuelType] ?? tank.currentLevel
            levelTexts[tank.fuelType] = String(Int(level))
        }
        for pump in branch.pumps {
            for fuel in FuelType.allCases {
                let sold = saved?.liters(pumpID: pump.id, fuelType: fuel) ?? 0
                saleTexts[PumpFuelKey(pumpID: pump.id, fuelType: fuel)] = String(Int(sold))
            }
        }
    }

    /// Mensaje de validación del nivel escrito (fuera de 0…capacidad), o nil si es válido.
    func levelWarning(for fuel: FuelType) -> String? {
        guard let capacity = repository.tank(branchID: branchID, fuelType: fuel)?.capacity,
              let level = Double(levelTexts[fuel] ?? "") else { return nil }
        if level < 0 { return "No puede ser menor que 0." }
        if level > capacity { return "Máximo \(Int(capacity)) L (capacidad del tanque)." }
        return nil
    }

    func capacity(for fuel: FuelType) -> Double {
        repository.tank(branchID: branchID, fuelType: fuel)?.capacity ?? 0
    }

    func levelBinding(for fuel: FuelType) -> Binding<String> {
        Binding(get: { self.levelTexts[fuel] ?? "" }, set: { self.levelTexts[fuel] = $0 })
    }

    func saleBinding(pump: Pump, fuel: FuelType) -> Binding<String> {
        let key = PumpFuelKey(pumpID: pump.id, fuelType: fuel)
        return Binding(get: { self.saleTexts[key] ?? "" }, set: { self.saleTexts[key] = $0 })
    }

    private func sale(_ pump: Pump, _ fuel: FuelType) -> Double? {
        Double(saleTexts[PumpFuelKey(pumpID: pump.id, fuelType: fuel)] ?? "")
    }

    var canSave: Bool {
        guard !isLocked, !closingBlocked else { return false }
        let levelsOK = FuelType.allCases.allSatisfy {
            Double(levelTexts[$0] ?? "") != nil && levelWarning(for: $0) == nil
        }
        guard showsSales else { return levelsOK }
        return levelsOK && pumps.allSatisfy { pump in
            FuelType.allCases.allSatisfy { (sale(pump, $0) ?? -1) >= 0 }
        }
    }

    func save() {
        guard canSave else { return }
        var levels: [FuelType: Double] = [:]
        for fuel in FuelType.allCases { levels[fuel] = Double(levelTexts[fuel] ?? "") ?? 0 }

        var readings: [PumpReading] = []
        if showsSales {
            for pump in pumps {
                for fuel in FuelType.allCases {
                    readings.append(PumpReading(pumpID: pump.id, fuelType: fuel, liters: sale(pump, fuel) ?? 0))
                }
            }
        }

        do {
            try repository.addCut(branchID: branchID, type: cutType, levels: levels, pumpReadings: readings)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
