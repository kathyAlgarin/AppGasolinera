import SwiftUI

/// Campo numérico único de la app: no acepta letras, signos negativos ni más de 2 decimales
/// (con `entero: true`, tampoco decimales). Lo que no cabe se descarta al escribir o pegar.
struct CampoNumerico: View {
    let titulo: String
    @Binding var texto: String
    var unidad: String?
    var entero = false
    var ayuda: String?
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(titulo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let ayuda { AyudaBoton(texto: ayuda) }
            }
            HStack {
                TextField(entero ? "0" : "0.00", text: $texto)
                    .keyboardType(entero ? .numberPad : .decimalPad)
                    .multilineTextAlignment(.leading)
                    .onChange(of: texto) { _, nuevo in
                        let filtrado = entero ? Validadores.filtrarEntero(nuevo) : Validadores.filtrarDecimal(nuevo)
                        if filtrado != nuevo { texto = filtrado }
                    }
                if let unidad {
                    Text(unidad).foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color.gas76Card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(error == nil ? Color.gray.opacity(0.28) : Color.gas76Rojo, lineWidth: 1))
            if let error {
                Text(error).font(.caption).foregroundColor(.gas76Rojo)
            }
        }
    }
}
