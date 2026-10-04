import Foundation

await pruebasModelos()
await pruebasValidadores()
await pruebasViewModels()
await pruebasDatosReales()

print("\n\(Marco.total - Marco.fallas) de \(Marco.total) verificaciones correctas")
exit(Marco.fallas == 0 ? 0 : 1)
