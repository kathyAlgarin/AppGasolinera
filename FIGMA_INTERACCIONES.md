# Gasolinera 76 — Guía de interacciones para el prototipo en Figma

**Archivo de Figma (editable y con prototipo conectado):**
https://www.figma.com/design/P4lxHxo4WqEK2xvQu4XRXq

- Cada pantalla mide **402 × 874** (iPhone 17 Pro): el contenido hace *scroll* dentro del
  marco y la barra de pestañas queda **fija** abajo, como en la app.
- Página **Pantallas**, en cuatro secciones:
  - **Autenticación**: `01` Login y sus estados `01e` (error), `01g` (cuenta del Gerente
    General) y `01s` (cuenta de Gerente de Sucursal).
  - **Gerente General**: `10`–`23`, más el panel filtrado por cada sucursal
    (`10 Panel General · 76 Centro` … `· 76 Poniente`) y el panel de otro día (`10 Panel General · 25 Sep`).
  - **Gerente de Sucursal**: `30`–`40`, la `35b` y el flujo Vespertino (`31v`, `36v`, `32v`).
  - **Flotantes**: menús, calendario, popover de ayuda, alerta y cuentas (ver sección 7).
- Página **Componentes**: botón primario, tarjeta de métrica, fila de tanque
  (Crítico/Medio/Óptimo), fila de combustible, fila de lista e **Interruptor interactivo**.
- Colección de variables **Prototipo**: rol elegido, sucursal elegida, motivo de pérdida y
  sucursal de precios. Los selectores cambian estas variables y la pantalla se actualiza sola.
- Puntos de inicio: **Inicio de sesión** (`01`), **Gerente General** (`10`) y **Gerente de
  Sucursal** (`30`).

Cada pantalla tiene su captura completa (con todo el scroll en una sola imagen) en la
carpeta [`Capturas/`](Capturas/). Este documento describe, pantalla por pantalla, qué hace
cada botón o elemento interactivo para armar el prototipo (Prototype → *On tap* →
acción).

**Vocabulario de acciones (Figma):**
- **Navigate to** → pantalla nueva empujada (con flecha "‹ atrás" en la barra superior).
- **Open overlay (sheet)** → hoja que sube desde abajo; se cierra con la **X** o arrastrando hacia abajo.
- **Back** → volver a la pantalla anterior.
- **Change to (variant)** → cambia el estado de un componente (p. ej. segmentado, badge).
- **Scroll** → toda pantalla larga hace *scroll vertical* (marcar el frame como *Vertical scrolling*).

**Datos de demostración** (contraseña de todas las cuentas: `1234`):

| Rol | Correo | Sucursal |
|---|---|---|
| Gerente General | gerente.general@gas76.com | Todas |
| Gerente de Sucursal | centro@gas76.com | 76 Centro (con cortes de hoy) |
| Gerente de Sucursal | norte@gas76.com | 76 Norte |
| Gerente de Sucursal | sur@gas76.com | 76 Sur |
| Gerente de Sucursal | oriente@gas76.com | 76 Oriente |
| Gerente de Sucursal | poniente@gas76.com | 76 Poniente |

**Nota sobre las capturas:** muestran el contenido completo de cada pantalla sin la barra de
pestañas inferior (tab bar). La tab bar se documenta en la sección de navegación.
Las capturas 30–40 fueron tomadas con la cuenta `poniente@gas76.com`.
La pantalla **35b** existe solo en el archivo de Figma (no tiene captura de la app).

**Componentes reutilizables sugeridos (Figma components):** `SummaryCard` (tarjeta de
métrica), `TankLevelRow` (fila de tanque con badge de estado + barra + autonomía),
`FuelTotalsRow` (fila de combustible con flecha), `DayPickerRow` (selector de fecha + aviso
"parcial"), `BranchSummaryRow`, `PumpRow` (bomba con check), `ListRow` estándar iOS, botón
primario naranja, botón X de cierre de hoja.

---

## 0. Navegación general

| Elemento | Interacción |
|---|---|
| Login → sesión iniciada | Correo + contraseña correctos → **Navigate to** Panel del rol correspondiente (GG → Panel General; GS → Panel de sucursal). Reemplaza la pantalla (sin volver al login). |
| Tab bar del Gerente General | 5 pestañas: **Panel**, **Usuarios**, **Sucursales**, **Precios**, **Perfil**. Tocar una pestaña cambia de sección (cada una conserva su propio stack de navegación). |
| Tab bar del Gerente de Sucursal | 2 pestañas: **Panel**, **Perfil**. |
| Cerrar sesión | Perfil → *Cerrar sesión* → vuelve al Login. |
| Teclado | Tocar fuera de un campo, o arrastrar el contenido hacia abajo, oculta el teclado. |
| Hojas (sheets) | Todas llevan botón **X** arriba a la izquierda. |

---

## 1. Autenticación

### 01 — Login (`Capturas/01_login.png`)
| Elemento | Acción |
|---|---|
| Campo **Correo electrónico** | Teclado de correo, sin autocapitalizar ni autocorrección. En Figma: **Open overlay** → *Cuentas de demostración*. |
| Campo **Contraseña** | Texto oculto. En Figma: mismo overlay de cuentas. |
| Botón **Ingresar** (naranja) | Credenciales válidas → **Navigate to** Panel según rol. Inválidas → aparece el texto rojo "Correo o contraseña incorrectos." sobre el botón. En Figma: con campos vacíos → `01e`; con la cuenta del Gerente General (`01g`) → `10`; con la de Gerente de Sucursal (`01s`) → `30`. |
| Recuperación de contraseña | **No existe.** Si alguien la olvida, el Gerente General se la cambia desde Editar usuario (16). |

---

## 2. Gerente General

### 10 — Panel General (`Capturas/10_gg_panel_general.png`)
| Elemento | Acción |
|---|---|
| Selector **Todas las sucursales ⌃⌄** (menú) | Abre un menú con: *Todas las sucursales* + cada sucursal. Al elegir, **Change to** variante del panel: todas las tarjetas y el consolidado se recalculan solo para esa sucursal (y "Tanques en estado crítico" cuenta solo sus tanques). |
| **Fecha** (DatePicker compacto) | Abre el calendario emergente (no permite fechas futuras). Al elegir un día, los títulos cambian de "(hoy)" a la fecha y los números se recalculan. Si ese día tiene un corte sin guardar aparece el aviso naranja "Corte en curso: datos parciales". |
| Tarjeta **Litros vendidos** | Solo informativa. |
| Tarjeta **Ingresos estimados** | Solo informativa (litros × precio de cada sucursal). |
| Tarjeta **Tanques en estado crítico** | Solo informativa. Rojo si > 0, verde si 0. |
| Tarjeta **Sucursales activas** | Solo informativa. |
| Fila **Regular / Súper / Diésel** (con ›) | **Navigate to** Detalle de combustible (11) con el alcance y fecha actuales del panel. Muestra litros y dinero vendidos, compras y pérdidas. |
| Lista **Sucursales** (filas con ›) | **Navigate to** Detalle de sucursal (12). |

### 11 — Detalle de combustible, todas las sucursales (`Capturas/11_gg_detalle_combustible_todas.png`)
| Elemento | Acción |
|---|---|
| Barra superior "‹" | **Back** → Panel General. |
| Subtítulo "Todas las sucursales" | Indica el alcance. |
| 4 tarjetas (litros, ventas $, compras, pérdidas) | Solo informativas, para el día elegido. |
| Bloque **Por sucursal** | Un bloque por sucursal: vendido (L y $), compras, pérdidas y fila de tanque. |
| Fila de tanque | Badge de estado (**Crítico** rojo ≤ 20 %, **Medio** naranja ≤ 50 %, **Óptimo** verde), barra de nivel y "Autonomía estimada". |
| Icono **?** junto a Autonomía | **Open overlay (popover)** con la explicación: "Días que durará el combustible… nivel actual ÷ litros vendidos por día". Se cierra tocando fuera. |
| **Historial de ventas por día** | Lista de días (más reciente primero) con dinero, litros, compras y pérdidas. Los días con corte sin guardar llevan "· parcial". Solo informativo. |

### 12 — Detalle de sucursal (`Capturas/12_gg_detalle_sucursal.png`)
| Elemento | Acción |
|---|---|
| "‹" | **Back**. |
| **Fecha** | Igual que en 10 (recalcula todo). |
| Tarjetas **Ventas** e **Ingresos** | Solo informativas. |
| **Niveles de tanque** | 3 filas de tanque (con badge de estado, barra y autonomía + icono **?**). |
| Fila **Regular / Súper / Diésel** (›) | **Navigate to** Detalle de combustible de esa sucursal (13). |
| Nota | Es una vista de **consulta**: el Gerente General no registra cortes aquí. |

### 13 — Detalle de combustible, una sucursal (`Capturas/13_gg_detalle_combustible_sucursal.png`)
Igual que 11 pero con una sola sucursal: bloque "Ventas y tanque", **precio vigente por litro** y el historial de esa sucursal. Botón "‹" → **Back**.

### 14 — Usuarios (`Capturas/14_gg_usuarios.png`)
| Elemento | Acción |
|---|---|
| Botón **＋** (barra superior derecha) | **Open overlay (sheet)** → Nuevo usuario (15). |
| Fila de usuario (con ›) | **Navigate to** Editar usuario (16). Muestra nombre, badge rojo "Inactivo" si aplica, correo y rol/sucursal. |

### 15 — Nuevo usuario (`Capturas/15_gg_usuario_nuevo.png`) — hoja
| Elemento | Acción / validación |
|---|---|
| Botón **X** | Cierra la hoja → Usuarios. |
| **Nombre completo** | Solo letras, espacios y `' - .` (los números se descartan al escribir o pegar). |
| **Correo electrónico** | No permite espacios; debe tener formato `algo@dominio.ext`. |
| **Contraseña** | Mínimo 4 caracteres. |
| Segmentado **Rol** | *Gerente General* / *Gerente de Sucursal*. Al elegir *Gerente de Sucursal* aparece el selector **Sucursal**; con *Gerente General* se oculta (**Change to** variante). |
| Selector **Sucursal** | Lista de sucursales (o "Selecciona una sucursal"). Obligatorio para Gerente de Sucursal. |
| Botón **Crear usuario** | Deshabilitado hasta que todo sea válido. Si la sucursal ya tiene un Gerente de Sucursal activo → aparece un texto rojo de error: "Esa sucursal ya tiene un gerente asignado…". El error **desaparece** al cambiar cualquier campo o a los 4 segundos. Si es correcto → cierra la hoja y el usuario aparece en la lista. |

### 16 — Editar usuario (`Capturas/16_gg_usuario_editar.png`) — pantalla empujada
Mismos campos que 15 (sin contraseña en "Datos del usuario") más:
- Sección **Cambiar contraseña** → campo **Nueva contraseña**. En blanco = se conserva la
  actual; si se escribe, mínimo 4 caracteres. Así el Gerente General restablece contraseñas.
- Interruptor **Usuario activo** (desactivar/reactivar). En Figma es interactivo (se enciende/apaga al tocarlo).

Botón **Guardar cambios** (mismas validaciones y regla de "un gerente por sucursal")
→ **Back** a Usuarios. Se sale con "‹" (sin X, no es hoja).

### 17 — Sucursales (`Capturas/17_gg_sucursales.png`)
| Elemento | Acción |
|---|---|
| Botón **＋** | **Open overlay (sheet)** → Nueva sucursal (18). |
| Fila de sucursal (›) | **Navigate to** Editar sucursal (19). Badge rojo "Inactiva" si aplica. |

### 18 — Nueva sucursal (`Capturas/18_gg_sucursal_nueva.png`) — hoja
| Elemento | Acción / validación |
|---|---|
| Botón **X** | Cierra la hoja. |
| **Nombre** y **Dirección** | Texto libre, obligatorios. |
| **Capacidad de tanques (litros)** — Regular, Súper, Diésel | Solo dígitos (las letras se descartan, también al pegar). Las 3 deben ser mayores a 0. |
| Botón **Crear sucursal** | Deshabilitado hasta que nombre, dirección y las 3 capacidades sean válidos. Al tocar → cierra la hoja y la sucursal aparece en la lista (con 6 bombas, tanques en 0 L). |

### 19 — Editar sucursal (`Capturas/19_gg_sucursal_editar.png`) — pantalla empujada
Mismos campos, más el interruptor **Sucursal activa**. La capacidad de un tanque **no puede
ser menor a su nivel actual**: si lo es, el botón se deshabilita y aparece el aviso con los
niveles actuales. **Guardar cambios** → **Back**.

### 20 — Precios (`Capturas/20_gg_precios.png`)
| Elemento | Acción |
|---|---|
| Selector segmentado de **sucursal** (aparece si hay más de una) | **Change to** variante: la lista muestra los precios de la sucursal elegida. (Nota: con muchas sucursales el segmentado puede quedar apretado; en Figma se puede usar un menú.) |
| Fila **Regular / Súper / Diésel** con precio (›) | **Navigate to** Editar precio (21). |

### 21 — Editar precio (`Capturas/21_gg_precio_editar.png`)
| Elemento | Acción / validación |
|---|---|
| Campo **Precio** | Solo números con un separador decimal. |
| Botón **Guardar precio** | Deshabilitado si el valor no es un número. Al tocar → **Back** a Precios; el cambio queda en el historial. |
| **Historial de cambios** | Lista "precio anterior → nuevo" con fecha y hora. Solo informativa. |

### 22 — Perfil (`Capturas/22_gg_perfil.png`)
| Elemento | Acción |
|---|---|
| Datos de la cuenta | Nombre, correo, rol (solo lectura). |
| Botón **Cambiar contraseña** | **Open overlay (sheet)** → Cambiar contraseña (23). |
| Botón **Cerrar sesión** (rojo) | Cierra la sesión → Login. |

### 23 — Cambiar contraseña (`Capturas/23_cambiar_contrasena.png`) — hoja
| Elemento | Acción / validación |
|---|---|
| Botón **X** | Cierra la hoja. |
| **Contraseña actual / Nueva / Confirmar** | Campos ocultos. |
| Botón **Guardar** | Errores en rojo: "La contraseña actual no es correcta.", "La nueva contraseña debe tener al menos 4 caracteres.", "Las contraseñas nuevas no coinciden." Si es correcto → cierra la hoja. |

---

## 3. Gerente de Sucursal

> El Gerente de Sucursal solo ve su sucursal. No tiene acceso a usuarios, sucursales ni precios.

### 30 — Panel de sucursal, sin cortes (`Capturas/30_gs_panel_sin_cortes.png`)
| Elemento | Acción |
|---|---|
| **Fecha** | Igual que el panel general: consulta otro día (títulos y datos cambian). Aviso "parcial" si hay corte en curso. |
| Tarjetas **Ventas** / **Ingresos estimados** | Solo informativas. |
| **Niveles de tanque** | 3 filas con estado Crítico/Medio/Óptimo, barra y autonomía (con **?** que abre popover explicativo). |
| Filas **Regular / Súper / Diésel** (›) | **Navigate to** Detalle de combustible de su sucursal (39). |
| **Cortes (fecha)** | Dos filas informativas: *Corte Matutino* y *Corte Vespertino* con estado "En curso · n/6 bombas" (gris) o "Guardado" (verde). |
| Botón **Registrar corte** (naranja) | **Open overlay (sheet)** → Registrar corte (31). Siempre registra el corte de **hoy**. |

### 31 — Registrar corte, vacío (`Capturas/31_gs_corte_vacio.png`) — hoja
| Elemento | Acción |
|---|---|
| Botón **X** | Cierra la hoja → Panel. |
| Segmentado **Matutino / Vespertino** | **Change to** variante: muestra las bombas de ese corte. |
| Lista **Bomba 1…6** | Cada bomba pendiente (círculo vacío, "Pendiente") → **Navigate to** Formulario de bomba (32). |
| Vespertino bloqueado | Si el Matutino no está guardado: las bombas se ven atenuadas sin flecha y el pie dice "Debes guardar el corte matutino antes de registrar el vespertino." |
| Botón **Guardar corte** | Deshabilitado ("Registra las 6 bombas para poder guardar el corte."). |

### 32 — Formulario de bomba (`Capturas/32_gs_bomba_formulario.png`)
Una sección por combustible (**Regular, Súper, Diésel**), cada una con:

| Campo | Regla |
|---|---|
| **Ventas (L)** | Solo números; vacío = 0. |
| **Compras / recepción (L)** | Solo números; no puede superar el espacio libre del tanque. |
| **Pérdidas o daños (L)** | Solo números. Si es > 0 aparece el selector **Motivo**: Merma, Fuga, Falla técnica, Derrame (**Change to** variante con el selector visible). |
| Pie de sección | "Tanque: X L disponibles · espacio libre Y L" (ayuda al validar). |

| Elemento | Acción |
|---|---|
| Botón **Guardar bomba** | Si ventas + pérdidas superan lo disponible, o las compras superan el espacio libre → texto rojo de error con el máximo permitido (variante de error). Si es válido → **Back** al corte y la bomba queda marcada con ✓. |
| Botón "‹" | Volver sin guardar. |

### 33 — Corte en curso (`Capturas/33_gs_corte_en_curso.png`)
| Elemento | Acción |
|---|---|
| Bombas guardadas (✓ verde, "n L vendidos · editable") | **Navigate to** Formulario de bomba con los valores cargados (35) para corregirlos. |
| Bombas pendientes | **Navigate to** Formulario de bomba vacío (32). |
| Encabezado | "Bombas registradas: 3 de 6". |
| **Consolidado del corte** | Ventas, compras y pérdidas por combustible; se actualiza con cada bomba. |
| Botón **Guardar corte** | Sigue deshabilitado hasta tener las 6 bombas. |
| Prototipo en Figma | La fila **Bomba 6** (pendiente) lleva a la pantalla **35b**, que simula haber registrado las 6 bombas. Las bombas 4 y 5 llevan al formulario vacío (32). |
| Botón **X** | Cierra la hoja → Panel con corte en curso (34). |

### 34 — Panel con corte en curso (`Capturas/34_gs_panel_en_curso.png`)
Igual que 30 pero con: aviso naranja "Corte en curso: datos parciales", las ventas de las bombas ya registradas y la fila del Matutino en "En curso · 3/6 bombas".

### 35 — Editar bomba (`Capturas/35_gs_bomba_editar.png`)
Igual que 32 con los valores cargados; el botón dice **Guardar cambios**. Se puede editar
cuantas veces se quiera **mientras el corte no esté guardado**. → **Back**.

### 35b — Corte completo sin guardar (solo en Figma, sin captura de la app)
Estado del corte con las **6 bombas registradas** y todavía editable. Se agregó porque las capturas
33 (3 de 6 bombas) y 36 (ya guardado) no muestran el botón **Guardar corte** habilitado.

| Elemento | Acción |
|---|---|
| Encabezado | "Bombas registradas: 6 de 6". |
| Bombas (✓ verde, "n L vendidos · editable") | **Navigate to** Editar bomba (35): siguen editables. |
| **Consolidado del corte** | Ventas, compras y pérdidas por combustible con las 6 bombas (Regular 705 L / 300 / 0, Súper 423 L, Diésel 564 L / pérdidas 12 L). |
| Botón **Guardar corte** (habilitado, azul) | **Navigate to** Corte guardado (36). En la app real abre antes la alerta de confirmación descrita en 36. |
| Botón **X** | Cierra la hoja → Panel con corte en curso (34). |

### 36 — Corte guardado (`Capturas/36_gs_corte_guardado.png`)
| Elemento | Acción |
|---|---|
| Botón **Guardar corte** (con las 6 bombas, pantalla 35b) | **Open overlay (alerta)**: "¿Guardar el corte Matutino?" / "Después de guardarlo no podrás editar la información de las bombas." con botones **Cancelar** y **Guardar corte**. |
| Alerta → **Guardar corte** | El corte queda **bloqueado**: desaparece el botón Guardar corte, el pie dice "Corte guardado: ya no se puede editar, solo consultar…", las bombas muestran "ver detalle" y los niveles de tanque se actualizan (nivel + compras − ventas − pérdidas). |
| Alerta → **Cancelar** | Cierra la alerta sin cambios. |
| Bomba (›) | **Navigate to** Detalle de bomba, solo lectura (37). |
| Segmentado **Vespertino** | Ahora sí permite registrar las bombas del Vespertino (mismo flujo). |

### 37 — Detalle de bomba, solo lectura (`Capturas/37_gs_bomba_detalle_solo_lectura.png`)
Ventas, compras, pérdidas y motivo por combustible. Sin campos editables ni botón de guardar. "‹" → **Back**.

### 38 — Panel con cortes guardados (`Capturas/38_gs_panel_con_cortes.png`)
Igual que 30 con datos: litros e ingresos, desglose por combustible (litros y dinero, compras, pérdidas), tanques actualizados y el Matutino en "Guardado" (verde).

### 39 — Detalle de combustible de la sucursal (`Capturas/39_gs_detalle_combustible.png`)
Igual que 13: tarjetas del día, tanque con autonomía (**?** → popover), precio vigente e historial de ventas por día. "‹" → **Back**.

### 40 — Perfil del Gerente de Sucursal (`Capturas/40_gs_perfil.png`)
Igual que 22 e incluye el campo **Sucursal**. **Cambiar contraseña** → hoja (23); **Cerrar sesión** → Login.

---

## 4. Estados y validaciones a prototipar como variantes

| Componente | Variantes |
|---|---|
| Badge de tanque | Crítico (rojo) · Medio (naranja) · Óptimo (verde) |
| Barra de tanque | Color según el estado del badge |
| Fila de corte (panel) | "En curso · n/6 bombas" (gris) · "Guardado" (verde) |
| Fila de bomba | Pendiente (círculo vacío) · Registrada/editable (✓ + "editable") · Guardada (✓ + "ver detalle") · Bloqueada (atenuada) |
| Botón **Guardar corte** | Deshabilitado (< 6 bombas) · Habilitado (6 bombas) · Oculto (corte guardado) |
| Aviso de fecha | Sin aviso · "Corte en curso: datos parciales" (naranja) |
| Campos numéricos | Vacío · Con valor · Error (texto rojo al guardar) |
| Botones de guardado | Habilitado / Deshabilitado |

## 5. Reglas de negocio que conviene anotar en el prototipo
- Cada sucursal tiene **6 bombas**; cada bomba despacha los **3 combustibles** (Regular, Súper, Diésel).
- **2 cortes diarios** (Matutino y Vespertino); el Vespertino exige el Matutino guardado.
- Por bomba y combustible se registran **ventas, compras/recepción y pérdidas o daños** (merma, fuga, falla técnica, derrame).
- Un corte se **guarda** solo con las 6 bombas; hasta entonces las bombas se pueden editar. Guardado = solo lectura.
- Los tanques se actualizan **al guardar el corte**: nivel + compras − ventas − pérdidas.
- Validación: ventas + pérdidas ≤ combustible disponible; compras ≤ espacio libre del tanque.
- Alerta de tanque: **Crítico ≤ 20 %**, **Medio ≤ 50 %**, **Óptimo** por encima.
- Autonomía estimada = nivel actual ÷ promedio diario vendido.
- Máximo **1 Gerente de Sucursal activo por sucursal**.
- Ingresos = litros vendidos × **precio vigente de esa sucursal** (el precio varía por sucursal).
- Los dashboards incluyen datos parciales (cortes sin guardar) con el aviso correspondiente y permiten elegir otro día.

## 6. Fuera del alcance de esta entrega (según el PDF)
Gestión de empleados, control de turnos y horarios, venta de productos de conveniencia o
lubricantes, y otros servicios.

## 7. Prototipo en Figma: flotantes y estados

Figma abre los flotantes centrados y del tamaño de la pantalla: cada uno trae un **velo**
que se cierra al tocarlo (como tocar fuera en iOS) y la tarjeta flotante en su posición.

| Flotante | Se abre desde | Qué hace |
|---|---|---|
| **Menú sucursal** (6 versiones, con ✓ en la opción actual) | Selector "Todas las sucursales ⌃⌄" del Panel General | Cada opción **navega** al panel filtrado (`10 Panel General · 76 …`) o vuelve a "Todas". |
| **Calendario · Panel General** | Fecha del Panel General | Días futuros (27–30) desactivados. **26** → panel de hoy; **25** → `10 Panel General · 25 Sep`; otros días cierran el calendario. |
| **Calendario** | Fecha de 12, 30, 34 y 38 | Días futuros desactivados; elegir un día lo cierra. |
| **Ayuda · Autonomía estimada** | Línea "Autonomía estimada ⓘ" de cualquier fila de tanque | Popover con la explicación del cálculo. |
| **Alerta · Guardar corte** | Botón **Guardar corte** en `35b` | **Cancelar** cierra; **Guardar corte** → `36 Corte guardado`. |
| **Menú sucursal · Nuevo / Editar usuario** | Fila **Sucursal** en 15 y 16 | Cambia la variable y la fila muestra la sucursal elegida. |
| **Menú motivo de pérdida** | Fila **Motivo** en `35` (Diésel, 12 L de pérdida) | Merma, Fuga, Falla técnica o Derrame; la fila se actualiza. |
| **Cuentas de demostración** | Campos del Login | Elige la cuenta del Gerente General (`01g`) o de 76 Poniente (`01s`). |

**Selectores que cambian la pantalla (variables):**
- **Rol** en 15 y 16: *Gerente General* oculta la fila **Sucursal**; *Gerente de Sucursal* la muestra.
- **Sucursal** en Precios (20): el segmento elegido queda marcado.
- **Interruptores** "Usuario activo" (16) y "Sucursal activa" (19): se encienden y apagan.

**Matutino / Vespertino en el corte:**
- En `31`, `33` y `35b` (Matutino sin guardar), **Vespertino** → `31v`: bombas atenuadas y el aviso
  "Debes guardar el corte matutino antes de registrar el vespertino."
- En `36` (Matutino guardado), **Vespertino** → `36v`: bombas disponibles → `32v` (formulario del
  Vespertino, *Guardar bomba* vuelve al corte).
- **Matutino** en `31v`/`36v` → **Back**.

**Limitaciones del prototipo:** los campos de texto no se pueden escribir en Figma (los valores
son de ejemplo) y el panel filtrado por sucursal lleva al detalle de combustible de todas las
sucursales (`11`).
