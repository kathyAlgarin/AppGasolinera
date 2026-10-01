import Foundation
import SwiftUI   // solo para Binding

final class BranchFormViewModel: ViewModel {
    private let repository: AppRepository
    let existingBranch: Branch?

    @Published var name: String
    @Published var address: String
    @Published var capacities: [FuelType: String] = [:]
    @Published var isActive: Bool
    @Published var didSave = false

    init(existingBranch: Branch?, repository: AppRepository = .shared) {
        self.existingBranch = existingBranch
        self.repository = repository
        name = existingBranch?.name ?? ""
        address = existingBranch?.address ?? ""
        isActive = existingBranch?.isActive ?? true
        super.init()
        for type in FuelType.allCases {
            if let tank = existingBranch?.tanks.first(where: { $0.fuelType == type }) {
                capacities[type] = String(Int(tank.capacity))
            } else {
                capacities[type] = ""
            }
        }
    }

    var canSave: Bool { !name.isEmpty && !address.isEmpty }
    var pumpsText: String { "\(Branch.pumpsPerBranch) bombas" }

    func capacityBinding(for fuel: FuelType) -> Binding<String> {
        Binding(get: { self.capacities[fuel] ?? "" }, set: { self.capacities[fuel] = $0 })
    }

    func save() {
        var tanks: [Tank] = []
        for type in FuelType.allCases {
            let capacityValue = Double(capacities[type] ?? "") ?? 0
            if let existingTank = existingBranch?.tanks.first(where: { $0.fuelType == type }) {
                tanks.append(Tank(id: existingTank.id, fuelType: type, capacity: capacityValue, currentLevel: existingTank.currentLevel))
            } else {
                tanks.append(Tank(fuelType: type, capacity: capacityValue, currentLevel: 0))
            }
        }

        // Al editar se conservan las mismas bombas (mismos ids) para no perder lecturas.
        let branch = Branch(
            id: existingBranch?.id ?? UUID(),
            name: name,
            address: address,
            tanks: tanks,
            pumps: existingBranch?.pumps ?? Branch.makePumps(),
            isActive: isActive
        )
        repository.saveBranch(branch)
        didSave = true
    }
}
