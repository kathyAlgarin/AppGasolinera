import Foundation

final class BranchManagementViewModel: ViewModel {
    private let repository: AppRepository

    init(repository: AppRepository = .shared) {
        self.repository = repository
        super.init()
        forwardChanges(from: repository)
    }

    var branches: [Branch] { repository.branches }
}
