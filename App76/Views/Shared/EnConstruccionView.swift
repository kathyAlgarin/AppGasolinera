import SwiftUI

/// Marcador temporal de una pestaña que aún no tiene su pantalla.
struct EnConstruccionView: View {
    let titulo: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer").font(.largeTitle).foregroundColor(.secondary)
            Text(titulo).font(.headline)
            Text("Pantalla en construcción").foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gas76Background)
        .navigationTitle(titulo)
    }
}
