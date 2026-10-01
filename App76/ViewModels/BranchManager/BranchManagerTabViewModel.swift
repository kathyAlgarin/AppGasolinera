import Foundation

/// Entrega el branchID del gerente en sesión para que las vistas no toquen la sesión.
final class BranchManagerTabViewModel: ViewModel {
    private let session: SessionManager

    init(session: SessionManager = .shared) {
        self.session = session
        super.init()
        forwardChanges(from: session)
    }

    var branchID: UUID? { session.currentUser?.branchID }
}
