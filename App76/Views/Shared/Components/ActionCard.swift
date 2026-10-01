import SwiftUI

/// Botón grande tipo tarjeta para las acciones principales del panel.
struct ActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .gas76Orange
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.bold())
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.25))
                    .clipShape(Circle())
                Spacer(minLength: 0)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .opacity(0.9)
                    .multilineTextAlignment(.leading)
            }
            .foregroundColor(.white)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background(tint.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: tint.opacity(0.3), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}
