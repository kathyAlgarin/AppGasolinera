# 1. Arquitectura del proyecto: implementación de MVVM

## 1.1 Visión general

Gasolinera 76 es una aplicación iOS escrita en SwiftUI para administrar una gasolinera con varias sucursales. Cada sucursal tiene **3 tanques** (Regular, Súper, Diésel) y **6 bombas**; cada bomba puede despachar cualquiera de los tres combustibles. La app define dos roles: **Gerente General** (administra usuarios, sucursales y precios y ve toda la empresa) y **Gerente de Sucursal** (opera solo su sucursal).

El proyecto sigue el patrón **MVVM (Model – View – ViewModel)** reforzado con una capa de servicios. Las dependencias fluyen en una sola dirección:

```
View  ──►  ViewModel  ──►  Services  ──►  Models
(dibuja)   (estado de      (reglas de      (datos)
            pantalla)       negocio)
```

## 1.2 Capas y responsabilidades

| Capa | Carpeta | Responsabilidad | No debe hacer |
|---|---|---|---|
| **Model** | `Models/` | Estructuras de datos (`struct`/`enum`): `Branch`, `Tank`, `Pump`, `FuelCut`, `PumpReading`, `Reception`, `FuelLoss`, `FuelPrice`, `AppUser`, `FuelType`, `UserRole`. | Contener reglas de negocio. |
| **Services** | `Services/` | Estado compartido y reglas: `AppRepository`, `SessionManager`, `SalesCalculator`. | Conocer la interfaz. |
| **ViewModel** | `ViewModels/` | Estado de cada pantalla (`@Published`), validación de formularios, formato de textos y llamadas a servicios. | Importar elementos de interfaz (única excepción: `Binding`). |
| **View** | `Views/` | Dibujar la interfaz y reenviar las acciones del usuario al ViewModel. | Mencionar `AppRepository` ni `SessionManager`. |

### Servicios

- **`AppRepository`** (singleton `AppRepository.shared`): guarda en memoria usuarios, sucursales, recepciones, pérdidas, cortes, precios e historial de precios, y **hace cumplir las reglas de integridad** (cortes, turno abierto, capacidades, un gerente por sucursal). También genera los datos de demostración y el reporte del día (`dailyReport`).
- **`SessionManager`** (singleton): mantiene el usuario en sesión y expone `login`, `logout` y `changePassword`. Solo usa el repositorio para autenticar.
- **`SalesCalculator`**: enumeración con funciones **puras** (sin estado). Recibe cortes, recepciones, pérdidas y precios y devuelve un `DailyReport`.

## 1.3 ViewModels

Existe un ViewModel por pantalla:

| Pantalla (View) | ViewModel |
|---|---|
| `RootView` | `RootViewModel` |
| `LoginView` | `LoginViewModel` |
| `ForgotPasswordView` | `ForgotPasswordViewModel` |
| `ChangePasswordView` | `ChangePasswordViewModel` |
| `ProfileView` | `ProfileViewModel` |
| `BranchManagerTabView` | `BranchManagerTabViewModel` |
| `BMDashboardView` y `BranchDetailView` | `BranchOverviewViewModel` (compartido) |
| `CutFormView` | `CutFormViewModel` |
| `ReceptionFormView` (recepción y pérdidas) | `ReceptionFormViewModel` |
| `GMDashboardView` | `GMDashboardViewModel` |
| `UserManagementView` / `UserFormView` | `UserManagementViewModel` / `UserFormViewModel` |
| `BranchManagementView` / `BranchFormView` | `BranchManagementViewModel` / `BranchFormViewModel` |
| `PriceManagementView` / `PriceEditView` | `PriceManagementViewModel` / `PriceEditViewModel` |

Todos heredan de la clase base `ViewModel`, que resuelve un problema concreto de SwiftUI: un `ObservableObject` dentro de otro **no propaga** sus cambios. `forwardChanges(from:)` reenvía el `objectWillChange` de un servicio al ViewModel, de modo que la vista se redibuja cuando cambia el repositorio (por ejemplo, tras registrar un corte).

```swift
class ViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    func forwardChanges<O: ObservableObject>(from object: O) {
        object.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
```

Patrón común: el ViewModel recibe el repositorio por parámetro (con `.shared` por defecto, lo que permite inyectar uno falso en pruebas), llama `super.init()` y luego `forwardChanges(from:)`; expone propiedades calculadas que leen del repositorio y métodos de acción.

## 1.4 Vistas

Cada vista crea su ViewModel con `@StateObject` y usa `@State` solo para asuntos puramente visuales (por ejemplo, qué hoja está abierta). Para pantallas con parámetros:

```swift
init(branchID: UUID) {
    _viewModel = StateObject(wrappedValue: CutFormViewModel(branchID: branchID))
}
```

Para cerrar una hoja tras guardar, el ViewModel publica `didSave = true` y la vista reacciona con `.onChange(of: viewModel.didSave) { … dismiss() }`: la vista no decide, solo reacciona al estado.

Componentes reutilizables (`Views/Shared/Components/`): `SummaryCard`, `ActionCard`, `TankLevelRow`, `BranchSummaryRow`, `PumpSalesRowView`, `ReconciliationRowView` y `BranchReportSection`. Esta última contiene el reporte completo de una sucursal y la comparten el panel del Gerente de Sucursal y el detalle de solo lectura del Gerente General.

## 1.5 Punto de entrada y navegación por rol

`App76App` solo muestra `RootView()`; no crea ni inyecta estado global. `RootViewModel` observa al `SessionManager` y expone un `Destination` (`login`, `generalManager`, `branchManager`) que la vista traduce con un `switch`. Al cerrar sesión, el destino vuelve a `login` y la pantalla cambia con una animación.

## 1.6 Verificación de la arquitectura

Ninguna vista menciona `AppRepository`, `SessionManager` ni `AppStore`:

```bash
grep -rn "AppRepository\|SessionManager\|AppStore" App76/Views
```

(sin resultados). Antes de la migración existía un único `AppStore` global que las vistas usaban directamente con `@EnvironmentObject`, mezclando estado, reglas y presentación.

## 1.7 Beneficios

- **Separación de responsabilidades:** cada archivo hace una sola cosa.
- **Testabilidad:** `SalesCalculator` es lógica pura; los ViewModels aceptan un repositorio inyectado.
- **Reutilización:** un mismo `BranchOverviewViewModel` y `BranchReportSection` alimentan dos pantallas.
- **Mantenibilidad:** cambiar una regla de negocio toca un servicio, no varias vistas. Ejemplo real: la regla de "turno abierto" para recepciones se agregó solo en `AppRepository` y el formulario la reflejó sin tocar la lógica de las demás pantallas.

## 1.8 Limitaciones

- Los datos viven **solo en memoria**: se pierden al cerrar la app. Para producción habría que sustituir `AppRepository` por persistencia real (SwiftData/Core Data) o un backend.
- Las contraseñas se guardan en **texto plano** (demo sin backend).
- Se usa `ObservableObject`/`@Published` en lugar de la macro `@Observable`, por coherencia con el código original.
- No hay pruebas unitarias automatizadas en el proyecto; la lógica se verificó con scripts sobre `AppRepository` y `SalesCalculator` y con pruebas manuales en el simulador.
