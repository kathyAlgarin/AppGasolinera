import SwiftUI

/// 40 · Niveles medidos de los tanques (se envían al cerrar el corte).
struct NivelesView: View {
    @ObservedObject var vm: CorteEnCursoViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 4) {
                    Text("Mide cada tanque con varilla o sonda y escribe el nivel en galones.").font(.callout).foregroundColor(.secondary)
                    AyudaBoton(texto: "Los niveles se ingresan manualmente: la app no se conecta a los tanques. Se guardan en este teléfono y se envían al cerrar el corte.")
                }
                ForEach(vm.datos?.tanques ?? []) { t in
                    CampoNumerico(
                        titulo: "\(t.combustible.nombre) (capacidad \(Formateadores.galones(t.capacidadGal)))",
                        texto: Binding(get: { vm.niveles[t.tanqueId] ?? "" }, set: { vm.niveles[t.tanqueId] = $0 }),
                        unidad: "gal",
                        error: vm.errorNiveles[t.tanqueId] ?? vm.errorNivel(t))
                }
                if !vm.nivelesCompletos {
                    Text("Faltan los niveles de: \(vm.tanquesSinNivel.map(\.nombre).joined(separator: ", ")).")
                        .font(.footnote).foregroundColor(.secondary)
                }
                BotonPrimario(titulo: "Guardar niveles", habilitado: vm.nivelesCompletos) {
                    if vm.guardarNiveles() { dismiss() }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.gas76Background)
        .navigationTitle("Niveles de tanque")
        .navigationBarTitleDisplayMode(.inline)
    }
}
