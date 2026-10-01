import SwiftUI

/// Detalle del cuadre de un combustible: cómo se calculó y por qué cuadra o no.
struct ReconciliationRowView: View {
    let row: ReconciliationRow

    private var statusColor: Color { row.isBalanced ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: row.fuel.symbolName)
                    .foregroundColor(.gas76Orange)
                Text(row.fuel.rawValue)
                    .font(.subheadline.bold())
                Spacer()
                Label(row.isBalanced ? "Cuadra" : "No cuadra",
                      systemImage: row.isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Según el tanque")
                    .font(.caption.bold())
                Text("\(Int(row.openingLevel)) apertura + \(Int(row.received)) recibido − \(Int(row.closingLevel)) cierre = \(Int(row.tankLiters)) L")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Según las bombas").font(.caption.bold())
                Spacer()
                Text("\(Int(row.pumpLiters)) L").font(.footnote).foregroundColor(.secondary)
            }

            HStack {
                Text("Diferencia (tanque − bombas)").font(.caption.bold())
                Spacer()
                Text("\(Int(row.difference.rounded())) L")
                    .font(.footnote.bold())
                    .foregroundColor(statusColor)
            }

            Text(row.explanation)
                .font(.footnote)
                .foregroundColor(statusColor)
        }
        .padding()
        .background(Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
