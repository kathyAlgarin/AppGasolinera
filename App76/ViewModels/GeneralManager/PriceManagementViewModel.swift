import Foundation

final class PriceManagementViewModel: ViewModel {
    private let repository: AppRepository

    @Published var selectedBranchID: UUID?

    init(repository: AppRepository = .shared) {
        self.repository = repository
        super.init()
        forwardChanges(from: repository)
    }

    var branches: [Branch] { repository.branches }

    var selectedBranch: Branch? {
        if let id = selectedBranchID, let branch = repository.branch(id: id) {
            return branch
        }
        return branches.first
    }

    func price(branchID: UUID, fuelType: FuelType) -> Double {
        repository.currentPrice(branchID: branchID, fuelType: fuelType) ?? 0
    }
}
