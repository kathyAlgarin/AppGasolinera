import SwiftUI

/// Tarjeta simple de resumen usada en los dashboards.
struct SummaryCard: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .gas76Orange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.gas76Blue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
