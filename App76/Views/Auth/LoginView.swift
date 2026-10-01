import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gas76Background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 8) {
                        Image("Logo76")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                        Text("Gasolinera 76")
                            .font(.title2.bold())
                            .foregroundColor(.gas76Blue)
                        Text("Gestión de combustible")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    VStack(spacing: 16) {
                        TextField("Correo electrónico", text: $viewModel.email)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()

                        SecureField("Contraseña", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)

                        if viewModel.showError {
                            Text("Correo o contraseña incorrectos.")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }

                        Button {
                            viewModel.login()
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
