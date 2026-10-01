import Foundation
import SwiftUI   // solo para Binding

struct MeterKey: Hashable {
    let pumpID: UUID
    let fuelType: FuelType
}

final class CutFormViewModel: ViewModel {
    private let repository: AppRepository
    let branchID: UUID

    @Published var cutType: CutType = .opening { didSet { loadDefaults() } }
    @Published var levelTexts: [FuelType: String] = [:]
    @Published var meterTexts: [MeterKey: String] = [:]
    @Published var errorMessage: String?
    @Published var didSave = false

    init(branchID: UUID, repository: AppRepository = .shared) {
        self.branchID = branchID
        self.repository = repository
        super.init()
        forwardChanges(from: repository)
        loadDefaults()
    }

    var pumps: [Pump] { repository.branch(id: branchID)?.pumps ?? [] }

    /// Precarga: niveles actuales de tanque y último contador conocido de cada bomba.
    private func loadDefaults() {
        guard let branch = repository.branch(id: branchID) else { return }
        for tank in branch.tanks {
            levelTexts[tank.fuelType] = String(Int(tank.currentLevel))
        }
        for pump in branch.pumps {
            for fuel in FuelType.allCases {
                let last = repository.lastMeter(branchID: branchID, pumpID: pump.id, fuelType: fuel)
                meterTexts[MeterKey(pumpID: pump.id, fuelType: fuel)] = String(Int(last))
            }
        }
    }

    func levelBinding(for fuel: FuelType) -> Binding<String> {
        Binding(get: { self.levelTexts[fuel] ?? "" }, set: { self.levelTexts[fuel] = $0 })
    }

    func meterBinding(pump: Pump, fuel: FuelType) -> Binding<String> {
        let key = MeterKey(pumpID: pump.id, fuelType: fuel)
        return Binding(get: { self.meterTexts[key] ?? "" }, set: { self.meterTexts[key] = $0 })
    }

    var canSave: Bool {
        FuelType.allCases.allSatisfy { Double(levelTexts[$0] ?? "") != nil } &&
        pumps.allSatisfy { pump in
            FuelType.allCases.allSatisfy {
                Double(meterTexts[MeterKey(pumpID: pump.id, fuelType: $0)] ?? "") != nil
            }
        }
    }

    func save() {
        var levels: [FuelType: Double] = [:]
        for fuel in FuelType.allCases { levels[fuel] = Double(levelTexts[fuel] ?? "") ?? 0 }

        var readings: [PumpReading] = []
        for pump in pumps {
            for fuel in FuelType.allCases {
                let value = Double(meterTexts[MeterKey(pumpID: pump.id, fuelType: fuel)] ?? "") ?? 0
                readings.append(PumpReading(pumpID: pump.id, fuelType: fuel, meterLiters: value))
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
