import Foundation

final class ChangePasswordViewModel: ViewModel {
    private let session: SessionManager

    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var errorMessage: String?
    @Published var didSave = false

    init(session: SessionManager = .shared) {
        self.session = session
        super.init()
    }

    func save() {
        guard !newPassword.isEmpty, newPassword == confirmPassword else {
            errorMessage = "Las contraseñas nuevas no coinciden."
            return
        }
        guard session.changePassword(current: currentPassword, new: newPassword) else {
            errorMessage = "La contraseña actual no es correcta."
            return
        }
        didSave = true
    }
}
