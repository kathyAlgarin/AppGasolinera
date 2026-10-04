import SwiftUI

/// Icono «?» que abre un globo con la explicación; se cierra tocando fuera.
struct AyudaBoton: View {
    let texto: String
    @State private var abierto = false

    var body: some View {
        Button {
            abierto = true
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundColor(.gas76Orange)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ayuda")
        .popover(isPresented: $abierto) {
            Text(texto)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)   // que el texto use todas las líneas que necesite
                .frame(width: 280, alignment: .leading)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// Etiqueta con su ayuda al lado.
struct TituloConAyuda: View {
    let titulo: String
    let ayuda: String
    var body: some View {
        HStack(spacing: 4) {
            Text(titulo)
            AyudaBoton(texto: ayuda)
        }
    }
}
