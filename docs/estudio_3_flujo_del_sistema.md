# Guía de estudio 3: cómo fluye el sistema, qué puede y qué no puede hacer, validaciones y archivos

> Los nombres de archivo son relativos a `App76/`. Prototipo en Figma: https://www.figma.com/design/SGdG1LLtg0lxJWlw5ECwhv

---

## 1. Visión general del flujo

```
Abrir la app → LoginView
   ├─ Gerente General  → 5 pestañas: Panel · Usuarios · Sucursales · Precios · Perfil
   └─ Gerente de Sucursal → 2 pestañas: Panel · Perfil
Cerrar sesión (Perfil) → vuelve al login
```

Quién decide la pantalla: `Views/Root/RootView.swift` + `ViewModels/RootViewModel.swift` (mira a `Services/SessionManager.swift`).

### Un día típico de un Gerente de Sucursal
1. **Apertura:** registra los niveles de los 3 tanques.
2. **Durante el día (turno abierto):** registra **recepciones** (camión cisterna) y **pérdidas** (con razón).
3. **Cierre:** registra los niveles de los 3 tanques y los **litros vendidos por cada bomba** (18 valores).
4. El panel muestra ventas, ingresos, ventas por bomba, consolidado, y el **cuadre** con explicación.
5. Con ambos cortes hechos, el corte queda bloqueado y el turno cerrado hasta mañana.

### Estados del panel del Gerente de Sucursal
| Estado | Tarjeta "Registrar corte" | Tarjeta "Recepción y pérdidas" |
|---|---|---|
| Sin apertura | "Falta la apertura" | "Disponible tras la apertura" |
| Apertura hecha | "Apertura ✓ · Falta el cierre" | "Camión cisterna o litros perdidos" |
| Ambos cortes | "Apertura ✓ · Cierre ✓" (verde) | "Turno cerrado" |

---

## 2. Lo que SÍ puede hacer cada rol

### Gerente General
- Ver el **panel consolidado**: litros e ingresos de hoy (solo sucursales activas con ambos cortes), litros por combustible y número de sucursales activas.
- Abrir el **detalle de solo lectura** de cualquier sucursal (tanques, ventas por bomba, consolidado, cuadre, pérdidas).
- **Usuarios:** crear y editar (nombre, correo, contraseña, rol, sucursal, activo/inactivo).
- **Sucursales:** crear y editar (nombre, dirección, capacidad de tanques, activa/inactiva).
- **Precios:** cambiar el precio por litro de cada combustible **por sucursal**, con historial de cambios.
- Cambiar su contraseña y cerrar sesión.

### Gerente de Sucursal
- Ver el panel **solo de su sucursal**.
- Registrar la **apertura** y el **cierre** del día.
- Registrar **recepciones** y **pérdidas** con el turno abierto.
- Consultar un corte ya registrado (solo lectura).
- Cambiar su contraseña y cerrar sesión.

## 3. Lo que NO puede hacer (por diseño o por límite actual)

**Por diseño**
- El Gerente de Sucursal **no ve otras sucursales** ni administra usuarios, sucursales o precios.
- El Gerente General **no registra cortes, recepciones ni pérdidas** (solo consulta).
- **No se edita** un corte ya guardado ni se registra un segundo corte del mismo tipo el mismo día.
- No se registran recepciones/pérdidas antes de la apertura ni después del cierre.
- Las sucursales tienen **siempre 6 bombas** (no se agregan ni se quitan).
- Un usuario **inactivo** no puede iniciar sesión.
- Solo puede haber **un Gerente de Sucursal activo por sucursal**.

**Límites actuales (no implementado)**
- **Persistencia:** todo vive en memoria; al cerrar la app se pierde y vuelven los datos demo.
- No se **eliminan** usuarios ni sucursales (solo se desactivan); no se editan ni eliminan recepciones, pérdidas o cortes.
- No hay historial por fechas: los paneles muestran **solo el día de hoy**.
- "Olvidé mi contraseña" es informativo (no envía nada).
- Contraseñas en texto plano; sin recuperación real ni bloqueo por intentos.
- No se valida que el correo tenga formato válido ni que sea único.
- Desactivar una sucursal no bloquea a su gerente (solo la excluye de los totales del panel general).
- Si el Gerente General edita su propio usuario, el Perfil no se actualiza hasta volver a iniciar sesión (cambiar contraseña desde el Perfil sí lo actualiza).
- El Gerente General puede bajar la capacidad de un tanque por debajo de su nivel actual (no se valida).

---

## 4. Validaciones, una por una

### Inicio de sesión
| Regla | Dónde | Resultado |
|---|---|---|
| Correo sin distinguir mayúsculas y **sin espacios al inicio/fin** | `AppRepository.authenticate` | Entra o no |
| Contraseña exacta | `AppRepository.authenticate` | — |
| Usuario **activo** | `AppRepository.authenticate` | — |
| Mensaje de error | `Views/Auth/LoginView.swift` | "Correo o contraseña incorrectos." |

### Cambiar contraseña
| Regla | Dónde | Mensaje |
|---|---|---|
| Nueva no vacía y igual a la confirmación | `ChangePasswordViewModel.save` | "Las contraseñas nuevas no coinciden." |
| La actual debe ser correcta | `SessionManager.changePassword` | "La contraseña actual no es correcta." |

### Usuarios (Gerente General)
| Regla | Dónde | Mensaje |
|---|---|---|
| Nombre, correo y contraseña no vacíos; si el rol es Gerente de Sucursal, debe elegir sucursal | `UserFormViewModel.isValid` | Botón deshabilitado |
| Un gerente activo por sucursal | `AppRepository.canAssignBranchManager` (`addUser`/`updateUser`) | "Esa sucursal ya tiene un gerente asignado. Desactívalo primero o elige otra sucursal." |

### Sucursales (Gerente General)
| Regla | Dónde |
|---|---|
| Nombre y dirección no vacíos | `BranchFormViewModel.canSave` |
| Capacidad vacía se toma como 0 | `BranchFormViewModel.save` |
| Al editar se **conservan** las mismas bombas (mismos id) y los niveles actuales | `BranchFormViewModel.save` |
| Al crear: 6 bombas nuevas y tanques con nivel 0 | `Branch.makePumps()` |

### Precios (Gerente General)
| Regla | Dónde |
|---|---|
| Debe ser un número | `PriceEditViewModel.canSave` |
| Cada cambio queda en el historial (anterior → nuevo, fecha) | `AppRepository.updatePrice` |

### Cortes (Gerente de Sucursal)
| Regla | Dónde | Error |
|---|---|---|
| Sucursal existente | `AppRepository.addCut` | `branchNotFound` |
| Niveles entre 0 y capacidad | `addCut` + aviso en vivo `CutFormViewModel.levelWarning` | "El nivel de X debe estar entre 0 y N L (capacidad del tanque)." |
| Una apertura por día | `addCut` | "Ya existe un corte de apertura registrado hoy…" |
| Cierre requiere apertura | `addCut` | "Debes registrar el corte de apertura antes del corte de cierre." |
| Un cierre por día | `addCut` | "Ya existe un corte de cierre registrado hoy…" |
| 18 ventas completas en el cierre | `addCut` | "Faltan los litros vendidos de alguna bomba." |
| Ventas ≥ 0 | `addCut` | "Los litros no pueden ser negativos." |
| Corte ya guardado → solo lectura | `CutFormViewModel.isLocked` | Botón "Corte ya registrado" |
| Botón habilitado solo con valores válidos | `CutFormViewModel.canSave` | — |

### Recepciones y pérdidas (Gerente de Sucursal)
| Regla | Dónde | Mensaje |
|---|---|---|
| Solo con el turno abierto | `AppRepository.shiftError` | "Primero registra el corte de apertura…" / "El corte de cierre de hoy ya está registrado…" |
| Cantidad > 0 | `addReception` / `addLoss` | "La cantidad debe ser mayor que 0." |
| Recepción ≤ espacio libre | `addReception` | "La recepción excede la capacidad del tanque de X: solo caben N L más." |
| Pérdida ≤ nivel actual | `addLoss` | "La pérdida no puede ser mayor que el nivel actual del tanque de X (N L)." |
| Pérdida con razón no vacía | `ReceptionFormViewModel.canSave` | Botón deshabilitado |
| Aviso en vivo y pista de capacidad | `ReceptionFormViewModel.quantityWarning` / `limitHint` | Texto en rojo / gris |

### Cuadre
| Regla | Dónde |
|---|---|
| `diferencia = tanque − bombas − pérdidas` | `DailyReport.difference(for:)` |
| Tolerancia `max(1 % de bombas, 1 L)` | `DailyReport.tolerance(for:)`, `SalesCalculator.toleranceRatio` |

---

## 5. Archivos involucrados por función

### Arranque y sesión
| Función | Archivos |
|---|---|
| Punto de entrada | `App76App.swift` |
| Decidir pantalla según rol | `Views/Root/RootView.swift`, `ViewModels/RootViewModel.swift` |
| Login / logout / cambiar contraseña | `Views/Auth/LoginView.swift`, `ChangePasswordView.swift`, `ForgotPasswordView.swift`; `ViewModels/Auth/*`; `Services/SessionManager.swift`; `Services/AppRepository.swift` (`authenticate`) |
| Perfil | `Views/Shared/ProfileView.swift`, `ViewModels/Shared/ProfileViewModel.swift` |

### Gerente de Sucursal
| Función | Archivos |
|---|---|
| Pestañas y panel | `Views/BranchManager/BranchManagerTabView.swift`, `BMDashboardView.swift`; `ViewModels/BranchManager/BranchManagerTabViewModel.swift`, `BranchOverviewViewModel.swift` |
| Tarjetas de acción | `Views/Shared/Components/ActionCard.swift` |
| Registrar corte (apertura/cierre) | `Views/BranchManager/CutFormView.swift`; `ViewModels/BranchManager/CutFormViewModel.swift`; `AppRepository.addCut`, `cuts(for:on:)` |
| Recepción y pérdidas | `Views/BranchManager/ReceptionFormView.swift`; `ViewModels/BranchManager/ReceptionFormViewModel.swift`; `AppRepository.addReception`, `addLoss`, `shiftError`, `tank(branchID:fuelType:)` |
| Reporte del día (ventas, bombas, consolidado, cuadre, pérdidas) | `Views/Shared/Components/BranchReportSection.swift`, `PumpSalesRowView.swift`, `ReconciliationRowView.swift`, `SummaryCard.swift`, `TankLevelRow.swift`; `ViewModels/BranchManager/BranchOverviewViewModel.swift`; `Services/SalesCalculator.swift`; `AppRepository.dailyReport` |

### Gerente General
| Función | Archivos |
|---|---|
| Pestañas | `Views/GeneralManager/GeneralManagerTabView.swift` |
| Panel consolidado | `Views/GeneralManager/GMDashboardView.swift`; `ViewModels/GeneralManager/GMDashboardViewModel.swift`; `Views/Shared/Components/BranchSummaryRow.swift` |
| Detalle de sucursal (solo lectura) | `Views/GeneralManager/BranchDetailView.swift`; `BranchOverviewViewModel` + `BranchReportSection` |
| Usuarios | `UserManagementView.swift`, `UserFormView.swift`; `UserManagementViewModel.swift`, `UserFormViewModel.swift`; `AppRepository.addUser`, `updateUser`, `canAssignBranchManager` |
| Sucursales | `BranchManagementView.swift`, `BranchFormView.swift`; `BranchManagementViewModel.swift`, `BranchFormViewModel.swift`; `AppRepository.saveBranch`; `Models/Branch.swift` |
| Precios | `PriceManagementView.swift`, `PriceEditView.swift`; `PriceManagementViewModel.swift`, `PriceEditViewModel.swift`; `AppRepository.updatePrice`, `currentPrice`, `history` |

### Modelos y servicios (transversales)
| Elemento | Archivo |
|---|---|
| Sucursal, tanques, bombas | `Models/Branch.swift`, `Tank.swift`, `Pump.swift` |
| Cortes y ventas por bomba | `Models/FuelCut.swift` (`FuelCut`, `PumpReading`) |
| Recepciones, pérdidas, precios | `Models/Reception.swift`, `FuelLoss.swift`, `FuelPrice.swift` |
| Usuarios y roles | `Models/AppUser.swift`, `UserRole.swift`, `FuelType.swift` |
| Estado y reglas | `Services/AppRepository.swift` |
| Cálculos del día | `Services/SalesCalculator.swift` (`DailyReport`, `SalesCalculator`) |
| Colores | `Theme/Colors.swift` |
| Clase base de ViewModels | `ViewModels/ViewModel.swift` |

---

## 6. Datos de demostración

| Usuario | Contraseña | Rol / sucursal |
|---|---|---|
| `gerente.general@gas76.com` | `1234` | Gerente General |
| `centro@gas76.com` | `1234` | 76 Centro (cortes de hoy ya registrados) |
| `norte@gas76.com` | `1234` | 76 Norte (cortes de hoy ya registrados) |
| `sur@gas76.com` | `1234` | 76 Sur (cortes de hoy ya registrados) |
| `prueba@gas76.com` | `1234` | 76 Pruebas (**sin cortes**, para probar el flujo desde cero) |

Cada sucursal con historial vende 1,700 L (Regular 700, Súper 400, Diésel 600). Precios: Regular $1.05, Súper $1.25, Diésel $0.98.

## 7. Cómo probar el flujo completo (usuario `prueba@gas76.com`)
1. Panel → "Registrar corte" → **Apertura** (deja los niveles precargados) → Guardar.
2. "Recepción y pérdidas" → Recepción de 1000 L Regular → registrar. Luego pestaña **Pérdida**: 50 L, razón "Fuga en manguera".
3. "Registrar corte" → **Cierre**: ventas de cada bomba 100 Regular + 50 Súper + 0 Diésel (600 / 300 / 0 L en total) y niveles medidos Regular **5,350**, Súper **2,700**, Diésel **4,000** (el formulario viene precargado con los niveles actuales; hay que corregirlos con lo "medido").
4. Revisa el panel: ventas, ingresos, consolidado y cuadre.
5. Experimento: reinicia la app (los datos vuelven a los de demostración), repite todo con un nivel de cierre distinto (por ejemplo Regular 5,950) y verás "No cuadra" con la explicación de la diferencia.
6. Intenta romper reglas: nivel mayor a la capacidad, recepción que no cabe, otro cierre, recepción tras el cierre.
