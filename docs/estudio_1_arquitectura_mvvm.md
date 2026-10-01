# Guía de estudio 1: la arquitectura MVVM de la app (en lenguaje natural)

## La idea en una frase
La app es el cuaderno digital de una gasolinera con varias sucursales. Para que el código no sea un enredo, está dividido en capas, cada una con un trabajo claro. Eso es MVVM.

---

## 1. La analogía del restaurante

| Rol | En el restaurante | En la app |
|---|---|---|
| **Model** | Los ingredientes y la receta | `Branch`, `Tank`, `Pump`, `FuelCut`… (solo datos) |
| **View** | El plato y la mesa: lo que ve el cliente | Las pantallas (`Views/`) |
| **ViewModel** | El mesero: toma tu pedido, lo lleva a cocina y te trae la respuesta lista | Un ViewModel por pantalla |
| **Services** | La cocina y el encargado: guarda lo importante y hace cumplir las reglas | `AppRepository`, `SessionManager`, `SalesCalculator` |

**Regla de oro:** el cliente (la pantalla) nunca entra a la cocina. Si tocas "Guardar corte", la pantalla solo le dice al ViewModel "guarda". El ViewModel prepara los datos y se los pasa al repositorio, y **el repositorio decide si son válidos**.

**¿Qué había antes?** Un solo objeto gigante (`AppStore`) que hacía de todo, y todas las pantallas lo usaban directamente. Era como si el cliente cocinara, sirviera y cobrara.

---

## 2. Las cuatro capas, una por una

### Models (`Models/`)
Solo guardan datos, no toman decisiones.
- `Branch` (sucursal): nombre, dirección, 3 tanques, **6 bombas**, si está activa.
- `Tank`: capacidad, nivel actual y `fillRatio` (qué tan lleno está, de 0 a 1).
- `Pump`: una bomba (Bomba 1…6).
- `FuelCut`: un corte (apertura o cierre) con los niveles de tanque y, en el cierre, los litros vendidos por bomba (`PumpReading`).
- `Reception`, `FuelLoss`, `FuelPrice`, `AppUser`, `FuelType`, `UserRole`.

### Services (`Services/`)
- **`AppRepository`**: la "base de datos" en memoria **y** el que dice "no" cuando algo no tiene sentido (un cierre sin apertura, una recepción que no cabe…). Es un *singleton*: hay uno solo, compartido (`AppRepository.shared`).
- **`SessionManager`**: recuerda quién entró (`currentUser`), hace login, logout y cambio de contraseña.
- **`SalesCalculator`**: una calculadora. No guarda nada: le das cortes, recepciones, pérdidas y precios y te devuelve el reporte del día (`DailyReport`).

### ViewModels (`ViewModels/`)
Uno por pantalla. Guardan lo que la pantalla necesita saber (textos de los campos, si el botón está habilitado, mensajes de error), validan formularios y llaman a los servicios. Todos heredan de `ViewModel`.

### Views (`Views/`)
Solo dibujan. Reciben su ViewModel con `@StateObject` y no saben nada del repositorio.

---

## 3. El truco de `forwardChanges`

En SwiftUI, si el repositorio cambia pero tu ViewModel no se entera, la pantalla no se actualiza. `forwardChanges` es como decirle al mesero: *"avísame cada vez que cambie algo en la cocina"*.

```swift
class ViewModel: ObservableObject {
    func forwardChanges<O: ObservableObject>(from object: O) { … }
}
```

Sin eso, registrarías un corte y la pantalla seguiría mostrando datos viejos. Por eso todos los ViewModels hacen esto al crearse:

```swift
super.init()                       // siempre ANTES de usar self
forwardChanges(from: repository)
```

---

## 4. Qué pasa cuando tocas "Guardar corte" (paso a paso)

1. En `CutFormView` tocas **Guardar corte** → la vista llama `viewModel.save()`.
2. `CutFormViewModel` arma los niveles y las ventas y llama `repository.addCut(...)`.
3. `AppRepository` valida las reglas. Si algo falla, lanza un error; el ViewModel lo convierte en `errorMessage` y la vista lo muestra en rojo.
4. Si es válido: guarda el corte y actualiza los niveles de los tanques.
5. El repositorio avisa que cambió → los ViewModels reenvían el aviso → el panel se **redibuja**.
6. El ViewModel pone `didSave = true` y la vista cierra el formulario (`.onChange(of: viewModel.didSave) { dismiss() }`).

## 5. Cómo se decide qué pantalla ver
`App76App` solo muestra `RootView`. `RootViewModel` mira a `SessionManager`: sin sesión → login; Gerente General → sus 5 pestañas; Gerente de Sucursal → sus 2 pestañas. Al cerrar sesión, vuelve al login solo.

## 6. Dos pantallas, un mismo ViewModel
`BMDashboardView` (gerente de sucursal) y `BranchDetailView` (gerente general viendo una sucursal) usan el **mismo** `BranchOverviewViewModel` y el mismo componente `BranchReportSection`. Así no se duplica código.

## 7. ¿Cómo sé que quedó bien MVVM?
Buscar en `Views/` las palabras `AppRepository` o `SessionManager`: no debe aparecer ninguna.

```bash
grep -rn "AppRepository\|SessionManager\|AppStore" App76/Views
```

## 8. Por qué sirve (con un ejemplo real)
Cuando se agregó la regla *"recepciones solo con el turno abierto"*, se escribió **una vez** en `AppRepository.shiftError`. El formulario de recepción solo preguntó "¿hay error de turno?" y mostró el aviso. No hubo que tocar otras pantallas.

## 9. Preguntas típicas y cómo responderlas
- **¿Por qué un ViewModel por pantalla?** Para que cada pantalla tenga su propio estado y validación sin mezclarse.
- **¿Por qué hay un repositorio compartido?** Porque los datos son los mismos para todas las pantallas; así un cambio en una se ve en las demás.
- **¿Por qué `SalesCalculator` es aparte?** Porque es matemática pura: se puede probar sin pantallas ni estado.
- **¿Qué falta?** Persistencia real (hoy todo vive en memoria), contraseñas con hash y pruebas unitarias automáticas.
