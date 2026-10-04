import SwiftUI

extension View {
    /// Tarjeta estándar: ocupa todo el ancho, fondo de tarjeta y esquinas redondeadas.
    func tarjeta(radio: CGFloat = 14) -> some View {
        self.padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gas76Card)
            .clipShape(RoundedRectangle(cornerRadius: radio))
    }
}

/// Selector de sucursal en una sola línea (con «Todas» opcional).
struct SelectorSucursal: View {
    let sucursales: [Sucursal]
    @Binding var seleccion: UUID?
    var permitirTodas = true

    private var nombre: String {
        sucursales.first { $0.id == seleccion }?.nombre ?? (permitirTodas ? "Todas las sucursales" : "Elige una sucursal")
    }

    var body: some View {
        Menu {
            if permitirTodas { Button("Todas las sucursales") { seleccion = nil } }
            ForEach(sucursales) { s in
                Button(s.activa ? s.nombre : "\(s.nombre) (inactiva)") { seleccion = s.id }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "building.2").foregroundColor(.gas76Orange)
                Text(nombre).lineLimit(1).foregroundColor(.primary)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down").font(.footnote).foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.gas76Card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("Sucursal: \(nombre)")
    }
}
