# 2. Lógica de negocio: cortes diarios, consolidación de las 6 bombas e indicadores de nivel de tanque

## 2.1 Modelo de datos relevante

- **`Branch`**: sucursal con `tanks` (3, uno por combustible) y `pumps` (siempre 6, constante `Branch.pumpsPerBranch`). Las bombas se crean con la sucursal y, al editarla, se **conservan con los mismos `id`** para no perder el historial.
- **`Tank`**: `capacity` y `currentLevel` en litros; `fillRatio = min(currentLevel / capacity, 1)` (0 si la capacidad es 0).
- **`Pump`**: bomba numerada del 1 al 6.
- **`FuelCut`**: corte (`.opening`/`.closing`), fecha, niveles de tanque por combustible y `pumpReadings`.
- **`PumpReading`**: litros **vendidos** por una bomba de un combustible durante el día (se captura en el cierre).
- **`Reception`**: litros recibidos en un tanque (camión cisterna). **`FuelLoss`**: litros perdidos con su razón.

## 2.2 Los dos cortes diarios

| | **Apertura** | **Cierre** |
|---|---|---|
| Qué registra | Niveles de los 3 tanques | Niveles de los 3 tanques **+ litros vendidos por cada bomba y combustible** (6 × 3 = 18 valores) |
| Requisito | Ninguno | Debe existir la apertura del mismo día |
| Efecto | Actualiza el nivel actual de cada tanque | Igual, y habilita el reporte del día |

### Reglas de validación (`AppRepository.addCut`)

| Regla | Error |
|---|---|
| La sucursal debe existir | `branchNotFound` |
| Cada nivel de tanque entre **0 y su capacidad** | `levelOutOfRange` |
| Una apertura por sucursal y día | `openingAlreadyExists` |
| El cierre exige la apertura previa | `closingRequiresOpening` |
| Un cierre por sucursal y día | `closingAlreadyExists` |
| El cierre exige las 18 lecturas de bombas | `incompleteReadings` |
| Los litros vendidos no pueden ser negativos | `negativeLiters` |

Un corte rechazado **no se guarda**. Un corte guardado **no puede editarse ni repetirse**.

### Experiencia de captura (`CutFormViewModel`)
- El formulario ofrece por defecto el corte que falta (apertura y, ya hecha esta, cierre).
- Precarga los niveles actuales de tanque; las ventas por bomba arrancan en 0.
- Muestra la capacidad de cada tanque y avisa en rojo si el valor escrito sale de 0…capacidad. El botón se habilita solo con todos los valores válidos.
- Si el corte seleccionado ya está registrado, el formulario queda de **solo lectura**, muestra lo guardado y el botón dice "Corte ya registrado". Las pestañas muestran ✓ en los cortes hechos.
- El cierre sin apertura queda bloqueado con un aviso.

### ¿Por qué los niveles de tanque siguen siendo editables en el cierre?
El nivel de un tanque es una **medición física** (varilla o sonda) que el gerente captura. Es lo que permite comparar contra las bombas. Si el nivel de cierre se calculara solo, el cuadre siempre daría 0 y dejaría de detectar fugas o errores.

## 2.3 Recepciones y pérdidas (solo con el turno abierto)

Se registran **después de la apertura y antes del cierre** (`AppRepository.shiftError`):

- **Antes de la apertura:** no hay nivel base → error `shiftNotOpen`.
- **Después del cierre:** `shiftClosed`. Una recepción registrada tras medir el nivel de cierre quedaría fuera de la ventana del cuadre y produciría una diferencia falsa. Lo ocurrido fuera del turno se refleja al medir el nivel en la siguiente apertura.

Validaciones adicionales:
- **Recepción:** cantidad > 0 y no mayor que el espacio libre del tanque (`capacidad − nivel actual`). Una cantidad exacta que llena el tanque se acepta.
- **Pérdida:** litros > 0, no mayores que el nivel actual, y con **razón** obligatoria (texto no vacío en el formulario).
- Una recepción **suma** al nivel del tanque; una pérdida lo **descuenta**.

## 2.4 Consolidación de las 6 bombas

La implementa `SalesCalculator.report(...)`, que produce un `DailyReport`:

1. **Ventas por bomba:** los litros registrados en el cierre, por bomba y combustible.
2. **Consolidado por combustible:** suma de las 6 bombas → total de la sucursal.
3. **Ingresos:** `Σ (litros consolidados × precio vigente de esa sucursal)`.
4. **Control por tanques** (sección 2.5).

El Gerente General suma además los reportes de las **sucursales activas** (las inactivas no cuentan), tanto en litros e ingresos como en litros por combustible:

```
6 bombas → total de la sucursal → Σ sucursales activas (Gerente General)
```

El reporte solo existe si hay **apertura y cierre** del día (`dailyReport` devuelve `nil` en caso contrario); entonces la interfaz muestra "Aún no hay corte de apertura y cierre de hoy".

### Resultado con los datos de demostración
Cada sucursal demo vende 1,700 L (Regular 700, Súper 400, Diésel 600); por bomba (Centro): 330, 270, 280, 260, 320 y 240 L. Ingresos de 76 Centro: 700×1.05 + 400×1.25 + 600×0.98 = **$1,823.00**. Panel general (3 sucursales con cortes): **5,100 L** y **$5,469.00**. La sucursal "76 Pruebas" no tiene cortes de hoy y no suma hasta que se registren.

## 2.5 Cuadre con los tanques

Las ventas **oficiales** salen de las bombas. El tanque actúa como control independiente:

```
Bajó el tanque = nivel de apertura + recepciones del periodo − nivel de cierre
Diferencia     = bajó el tanque − litros de las bombas − pérdidas registradas
```

Solo cuentan las recepciones y pérdidas entre la apertura y el cierre.

- **Cuadra** si `|diferencia| ≤ max(1 % de los litros de bombas, 1 L)` (`SalesCalculator.toleranceRatio = 0.01`). El mínimo de 1 L evita falsas alarmas cuando se vendió muy poco.
- **No cuadra** si excede la tolerancia: posible fuga no registrada, merma, bomba descalibrada o error de captura.
- La interfaz **explica el porqué** por combustible: la cuenta del tanque (apertura + recibido − cierre), los litros de las bombas, las pérdidas registradas, la diferencia, la tolerancia y una frase que indica de qué lado está el exceso.

**Ejemplo (Regular):** abre con 5,000 L, recibe 1,000 L, registra una pérdida de 50 L, cierra con 5,350 L y las bombas vendieron 600 L. El tanque bajó 5,000 + 1,000 − 5,350 = 650 L; bombas 600 L + pérdidas 50 L = 650 L → diferencia 0 → **Cuadra**. Sin registrar la pérdida, la diferencia sería 50 L y marcaría **No cuadra**.

## 2.6 Indicadores de nivel de tanque

- `Tank.fillRatio` produce un valor entre 0 y 1; `TankLevelRow` lo muestra como barra junto a `nivel / capacidad L`.
- El nivel actual cambia por tres eventos: un **corte** (lo reemplaza por la lectura física), una **recepción** (suma) y una **pérdida** (resta).
- Las capacidades las define el Gerente General al crear o editar una sucursal. Todos los movimientos se validan contra ellas (sección 2.2 y 2.3).

## 2.7 Otras reglas del dominio

- **Roles:** el Gerente General ve y administra todo; el Gerente de Sucursal solo su sucursal.
- **Un Gerente de Sucursal activo por sucursal** (`canAssignBranchManager`).
- **Precios por sucursal** con historial de cambios; cambiar un precio solo afecta los ingresos de esa sucursal.
- Solo usuarios **activos** pueden iniciar sesión.

## 2.8 Verificación realizada

- Script sobre `AppRepository` y `SalesCalculator`: rechazos de cierre sin apertura, duplicados, cierre sin ventas, recepciones fuera de capacidad, niveles fuera de rango, recepciones y pérdidas fuera de turno; aceptación de valores límite; cuadre completo con recepción y pérdida.
- Simulador de iOS: panel general y de sucursal, cortes bloqueados, formulario de recepción con turno cerrado.

## 2.9 Limitaciones conocidas

- Datos en memoria; sin concurrencia ni auditoría de quién registró cada movimiento.
- Un día operativo equivale al día calendario (un turno que cruce la medianoche no está soportado).
- Una recepción nocturna con el turno cerrado no puede registrarse ese día (se corrige al medir el nivel en la apertura siguiente).
- Los cambios de capacidad de un tanque por debajo de su nivel actual no se validan.
