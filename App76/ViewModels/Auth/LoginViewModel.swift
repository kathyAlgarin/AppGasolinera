import Foundation

final class LoginViewModel: ViewModel {
    private let session: SessionManager

    @Published var email = ""
    @Published var password = ""
    @Published var showError = false

    init(session: SessionManager = .shared) {
        self.session = session
        super.init()
    }

    func login() {
        showError = !session.login(email: email, password: password)
    }
}
