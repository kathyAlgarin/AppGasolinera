import SwiftUI

/// Fila de lista para representar una sucursal (usada por el Gerente General).
struct BranchSummaryRow: View {
    let branch: Branch

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(branch.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    if !branch.isActive {
                        Text("Inactiva")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                    }
                }
                Text(branch.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
