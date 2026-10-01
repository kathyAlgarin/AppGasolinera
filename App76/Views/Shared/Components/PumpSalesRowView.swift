import SwiftUI

/// Fila con lo vendido por una bomba, desglosado por combustible.
struct PumpSalesRowView: View {
    let row: PumpSalesRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "fuelpump.fill")
                    .foregroundColor(.gas76Orange)
                Text(row.name)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(row.total)) L")
                    .font(.subheadline.bold())
                    .foregroundColor(.gas76Blue)
            }
            HStack {
                ForEach(FuelType.allCases) { fuel in
                    Text("\(fuel.rawValue): \(Int(row.litersByFuel[fuel] ?? 0)) L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if fuel != FuelType.allCases.last { Spacer() }
                }
            }
        }
        .padding()
        .background(Color.gas76Card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
