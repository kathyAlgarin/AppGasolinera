import Foundation

final class ForgotPasswordViewModel: ViewModel {
    @Published var email = ""
    @Published var sent = false

    var canSend: Bool { !email.isEmpty }

    func send() { sent = true }
}
