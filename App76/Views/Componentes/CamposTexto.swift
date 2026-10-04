import SwiftUI

struct CampoTexto: View {
    let titulo: String
    @Binding var texto: String
    var placeholder = ""
    var teclado: UIKeyboardType = .default
    var capitalizacion: TextInputAutocapitalization = .sentences
    var contenido: UITextContentType?
    var ayuda: String?
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(titulo).font(.subheadline).foregroundColor(.secondary)
                if let ayuda { AyudaBoton(texto: ayuda) }
            }
            TextField(placeholder, text: $texto)
                .keyboardType(teclado)
                .textInputAutocapitalization(capitalizacion)
                .textContentType(contenido)
                .autocorrectionDisabled(teclado == .emailAddress)
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

/// Contraseña con el ojo para verla.
struct CampoPassword: View {
    let titulo: String
    @Binding var texto: String
    var nueva = false
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.subheadline).foregroundColor(.secondary)
            HStack {
                Group {
                    if visible {
                        TextField("", text: $texto)
                    } else {
                        SecureField("", text: $texto)
                    }
                }
                .textContentType(nueva ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Button {
                    visible.toggle()
                } label: {
                    Image(systemName: visible ? "eye.slash" : "eye").foregroundColor(.secondary)
                }
                .accessibilityLabel(visible ? "Ocultar contraseña" : "Mostrar contraseña")
            }
            .padding(10)
            .background(Color.gas76Card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.28), lineWidth: 1))
        }
    }
}

/// Campo de varias líneas para notas y motivos.
struct CampoNota: View {
    let titulo: String
    @Binding var texto: String
    var obligatorio = false
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo + (obligatorio ? " (obligatoria)" : " (opcional)"))
                .font(.subheadline).foregroundColor(.secondary)
            TextField("", text: $texto, axis: .vertical)
                .lineLimit(2...5)
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
