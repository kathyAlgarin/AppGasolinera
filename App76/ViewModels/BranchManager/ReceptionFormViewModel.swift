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
    @Published var errorMessage: String?

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

    private var tank: Tank? { repository.tank(branchID: branchID, fuelType: fuelType) }

    /// Litros máximos que admite la operación: espacio libre (recepción) o nivel actual (pérdida).
    var maxQuantity: Double {
        guard let tank else { return 0 }
        return mode == .reception ? max(tank.capacity - tank.currentLevel, 0) : tank.currentLevel
    }

    var limitHint: String {
        guard let tank else { return "" }
        return mode == .reception
            ? "Nivel actual \(Int(tank.currentLevel)) de \(Int(tank.capacity)) L · caben \(Int(maxQuantity)) L más"
            : "Nivel actual del tanque: \(Int(tank.currentLevel)) L"
    }

    /// Aviso en vivo cuando la cantidad escrita pasa del límite.
    var quantityWarning: String? {
        guard let quantity, quantity > maxQuantity else { return nil }
        return mode == .reception
            ? "Excede la capacidad: solo caben \(Int(maxQuantity)) L más en el tanque de \(fuelType.rawValue)."
            : "No puede ser mayor que el nivel actual (\(Int(maxQuantity)) L)."
    }

    /// Si el turno no está abierto (falta la apertura o ya hay cierre), no se puede registrar.
    var shiftMessage: String? { repository.shiftError(branchID: branchID)?.errorDescription }

    var canSave: Bool {
        guard shiftMessage == nil, let quantity, quantity <= maxQuantity else { return false }
        return mode == .reception || !reason.isEmpty
    }

    func save() {
        guard let quantity, canSave else { return }
        errorMessage = nil
        do {
            switch mode {
            case .reception:
                try repository.addReception(branchID: branchID, fuelType: fuelType, quantity: quantity)
            case .loss:
                try repository.addLoss(branchID: branchID, fuelType: fuelType, liters: quantity, reason: reason)
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
