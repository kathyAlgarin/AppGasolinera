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

/// Desglose por tipo de combustible: ventas (litros y dinero), compras y pérdidas.
/// Cada fila abre el detalle de ese combustible. `branchID == nil` = todas las sucursales.
struct FuelTotalsSection: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let branchID: UUID?
    let date: Date

    var body: some View {
        let totals = store.totals(branchID: branchID, on: date)
        let revenue = store.revenueByFuel(branchID: branchID, on: date)

        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            VStack(spacing: 8) {
                ForEach(FuelType.allCases) { type in
                    let t = totals[type] ?? FuelTotals()
                    NavigationLink {
                        FuelDetailView(fuelType: type, branchID: branchID, date: date)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(type.rawValue, systemImage: type.symbolName)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.gas76Orange)
                                Text("Ventas \(Int(t.sales)) L · \((revenue[type] ?? 0).formatted(.currency(code: "USD")))")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                                Text("Compras \(Int(t.purchases)) L · Pérdidas \(Int(t.losses)) L")
                                    .font(.footnote)
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
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

extension View {
    /// Restringe un campo a números: solo dígitos y, si `decimal`, un separador decimal.
    /// Filtra también lo que llegue al pegar texto.
    func numericInput(_ text: Binding<String>, decimal: Bool = false) -> some View {
        onChange(of: text.wrappedValue) { _, new in
            var out = ""
            var hasSeparator = false
            for ch in new {
                if ch.isASCII && ch.isNumber {
                    out.append(ch)
                } else if decimal && (ch == "." || ch == ",") && !hasSeparator {
                    hasSeparator = true
                    out.append(".")
                }
            }
            if out != new { text.wrappedValue = out }
        }
    }
}

extension String {
    /// Formato básico de correo: algo@dominio.ext, sin espacios.
    var isValidEmail: Bool {
        range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}

extension Date {
    /// "hoy" o la fecha corta, para los títulos de los dashboards.
    var dayLabel: String {
        Calendar.current.isDateInToday(self) ? "hoy" : formatted(date: .abbreviated, time: .omitted)
    }
}

/// Selector de fecha para consultar otros días, con aviso si los datos son parciales.
struct DayPickerRow: View {
    @Binding var date: Date
    let isPartial: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date)
            if isPartial {
                Label("Corte en curso: datos parciales", systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

extension View {
    /// Permite ocultar el teclado arrastrando el contenido hacia abajo. Tocar fuera de un
    /// campo también lo oculta: ver `installKeyboardDismissTap()` en App76App.swift.
    func dismissKeyboardSupport() -> some View {
        scrollDismissesKeyboard(.interactively)
    }
}
