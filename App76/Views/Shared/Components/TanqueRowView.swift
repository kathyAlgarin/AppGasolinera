import SwiftUI

/// Fila de tanque: nivel estimado, porcentaje, estado, autonomía y la leyenda de lo que incluye el corte en curso.
struct TanqueRowView: View {
    let tanque: EstadoTanque
    var mostrarIncluye = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(tanque.combustible.nombre, systemImage: "fuelpump.fill")
                    .font(.headline).foregroundColor(tanque.combustible.color)
                Spacer()
                Insignia(texto: tanque.estado.nombre, color: tanque.estado.color)
            }
            ProgressView(value: min(max(NSDecimalNumber(decimal: tanque.porcentaje).doubleValue, 0), 100), total: 100)
                .tint(tanque.estado.color)
            HStack {
                Text("\(Formateadores.galones(tanque.nivelEstimadoGal)) de \(Formateadores.galones(tanque.capacidadGal))")
                    .font(.subheadline)
                Spacer()
                Text(Formateadores.porcentaje(tanque.porcentaje)).font(.subheadline.bold())
            }
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.caption)
                if let dias = tanque.autonomiaDias, tanque.autonomiaDisponible {
                    Text("Autonomía: \(Formateadores.dias(dias))")
                } else {
                    Text("Autonomía aún no disponible")
                }
                AyudaBoton(texto: "La autonomía son los días que dura el nivel estimado al ritmo de venta de los últimos 7 días con cortes cerrados. En una sucursal con menos historial, el estado usa solo el porcentaje: Crítico hasta 20 %, Medio hasta 50 %. Por autonomía: Crítico menos de 2 días, Medio menos de 5.")
            }
            .font(.caption).foregroundColor(.secondary)

            if let base = tanque.baseEn {
                Text("Estimado al corte del \(Fechas.fechaHora(base))").font(.caption).foregroundColor(.secondary)
            } else {
                Text("Estimado desde el nivel inicial de la sucursal").font(.caption).foregroundColor(.secondary)
            }
            if mostrarIncluye {
                HStack(spacing: 4) {
                    Text("Incluye \(tanque.nCompras) \(tanque.nCompras == 1 ? "compra" : "compras") y \(tanque.nPerdidas) \(tanque.nPerdidas == 1 ? "pérdida" : "pérdidas") del corte en curso")
                    AyudaBoton(texto: "El nivel no es en vivo: la app solo sabe cuánto se vendió cuando se cierra un corte. Las compras y pérdidas que registras en el corte en curso sí lo afectan al instante.")
                }
                .font(.caption).foregroundColor(.secondary)
            }
        }
        .tarjeta()
        .accessibilityElement(children: .combine)
    }
}

/// Texto estándar para cifras de dashboard que salen en cero porque no hay cortes cerrados.
struct SinCortesCerradosView: View {
    var texto = "Sin cortes cerrados hoy"
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
            Text(texto)
            AyudaBoton(texto: "Las ventas de combustible solo se conocen al cerrar un corte. Las cifras en cero no son ventas en cero reales: todavía no hay cortes cerrados en este periodo.")
        }
        .font(.caption).foregroundColor(.secondary)
    }
}
