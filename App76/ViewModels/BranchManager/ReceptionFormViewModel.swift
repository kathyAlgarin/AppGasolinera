import Foundation

final class ReceptionFormViewModel: ViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case reception = "Recepción"
        case loss = "Pérdida"
        var id: String { rawValue }
    }

    private let repository: AppRepository
    private let branchID: UUID

    @Published var mode: Mode = .reception
    @Published var fuelType: FuelType = .regular
    @Published var quantityText = ""
    @Published var reasonText = ""
    @Published var didSave = false

    init(branchID: UUID, repository: AppRepository = .shared) {
        self.branchID = branchID
        self.repository = repository
        super.init()
    }

    private var quantity: Double? { Double(quantityText).flatMap { $0 > 0 ? $0 : nil } }
    private var reason: String { reasonText.trimmingCharacters(in: .whitespacesAndNewlines) }

    var title: String { mode == .reception ? "Nueva recepción" : "Nueva pérdida" }
    var quantityLabel: String { mode == .reception ? "Cantidad recibida (L)" : "Litros perdidos (L)" }
    var saveLabel: String { mode == .reception ? "Registrar recepción" : "Registrar pérdida" }

    var canSave: Bool {
        quantity != nil && (mode == .reception || !reason.isEmpty)
    }

    func save() {
        guard let quantity, canSave else { return }
        switch mode {
        case .reception:
            repository.addReception(branchID: branchID, fuelType: fuelType, quantity: quantity)
        case .loss:
            repository.addLoss(branchID: branchID, fuelType: fuelType, liters: quantity, reason: reason)
        }
        didSave = true
    }
}
