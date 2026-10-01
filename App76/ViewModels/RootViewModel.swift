import Foundation

final class RootViewModel: ViewModel {
    enum Destination { case login, generalManager, branchManager }

    private let session: SessionManager

    init(session: SessionManager = .shared) {
        self.session = session
        super.init()
        forwardChanges(from: session)
    }

    var destination: Destination {
        switch session.currentUser?.role {
        case .generalManager: return .generalManager
        case .branchManager: return .branchManager
        case nil: return .login
        }
    }
}
