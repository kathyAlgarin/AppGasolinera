# AppGasolinera

App iOS (SwiftUI) para la gestión de una cadena de gasolineras: sucursales, tanques, precios de combustible, recepciones y cortes.

## Roles

- **Gerente General**: administra sucursales, usuarios y precios; ve el dashboard consolidado.
- **Gerente de Sucursal**: registra recepciones de combustible y cortes, y consulta el estado de sus tanques.

## Requisitos

- Xcode 15 o superior
- iOS 17.2+
- Swift 5

## Ejecución

1. Clona el repositorio.
2. Abre `App76.xcodeproj` en Xcode.
3. Selecciona un simulador y presiona **Run** (⌘R).

## Estructura

```
App76/
├── Data/        Almacén de datos (AppStore)
├── Models/      Modelos (Branch, Tank, FuelPrice, Reception, FuelCut, AppUser...)
├── Theme/       Colores
└── Views/       Auth, GeneralManager, BranchManager, Shared, Root
```

## Notas

Los datos son de demostración y se cargan en memoria desde `AppStore`.
