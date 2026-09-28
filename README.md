# AppGasolinera

App iOS (SwiftUI) para la gestión de una franquicia de gasolineras (Súper, Regular y Diésel): sucursales, tanques, precios por sucursal y cortes diarios registrados bomba por bomba.

## Roles

- **Gerente General**: dashboard consolidado con filtro por sucursal y por fecha; administra sucursales, usuarios (incluido cambiarles la contraseña) y precios por sucursal.
- **Gerente de Sucursal**: registra los 2 cortes diarios (Matutino y Vespertino) de sus 6 bombas y consulta el estado de sus tanques.

## Módulo de combustible

- Cada sucursal tiene **6 bombas**; cada bomba despacha los 3 combustibles.
- Por bomba y combustible se registran **ventas**, **compras / recepción** y **pérdidas o daños** (merma, fuga, falla técnica, derrame).
- Las bombas se pueden editar hasta pulsar **Guardar corte** (exige las 6). Al guardar, el corte queda bloqueado y se actualizan los tanques: nivel + compras − ventas − pérdidas.
- El Vespertino exige el Matutino guardado. Las cantidades se validan contra el tanque (no se vende más de lo disponible ni se compra más de lo que cabe).
- Alertas de tanque: Crítico (≤ 20 %), Medio (≤ 50 %), Óptimo, con días de autonomía estimados.
- Los dashboards muestran datos parciales de cortes en curso y permiten consultar otros días.

## Cuentas de demostración

Contraseña de todas: `1234`

| Rol | Correo |
|---|---|
| Gerente General | gerente.general@gas76.com |
| Gerente de Sucursal (76 Centro, con cortes de hoy) | centro@gas76.com |
| Gerente de Sucursal (sin cortes de hoy) | norte@ · sur@ · oriente@ · poniente@gas76.com |

No hay recuperación de contraseña desde el login: el Gerente General la cambia desde Editar usuario.

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
├── Models/      Modelos (Branch, Tank, FuelPrice, FuelCut, PumpReading, AppUser...)
├── Theme/       Colores
└── Views/       Auth, GeneralManager, BranchManager, Shared, Root
```

## Notas

Los datos son de demostración y se cargan en memoria desde `AppStore` (se reinician al cerrar la app). Las contraseñas se comparan en texto plano: es solo una demo.

## Diseño (Figma)

Prototipo editable y conectado: https://www.figma.com/design/P4lxHxo4WqEK2xvQu4XRXq

La guía de interacciones de cada pantalla está en [`FIGMA_INTERACCIONES.md`](FIGMA_INTERACCIONES.md).
