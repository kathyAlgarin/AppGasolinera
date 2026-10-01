import Foundation

final class GMDashboardViewModel: ViewModel {
    private let repository: AppRepository

    init(repository: AppRepository = .shared) {
        self.repository = repository
        super.init()
        forwardChanges(from: repository)
    }

    var branches: [Branch] { repository.branches }               // lista completa (con badge "Inactiva")
    private var activeBranches: [Branch] { repository.branches.filter { $0.isActive } }

    /// Reportes de hoy de las sucursales activas que ya tienen ambos cortes.
    private var reports: [DailyReport] {
        activeBranches.compactMap { repository.dailyReport(branchID: $0.id, on: Date()) }
    }

    var activeBranchesCount: Int { activeBranches.count }
    var totalLitersText: String { "\(Int(reports.reduce(0) { $0 + $1.totalLiters })) L" }
    var totalRevenueText: String {
        reports.reduce(0) { $0 + $1.revenue }.formatted(.currency(code: "USD"))
    }

    /// Consolidación de toda la empresa por combustible (suma de las bombas de todas las sucursales).
    func totalLiters(for fuel: FuelType) -> Double {
        reports.reduce(0) { $0 + ($1.litersByFuel[fuel] ?? 0) }
    }
}
