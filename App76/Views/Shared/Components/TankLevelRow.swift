import SwiftUI

/// Fila que muestra el nivel de un tanque, su alerta de reabastecimiento
/// (crítico / medio / óptimo) y, si se conoce, los días de autonomía estimados.
struct TankLevelRow: View {
    let tank: Tank
    var autonomyDays: Double? = nil

    @State private var showAutonomyInfo = false

    private var statusColor: Color {
        switch tank.status {
        case .critical: return .red
        case .medium: return .orange
        case .optimal: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: tank.fuelType.symbolName)
                    .foregroundColor(.gas76Orange)
                Text(tank.fuelType.rawValue)
                    .font(.subheadline.bold())
                Text(tank.status.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
                Spacer()
                Text("\(Int(tank.currentLevel)) / \(Int(tank.capacity)) L")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: tank.fillRatio)
                .tint(statusColor)
            if let autonomyDays {
                HStack(spacing: 4) {
                    Text("Autonomía estimada: \(autonomyDays.formatted(.number.precision(.fractionLength(1)))) días")
                        .font(.caption)
                        .foregroundColor(tank.status == .optimal ? .secondary : statusColor)
                    Button {
                        showAutonomyInfo = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                            .foregroundColor(.gas76Blue)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAutonomyInfo) {
                        Text("Días que durará el combustible de este tanque si se sigue vendiendo al ritmo promedio diario de los cortes registrados.\n\nSe calcula: nivel actual ÷ litros vendidos por día (promedio).\n\nSirve para anticipar el desabastecimiento y decidir cuándo pedir combustible.")
                            .font(.footnote)
                            .padding()
                            .frame(idealWidth: 280)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
        }
        .padding()
        .background(Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
