import SwiftUI

/// Muestra los cuatro estados de una pantalla: cargando, error (con reintentar), vacío y contenido.
struct CargaView<Valor, Contenido: View>: View {
    let estado: Carga<Valor>
    var textoVacio = "Sin datos para mostrar."
    var iconoVacio = "tray"
    var esVacio: (Valor) -> Bool = { _ in false }
    let reintentar: () -> Void
    @ViewBuilder let contenido: (Valor) -> Contenido

    var body: some View {
        switch estado {
        case .inicial, .cargando:
            ProgressView("Cargando…")
                .frame(maxWidth: .infinity, minHeight: 160)
        case .error(let mensaje):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle").font(.title).foregroundColor(.gas76Rojo)
                Text(mensaje).multilineTextAlignment(.center).foregroundColor(.gas76Rojo)
                Button("Reintentar", action: reintentar)
                    .buttonStyle(.borderedProminent).tint(.gas76Orange)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 160)
        case .listo(let valor):
            if esVacio(valor) {
                VStack(spacing: 8) {
                    Image(systemName: iconoVacio).font(.title).foregroundColor(.secondary)
                    Text(textoVacio).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                contenido(valor)
            }
        }
    }
}

struct MensajeError: View {
    let texto: String?
    var body: some View {
        if let texto, !texto.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(texto)
            }
            .font(.callout)
            .foregroundColor(.gas76Rojo)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MensajeAviso: View {
    let texto: String?
    var body: some View {
        if let texto, !texto.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle.fill")
                Text(texto)
            }
            .font(.callout)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(.gas76Blue)
            .background(Color.gas76Blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct BotonPrimario: View {
    let titulo: String
    var cargando = false
    var habilitado = true
    var tint: Color = .gas76Orange
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack {
                if cargando { ProgressView().tint(.white) }
                Text(titulo).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(habilitado && !cargando ? tint : Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!habilitado || cargando)
    }
}

/// Etiqueta de estado. Si tiene explicación (ver `ExplicacionesInsignias`), al tocarla se abre un globo que dice a qué se refiere.
struct Insignia: View {
    let texto: String
    var color: Color = .gas76Orange
    var conAyuda = true
    @State private var abierta = false

    private var explicacion: String? { conAyuda ? ExplicacionesInsignias.para(texto) : nil }

    private var etiqueta: some View {
        Text(texto)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundColor(color)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    var body: some View {
        if let explicacion {
            Button { abierta = true } label: { etiqueta }
                .buttonStyle(.plain)
                .accessibilityHint("Toca para ver qué significa")
                .popover(isPresented: $abierta) {
                    Text(explicacion)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 280, alignment: .leading)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
        } else {
            etiqueta
        }
    }
}

/// Qué significa cada etiqueta (se muestra al tocarla).
enum ExplicacionesInsignias {
    static func para(_ texto: String) -> String? {
        if texto.hasPrefix("Diferencia") {
            return "El nivel medido en el tanque difiere del teórico por más del 0.5 % de los galones despachados. Es solo un indicador: no impide cerrar el corte."
        }
        switch texto {
        case "Forzado":
            return "Cierre forzado: el cajero dejó su caja abierta y el Gerente de Sucursal la cerró por él. El Gerente contó el efectivo y dejó un motivo, por eso queda marcada."
        case "Ajustado", "Ajustada":
            return "El Gerente General corrigió una lectura de este corte después de cerrarlo. La lectura original se conserva y el ajuste queda registrado con su motivo."
        case "Cambio de medidor":
            return "Durante este corte se reemplazó el contador (totalizador) de una manguera. Sus galones se calculan sumando lo que marcó el medidor viejo y lo que marcó el nuevo."
        case "Contaminación":
            return "Combustible perdido por contaminación: una descarga en el tanque equivocado, agua u otro problema. La genera «Descarga errónea y vaciado» y no se puede editar."
        case "Anulada":
            return "Venta anulada por el Gerente de Sucursal mientras su caja seguía abierta. Se conserva marcada, se devolvió el stock y no cuenta en el efectivo esperado."
        case "Stock bajo":
            return "El stock llegó al mínimo configurado para este producto (o se agotó)."
        case "Crítico":
            return "Nivel del 20 % o menos, o autonomía menor a 2 días. Conviene pedir combustible pronto."
        case "Medio":
            return "Nivel del 50 % o menos, o autonomía menor a 5 días."
        case "Óptimo":
            return "Nivel mayor al 50 % y autonomía de 5 días o más."
        case "Cuadra":
            return "El nivel medido en el tanque coincide con el teórico dentro de la tolerancia del 0.5 % de los galones despachados."
        case "Inactiva", "Inactivo":
            return "Se desactiva en lugar de borrarse: conserva su historial, pero ya no se usa."
        case "Primer corte":
            return "Es el primer corte de la sucursal: pide las lecturas iniciales y finales de las 18 mangueras y si es Matutino o Vespertino."
        case "Con tienda":
            return "Esta sucursal tiene tienda y cajeros: hace cierre de caja y su corte no se cierra con cajas abiertas."
        case "Abierta":
            return "Caja abierta: todavía no se ha cerrado."
        default:
            return nil
        }
    }
}

/// Fila «etiqueta ........ valor».
struct FilaDato: View {
    let titulo: String
    let valor: String
    var destacado = false
    var color: Color?
    var body: some View {
        HStack {
            Text(titulo).foregroundColor(.secondary)
            Spacer()
            Text(valor)
                .fontWeight(destacado ? .semibold : .regular)
                .foregroundColor(color ?? .primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

/// Envoltura de las hojas de formulario: título y botón X.
struct HojaFormulario<Contenido: View>: View {
    let titulo: String
    let cerrar: () -> Void
    @ViewBuilder let contenido: () -> Contenido

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { contenido() }
                    .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.gas76Background)
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: cerrar) { Image(systemName: "xmark") }
                        .accessibilityLabel("Cerrar")
                }
            }
        }
    }
}
