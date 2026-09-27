import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gas76Background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gas76Orange)
                        Text("Gasolinera 76")
                            .font(.title2.bold())
                            .foregroundColor(.gas76Blue)
                        Text("Gestión de combustible")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    VStack(spacing: 16) {
                        TextField("Correo electrónico", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()

                        SecureField("Contraseña", text: $password)
                            .textFieldStyle(.roundedBorder)

                        if showError {
                            Text("Correo o contraseña incorrectos.")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }

                        Button {
                            let success = store.login(email: email, password: password)
                            showError = !success
                        } label: {
                            Text("Ingresar")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.gas76Orange)

                        Button("Olvidé mi contraseña") {
                            showForgotPassword = true
                        }
                        .font(.footnote)
                        .foregroundColor(.gas76Blue)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                    Spacer()
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
}
