import Foundation

final class ReceptionFormViewModel: ViewModel {
    private let repository: AppRepository
    private let branchID: UUID

    @Published var fuelType: FuelType = .regular
    @Published var quantityText = ""
    @Published var didSave = false

    init(branchID: UUID, repository: AppRepository = .shared) {
        self.branchID = branchID
        self.repository = repository
        super.init()
    }

    private var quantity: Double? { Double(quantityText).flatMap { $0 > 0 ? $0 : nil } }
    var canSave: Bool { quantity != nil }

    func save() {
        guard let quantity else { return }
        repository.addReception(branchID: branchID, fuelType: fuelType, quantity: quantity)
        didSave = true
    }
}
