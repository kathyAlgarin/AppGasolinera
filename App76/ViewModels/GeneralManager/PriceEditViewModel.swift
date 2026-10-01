import Foundation

final class PriceEditViewModel: ViewModel {
    private let repository: AppRepository
    let branchID: UUID
    let fuelType: FuelType

    @Published var priceText: String
    @Published var didSave = false

    init(branchID: UUID, fuelType: FuelType, repository: AppRepository = .shared) {
        self.branchID = branchID
        self.fuelType = fuelType
        self.repository = repository
        let current = repository.currentPrice(branchID: branchID, fuelType: fuelType) ?? 0
        priceText = String(format: "%.2f", current)
        super.init()
        forwardChanges(from: repository)
    }

    var title: String { "\(fuelType.rawValue) · \(repository.branch(id: branchID)?.name ?? "")" }
    var history: [PriceHistoryEntry] { repository.history(branchID: branchID, fuelType: fuelType) }
    var canSave: Bool { Double(priceText) != nil }

    func save() {
        guard let newPrice = Double(priceText) else { return }
        repository.updatePrice(branchID: branchID, fuelType: fuelType, newPrice: newPrice)
        didSave = true
    }
}
