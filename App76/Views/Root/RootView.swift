import SwiftUI

/// Fase 0: pantalla vacía que solo comprueba que el cliente Supabase está configurado y alcanzable.
/// En la fase 1 se reemplaza por el enrutamiento por sesión y rol.
struct RootView: View {
    @StateObject private var viewModel = ArranqueViewModel()

    var body: some View {
        ZStack {
            Color.gas76Background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("Logo76")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                contenido
            }
            .padding(32)
        }
        .task { await viewModel.iniciar() }
    }

    @ViewBuilder
    private var contenido: some View {
        switch viewModel.estado {
        case .cargando:
            ProgressView("Conectando…")
        case .listo:
            Label("Conectado al servidor", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .sinConfigurar:
            textoError("Falta pegar la clave publishable en Core/Configuracion.swift.", reintentar: false)
        case .error(let mensaje):
            textoError(mensaje, reintentar: true)
        }
    }

    private func textoError(_ mensaje: String, reintentar: Bool) -> some View {
        VStack(spacing: 12) {
            Text(mensaje)
                .multilineTextAlignment(.center)
                .foregroundColor(.red)
            if reintentar {
                Button("Reintentar") { Task { await viewModel.iniciar() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.gas76Orange)
            }
        }
    }
}
