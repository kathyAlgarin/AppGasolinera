import Foundation
import Combine

/// Sesión actual (quién inició sesión). Depende del repositorio solo para autenticar.
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published private(set) var currentUser: AppUser?
    private let repository: AppRepository

    init(repository: AppRepository = .shared) {
        self.repository = repository
    }

    @discardableResult
    func login(email: String, password: String) -> Bool {
        guard let user = repository.authenticate(email: email, password: password) else { return false }
        currentUser = user
        return true
    }

    func logout() { currentUser = nil }

    /// Devuelve false si la contraseña actual no coincide.
    func changePassword(current: String, new: String) -> Bool {
        guard var user = currentUser, user.password == current else { return false }
        user.password = new
        _ = repository.updateUser(user)
        currentUser = user
        return true
    }
}
