import Foundation

/// 44 · Historial de cortes cerrados, con indicadores «Ajustado», «Cambio de medidor» y «Diferencia».
@MainActor
final class HistorialCortesViewModel: ObservableObject {
    struct Item: Identifiable, Equatable {
        let corte: Corte
        let ajustado: Bool
        let cambioMedidor: Bool
        let hayDiferencia: Bool
        var id: UUID { corte.id }
    }

    @Published private(set) var estado: Carga<[Item]> = .inicial

    private let sucursalId: UUID?
    private let servicio: ReportesService
    private let limite: Int

    init(sucursalId: UUID?, servicio: ReportesService, limite: Int = 60) {
        self.sucursalId = sucursalId
        self.servicio = servicio
        self.limite = limite
    }

    func cargar() async {
        if estado.valor == nil { estado = .cargando }
        do {
            let cortes = try await servicio.historial(sucursalId: sucursalId, limite: limite)
            let resumenes = try await servicio.resumenes(corteIds: cortes.map(\.id))
            let porCorte = Dictionary(grouping: resumenes, by: \.corteId)
            estado = .listo(cortes.map { c in
                let r = porCorte[c.id] ?? []
                return Item(corte: c, ajustado: r.contains { $0.hayAjuste }, cambioMedidor: r.contains { $0.hayCambioMedidor },
                            hayDiferencia: r.contains { $0.hayDiferencia })
            })
        } catch {
            estado.registrarFallo(error)
        }
    }
}
