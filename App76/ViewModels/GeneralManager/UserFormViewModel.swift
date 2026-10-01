import Foundation

final class UserFormViewModel: ViewModel {
    private let repository: AppRepository
    let existingUser: AppUser?

    @Published var name: String
    @Published var email: String
    @Published var password: String
    @Published var role: UserRole
    @Published var branchID: UUID?
    @Published var isActive: Bool
    @Published var errorMessage: String?
    @Published var didSave = false

    init(existingUser: AppUser?, repository: AppRepository = .shared) {
        self.existingUser = existingUser
        self.repository = repository
        name = existingUser?.name ?? ""
        email = existingUser?.email ?? ""
        password = existingUser?.password ?? ""
        role = existingUser?.role ?? .branchManager
        branchID = existingUser?.branchID
        isActive = existingUser?.isActive ?? true
        super.init()
        forwardChanges(from: repository)
    }

    var branches: [Branch] { repository.branches }

    var isValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && (role == .generalManager || branchID != nil)
    }

    func save() {
        let user = AppUser(
            id: existingUser?.id ?? UUID(),
            name: name,
            email: email,
            password: password,
            role: role,
            branchID: role == .generalManager ? nil : branchID,
            isActive: isActive
        )

        let success = existingUser == nil ? repository.addUser(user) : repository.updateUser(user)

        if success {
            didSave = true
        } else {
            errorMessage = "Esa sucursal ya tiene un gerente asignado. Desactívalo primero o elige otra sucursal."
        }
    }
}
