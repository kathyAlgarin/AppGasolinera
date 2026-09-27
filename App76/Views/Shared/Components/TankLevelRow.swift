import SwiftUI

/// Fila que muestra el nivel actual de un tanque respecto a su capacidad.
struct TankLevelRow: View {
    let tank: Tank

    private var percentage: Double {
        guard tank.capacity > 0 else { return 0 }
        return min(tank.currentLevel / tank.capacity, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: tank.fuelType.symbolName)
                    .foregroundColor(.gas76Orange)
                Text(tank.fuelType.rawValue)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(tank.currentLevel)) / \(Int(tank.capacity)) L")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: percentage)
                .tint(.gas76Orange)
        }
        .padding()
        .background(Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
