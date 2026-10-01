import Foundation

final class ProfileViewModel: ViewModel {
    private let session: SessionManager
    private let repository: AppRepository

    init(session: SessionManager = .shared, repository: AppRepository = .shared) {
        self.session = session
        self.repository = repository
        super.init()
        forwardChanges(from: session)
        forwardChanges(from: repository)
    }

    var user: AppUser? { session.currentUser }

    var branchName: String? {
        user?.branchID.flatMap { repository.branch(id: $0)?.name }
    }

    func logout() { session.logout() }
}
