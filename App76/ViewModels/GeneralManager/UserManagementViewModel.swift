import Foundation

final class UserManagementViewModel: ViewModel {
    private let repository: AppRepository

    init(repository: AppRepository = .shared) {
        self.repository = repository
        super.init()
        forwardChanges(from: repository)
    }

    var users: [AppUser] { repository.users }

    func roleDescription(for user: AppUser) -> String {
        if user.role == .generalManager {
            return "Gerente General"
        }
        if let branchID = user.branchID, let branch = repository.branch(id: branchID) {
            return "Gerente de \(branch.name)"
        }
        return "Gerente de Sucursal"
    }
}
