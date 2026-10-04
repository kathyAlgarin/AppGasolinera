# Gasolineras — guía de interacciones para el prototipo en Figma

> **Esta guía describe el diseño NUEVO** (corte con lecturas de mangueras, Cajero, tienda, personal, vaciado de tanque).
> El archivo de Figma actual **corresponde al diseño anterior** y hay que actualizarlo siguiendo este documento:
> https://www.figma.com/design/P4lxHxo4WqEK2xvQu4XRXq
> Las reglas de negocio están en [`docs/FLUJO.md`](docs/FLUJO.md); a qué datos llama cada pantalla, en
> [`docs/PLAN_DESARROLLO.md`](docs/PLAN_DESARROLLO.md).

- Cada pantalla mide **402 × 874** (iPhone 17 Pro). El contenido hace *scroll* dentro del marco y la barra de pestañas queda **fija** abajo.
- Páginas sugeridas en Figma: **Pantallas** (secciones Autenticación, Gerente General, Gerente de Sucursal, Cajero, Flotantes) y **Componentes**.
- Puntos de inicio del prototipo: Login (`01`), Gerente General (`10`), Gerente de Sucursal (`30`) y Cajero (`60`).
- Los datos de ejemplo del prototipo son **ficticios**; no usar cuentas reales.

**Vocabulario de acciones (Figma):**
- **Navigate to** → pantalla empujada (con "‹ atrás").
- **Open overlay (sheet)** → hoja que sube desde abajo; se cierra con la **X** o arrastrando.
- **Open overlay (alerta / popover)** → ventana centrada o globo de ayuda; se cierra tocando fuera.
- **Back** → volver. **Change to (variant)** → cambia el estado de un componente. **Scroll** → pantallas largas con *Vertical scrolling*.

**Componentes reutilizables sugeridos:** tarjeta de métrica, fila de tanque (estado + barra + autonomía), fila de combustible,
fila de lista estándar, selector de periodo, selector de sucursal, **campo numérico** (variantes vacío / con valor / error),
**icono de ayuda "?"** (abre popover), botón primario, botón de cierre **X**, insignia de estado, fila de bomba
(Pendiente / Guardada ✓ / Bloqueada), tarjeta de artículo del POS, fila de carrito, teclado numérico de cobro.

---

## 0. Navegación general

| Rol | Pestañas (barra inferior fija) |
|---|---|
| **Gerente General** | **Panel · Sucursales · Precios · Usuarios · Más** (Más: Catálogo, Pérdidas y contaminaciones, Personal, Tienda y cajas, Perfil) |
| **Gerente de Sucursal** | **Inicio · Corte · Tienda · Personal · Más** (Más: Historial, Cajeros, Perfil). *Tienda* y *Cajeros* **solo aparecen si la sucursal tiene tienda**. |
| **Cajero** | **Caja · Ventas · Perfil** |

| Elemento | Interacción |
|---|---|
| Login correcto | **Navigate to** el inicio del rol (sin volver al login). Si el usuario debe cambiar su contraseña → `05` antes que nada. |
| Cerrar sesión | Perfil → **Cerrar sesión** → Login. |
| Teclado | Tocar fuera o arrastrar oculta el teclado. |
| Campos numéricos | **No aceptan letras, signos negativos ni más de 2 decimales** (las cantidades de tienda, solo enteros). Lo que no cabe se descarta al escribir o pegar. |
| Mensajes de error | Texto rojo bajo el campo o sobre el botón, con el mensaje exacto del servidor; desaparece al editar. |
| Pantallas con datos | Cuatro estados: **cargando**, **vacío** (texto útil, p. ej. "Sin pérdidas registradas"), **error** (con *Reintentar*), **contenido**. |

---

## 1. Autenticación (todos los roles)

| Pantalla | Elementos y acciones |
|---|---|
| **01 Login** | Correo (teclado de correo, sin autocapitalizar) · Contraseña (oculta) · **Ingresar** → inicio del rol; error → "Correo o contraseña incorrectos." · **¿Olvidaste tu contraseña?** → `02`. Variantes: `01e` (error). |
| **02 Recuperar: correo** | Campo de correo (formato válido) · **Enviar código** → `03`. |
| **03 Recuperar: código** | 6 casillas numéricas · **Verificar** → `04`; error "Código incorrecto o vencido." · **Reenviar código** (con espera). |
| **04 Nueva contraseña** | Nueva + confirmar (mínimo 8 caracteres) · **Guardar** → Login con aviso de éxito. |
| **05 Cambio obligatorio** | Aparece tras iniciar con una **contraseña temporal**. Nueva + confirmar (8–72 caracteres) · **Guardar** → inicio del rol. No hay "atrás". |
| **Perfil** (cada rol) | Nombre, correo, rol y sucursal (solo lectura) · **Cambiar contraseña** → hoja · **Cerrar sesión**. |

---

## 2. Gerente General

### 10 — Panel
| Elemento | Acción |
|---|---|
| **Sucursal** (menú) | *Todas* o una sucursal → **Change to**: todas las cifras se recalculan. |
| **Periodo** (segmentado) | **Hoy · 7 días · 30 días · Fechas** (este último abre calendario sin fechas futuras). |
| Tarjetas por combustible (Súper, Regular, Diésel) | Galones vendidos, ingreso USD, compras, pérdidas. Tocar → `11`. |
| Aviso de datos | "**Datos de N de M cortes**". Si no hay cortes cerrados: cifras en cero con el texto **"Sin cortes cerrados hoy"** y un **?** que explica que las ventas se conocen al cerrar el corte. |
| Gráfico de tendencia | Galones vendidos por día (series por combustible). |
| Ranking de sucursales | Por ventas; tocar una fila → `12`. |
| Tanques críticos | Lista de tanques en estado **Crítico**, arriba. Tocar → `12`. |
| Sucursales sin corte cerrado hoy | Lista informativa. |
| Cortes con diferencia | Cuenta del periodo (indicador, sin alertas). |
| Bloque **Tienda y servicios** | Ingreso por categoría, anulaciones, diferencias de cierre de caja y productos con stock bajo. **Separado** del combustible. |

### 11 — Detalle de combustible
Tarjetas del periodo y filas por sucursal (vendido, compras, pérdidas, fila de tanque con estado). Icono **?** junto a Autonomía → popover con el cálculo.
"‹" → Back.

### 12 — Detalle de sucursal (solo consulta)
Encabezado con **Gerente asignado**. Secciones: **Tanques** (nivel *estimado al corte del …*, % y estado, días de autonomía, y el texto
"Incluye N compras y M pérdidas del corte en curso") · **Cortes** (historial → `13`) · **Pérdidas registradas** (lista con tipo, galones, bomba, nota; vacío:
"Sin pérdidas registradas") · **Precios vigentes** · **Personal** · **Tienda**. El Gerente General **no** registra cortes aquí.

### 13 — Reporte de corte (también lo ve el Gerente de Sucursal)
| Elemento | Acción |
|---|---|
| Encabezado | Sucursal, tipo (Matutino/Vespertino), fecha operativa, quién cerró. Insignias **Ajustado** y **Cambio de medidor** si aplican. |
| Las 6 bombas | Por bomba y combustible: lectura inicial, final, galones, USD. |
| Consolidado por combustible | Galones, USD, compras, pérdidas. |
| **Cuadre** | Nivel inicial, compras, medidor, pérdidas, **nivel teórico**, **nivel medido**, **diferencia** con indicador *Cuadra* / *Diferencia* (con **?** que explica la tolerancia del 0.5 %). |
| **Ajustar lectura** (solo Gerente General) | Visible solo si el corte siguiente sigue abierto → hoja `14`. |

### 14 — Ajustar lectura (hoja)
Manguera (selector), **valor correcto** (campo numérico, no menor a la lectura inicial), **motivo** (obligatorio, mínimo 3 caracteres) · **Guardar ajuste** → cierra y el reporte muestra "Ajustado".
Si el corte siguiente ya se cerró, el botón no aparece y un texto explica que el corte es definitivo.

### 15–17 — Sucursales
| Pantalla | Interacción |
|---|---|
| **15 Lista** | **＋** → `16`. Fila → `17`. Insignias *Inactiva* y *Con tienda*. |
| **16 Nueva sucursal** (hoja) | **Nombre**, **Dirección**, interruptor **Tiene tienda**, y por cada combustible (**Súper, Regular, Diésel**): **capacidad (gal)** (obligatoria, > 0) y **nivel inicial (gal)** (opcional: vacío = 0), con el nivel ≤ capacidad. **Crear sucursal** (deshabilitado hasta que todo sea válido). Texto de apoyo: "Se crearán 6 bombas, 18 mangueras y 3 tanques." |
| **17 Editar sucursal** | Nombre y dirección; interruptores **Activa** y **Tiene tienda** (no se apaga con cajas abiertas). Los tanques son de solo lectura. |

### 18–20 — Precios
| Pantalla | Interacción |
|---|---|
| **18 Precios** | Selector de sucursal · filas **Súper / Regular / Diésel** con precio vigente y fecha desde. Si falta alguno: aviso "Sin precio: la sucursal no podrá cerrar cortes". |
| **19 Fijar precio** (hoja) | **Combustible**, **precio por galón** (> 0, 2 decimales, precio final con impuestos), **Aplicar a**: *Esta sucursal* / *Elegir sucursales* / *Todas*. **Guardar**. |
| **20 Historial de precios** | Lista cronológica por sucursal y combustible. Solo informativa. |

### 21–23 — Usuarios
| Pantalla | Interacción |
|---|---|
| **21 Lista** | Filtros por rol y sucursal; fila con nombre, correo, rol, sucursal e insignia *Inactivo*. **＋** → `22`. Fila → `23`. |
| **22 Nuevo usuario** (hoja) | Nombre, correo (formato válido), **contraseña temporal** (8–72 caracteres, con ojo para verla), **Rol** (*Gerente General · Gerente de Sucursal · Cajero*). **Sucursal** solo para *Gerente de Sucursal* y *Cajero* (para *Cajero*, solo sucursales con tienda). Error posible: "Esa sucursal ya tiene un Gerente de Sucursal activo." Texto: "Deberá cambiarla al iniciar sesión." |
| **23 Editar usuario** | Datos en solo lectura · **Restablecer contraseña** (hoja con contraseña temporal) · **Cambiar correo** (por si estaba mal escrito; no sobre uno mismo) · interruptor **Activo** (no se puede desactivar al último Gerente General ni a uno mismo; mensaje del servidor). |

### 24–25 — Catálogo (Más)
| Pantalla | Interacción |
|---|---|
| **24 Lista** | Productos y servicios con categoría, precio e insignia *Inactivo*. **＋** → `25`. |
| **25 Artículo** | **Nombre**, **categoría** (*Lubricantes · Bebidas · Snacks · Otros productos · Servicios*), **tipo** (*Producto* con inventario / *Servicio* sin inventario; al elegir *Servicios* el tipo queda en *Servicio*), **precio USD** (> 0), interruptor **Activo**. Al editar, tipo y categoría no cambian. |

### 26 — Pérdidas y contaminaciones (Más)
Lista global filtrable por sucursal, tipo y fecha. Las de tipo **Contaminación** llevan insignia propia. Vacío: "Sin pérdidas registradas".

### 27 — Personal (Más) · consulta
Por sucursal: empleados, turnos, horario semanal y **Quién trabaja ahora**.

### 28 — Tienda y cajas (Más) · consulta
Cierres de caja (fondo, esperado, contado, diferencia, **Forzado**), anulaciones por sucursal y productos con stock bajo.

---

## 3. Gerente de Sucursal

> Solo ve su sucursal. No ve precios editables, usuarios de otras sucursales ni otras sucursales.

### 30 — Inicio
| Elemento | Acción |
|---|---|
| **Tanques** (3) | Nivel *estimado al corte del …* (fecha y hora visibles), %, estado **Crítico / Medio / Óptimo**, días de autonomía (o "Autonomía aún no disponible" en sucursales nuevas) y "Incluye N compras y M pérdidas del corte en curso" (con **?**). |
| **Corte en curso** | Tarjeta con el estado (bombas N/6, compras, pérdidas) y botón **Continuar corte** → `31`. |
| Resumen de hoy | Galones e ingreso de los cortes **cerrados** hoy, con "Sin cortes cerrados hoy" si no hay. |

### 31 — Corte en curso (centro del flujo)
Lista de secciones, cada una con su estado: **Bombas (N de 6)** → `32` · **Compras** → `35` · **Pérdidas** → `37` · **Descarga errónea y vaciado** → `39` ·
**Tienda** (entradas y bajas; solo si hay tienda) → `46` · **Niveles de tanque** → `40` · **Resumen y cierre** → `41`.
Junto al título, icono **?**: "Las lecturas y los niveles se ingresan manualmente: lee el totalizador de cada manguera y mide el tanque con varilla."
El botón **Resumen y cierre** está deshabilitado hasta tener las 6 bombas y los 3 niveles; debajo, el motivo ("Faltan: Bomba 4, 5").

### 32–34 — Bombas
| Pantalla | Interacción |
|---|---|
| **32 Bombas** | Lista **Bomba 1–6**: *Pendiente* (círculo vacío) o *Guardada ✓* (editable). Tocar → `33`. |
| **33 Bomba N** | Tres secciones (**Súper, Regular, Diésel**) con **lectura final (gal)**. En el **primer corte de la sucursal** también **lectura inicial (gal)** (se explica con **?**: "Solo se pide una vez: es lo que marcaba cada manguera al empezar a usar el sistema"); desde el segundo corte la inicial aparece como dato fijo. Reglas: final ≥ inicial (error: "La lectura final no puede ser menor que la inicial (valor)"). **Guardar bomba** → Back (borrador editable hasta cerrar). Enlace **El medidor se cambió** → `34`. |
| **34 Cambio de medidor** (hoja) | Manguera, **lectura final del medidor viejo**, **lectura inicial del nuevo** (normalmente 0), **nota** obligatoria · **Guardar**. Se muestra la fórmula de galones. |

### 35–36 — Compras
| Pantalla | Interacción |
|---|---|
| **35 Compras** | Lista de descargas del corte (combustible, galones, proveedor, hora); **＋** → `36`; deslizar para **editar/eliminar** (las generadas por un vaciado aparecen bloqueadas con candado). |
| **36 Nueva compra** (hoja) | **Combustible** (tanque), **galones** (> 0), **proveedor** (opcional, solo nombre). Error: "La compra excede el espacio libre del tanque (libre: N gal)." |

### 37–38 — Pérdidas
| Pantalla | Interacción |
|---|---|
| **37 Pérdidas** | Lista con tipo, combustible, galones, bomba y nota; **＋** → `38`. Vacío: "Sin pérdidas registradas". |
| **38 Nueva pérdida** (hoja) | **Tipo** (*Merma · Fuga · Falla técnica · Derrame*), **combustible**, **galones** (> 0, ≤ nivel estimado), **Bomba (opcional)** con icono **?**: "Un derrame o una falla ocurre en una bomba; una fuga, en el tanque. Por eso es opcional.", **nota** obligatoria. |

### 39 — Descarga errónea y vaciado (hoja)
| Elemento | Acción |
|---|---|
| **Motivo** | *Descarga de combustible equivocado* · *Otra contaminación o mantenimiento* (**Change to** variante). |
| Tanque afectado | Selector. |
| (Motivo 1) **Combustible que traía la cisterna**, **galones descargados por error** | Combustible distinto al del tanque; galones ≤ nivel medido. |
| **Nivel medido tras la descarga** (varilla) | Obligatorio; con **?** que explica por qué se usa el medido y no el estimado. |
| **Nota** | Obligatoria. |
| Vista previa | "Se registrarán: pérdida de X gal de Regular · pérdida de Y gal de Diésel · el tanque quedará en 0." |
| **Registrar y vaciar** | Alerta de confirmación → guarda. No existe un botón "vaciar" sin motivo. |

### 40 — Niveles de tanque
Tres campos (**Súper, Regular, Diésel**), nivel medido en galones, ≤ capacidad, con **?** de captura manual. **Guardar niveles** → Back (se envían al cerrar el corte).

### 41–43 — Resumen y cierre
| Pantalla | Interacción |
|---|---|
| **41 Resumen** | Por combustible: galones, USD (precio vigente), compras, pérdidas, **nivel teórico vs medido** y **indicador de cuadre**. Insignias de cambio de medidor. Si hay tienda: cajas abiertas (con el motivo si bloquean el cierre). Selector **Matutino / Vespertino** solo en el **primer corte** de la sucursal. Botón **Cerrar corte**. |
| **42 Alerta** | "¿Cerrar el corte?" / "Después de cerrarlo no se podrá modificar." · **Cancelar** · **Cerrar corte**. |
| **43 Corte cerrado** | Confirmación con tipo y fecha operativa; botón **Ver reporte** → `13`; **Volver al inicio**. Errores posibles en pantalla anterior: "Faltan lecturas de las bombas: …", "Hay cajas abiertas…", "Ya hay 2 cortes cerrados en esta fecha operativa.", "La sucursal no tiene precio de … configurado." |

### 44 — Historial de cortes (Más)
Lista por fecha y tipo, con indicadores *Ajustado* y *Diferencia*; fila → `13`.

### 46–50 — Tienda (solo con tienda)
| Pantalla | Interacción |
|---|---|
| **46 Inventario** | Productos con stock y mínimo, insignia **Stock bajo**. Acciones **Entrada** → `47` y **Baja** → `48`. |
| **47 Entrada de mercadería** (hoja) | Producto, **cantidad** (entero > 0), proveedor opcional. |
| **48 Baja** (hoja) | Producto, cantidad (≤ stock), **motivo** (*Vencido · Dañado · Otro*; con *Otro* la nota es obligatoria). |
| **49 Ventas del corte** | Tickets con número, cajero, total, método e insignia **Anulada**. **Anular** (solo si la caja de esa venta sigue abierta) → hoja con **motivo** obligatorio. Si la caja ya cerró: "La venta es definitiva." |
| **50 Cajas** | Cajas del corte: abiertas y cerradas, con esperado, contado, diferencia e insignia **Forzado**. En una abierta: **Cierre forzado** → hoja con **efectivo contado** y **motivo** obligatorio. |

### 51–56 — Personal
| Pantalla | Interacción |
|---|---|
| **51 Empleados** | Lista con cargo y turno; **＋** → `52`. |
| **52 Empleado** | **Nombre**, **cargo** (*Despachador · Cajero · Supervisor · Mantenimiento · Otro*), teléfono y fecha de ingreso (opcionales), interruptor **Activo**. **Sin DUI**. |
| **53 Turnos** | Lista; **＋** → `54`. |
| **54 Turno** | **Nombre**, **hora de inicio**, **hora de fin** (≠ inicio). Texto: "Si el fin es menor que el inicio, el turno termina al día siguiente." Se permiten turnos que se solapan y huecos. |
| **55 Horario semanal** | Cuadrícula turnos × días; asignar a cada empleado **un turno y los días**. |
| **56 Quién trabaja ahora** | Empleados activos del turno actual; en un hueco: "Nadie en turno". Los turnos son **solo informativos**. |

### 57 — Cajeros (Más · solo con tienda)
Lista de cajeros de la sucursal; **＋** crea un cajero (nombre, correo, contraseña temporal); fila → restablecer contraseña y activar/desactivar.

---

## 4. Cajero

| Pantalla | Interacción |
|---|---|
| **60 Caja** | Sin caja abierta: **Abrir caja** → `61`. Con caja abierta: resumen (fondo, ventas del turno, efectivo esperado) y accesos a **Cobrar** → `62` y **Cerrar caja** → `67`. |
| **61 Abrir caja** (hoja) | **Fondo inicial (USD)** (≥ 0, 2 decimales) · **Abrir**. Error: "Ya tienes una caja abierta." |
| **62 POS** | Búsqueda y categorías; tarjetas de artículo (nombre, precio, stock; sin stock → atenuada). Tocar suma al **carrito**; cantidades con ＋/− (enteras, ≤ stock). Barra inferior con total y **Cobrar** → `63`. |
| **63 Cobro** (hoja) | Total · **Método** (*Efectivo · Tarjeta (simulada)*) · con *Efectivo*: **monto recibido** y **vuelto** calculado en pantalla (no se puede pagar con menos del total) · **Pagar** → `64`. Con *Tarjeta* no se pide ningún dato de tarjeta. |
| **64 Animación de pago** | Animación que **simula** el cobro (nota visible: "Pago simulado"). Al terminar → `65`. Errores del servidor (p. ej. "Stock insuficiente de …") vuelven al carrito. |
| **65 Ticket** | Número de ticket, líneas, total, recibido y vuelto · **Nueva venta** → `62`. |
| **66 Ventas** | Mis tickets del turno; fila → detalle de solo lectura. El Cajero **no puede anular**: texto "Pide al Gerente de Sucursal que la anule." |
| **67 Cerrar caja** | **Efectivo contado (USD)** · **Cerrar caja** → alerta de confirmación → resultado: **esperado, contado y diferencia** (faltante o sobrante) con indicador. Texto: "Después de cerrar no se pueden anular ventas de esta caja." |

---

## 5. Estados y variantes a prototipar

| Componente | Variantes |
|---|---|
| Insignia de tanque / barra | **Crítico** (rojo) · **Medio** (naranja) · **Óptimo** (verde) |
| Autonomía | Con días · "Autonomía aún no disponible" |
| Fila de bomba | Pendiente · Guardada ✓ · Bloqueada |
| Botón **Resumen y cierre** | Deshabilitado (con el motivo) · Habilitado |
| Indicador de cuadre | **Cuadra** (verde) · **Diferencia** (naranja, con ± galones) |
| Insignias de corte | Ajustado · Cambio de medidor · Cierre forzado · Anulada · Contaminación · Inactivo · Stock bajo |
| Dashboards | Con datos · "Sin cortes cerrados hoy" (ceros con explicación) |
| Campo numérico | Vacío · Con valor · Error |
| Venta | Completada · Anulada |
| Caja | Abierta · Cerrada · Cerrada forzada |

## 6. Reglas de negocio que conviene anotar en el prototipo
- Cada sucursal: **6 bombas × 3 mangueras** y **1 tanque por combustible**. Unidad: **galones**; dinero en **USD**.
- **2 cortes por día** (Matutino y Vespertino) que se cierran con las **6 bombas**; la lectura final es la inicial del siguiente. Captura **manual**.
- **Cuadre** medidor vs tanque como **indicador** (tolerancia 0.5 %). **Ajustes** solo del Gerente General, mientras el corte siguiente siga abierto.
- Compras **por tanque**; pérdidas con bomba opcional; **vaciado** solo con motivo.
- Precios **por sucursal**, solo del Gerente General; el corte usa el precio vigente **al cerrar**.
- Tanque: **Crítico ≤ 20 %**, **Medio ≤ 50 %**; por autonomía, **< 2 días** Crítico y **< 5 días** Medio; el estado es el peor de los dos.
- **Un Gerente de Sucursal activo** por sucursal; varios cajeros. Nada se borra: se desactiva o se anula.
- Tienda: pago **simulado**; el corte no se cierra con **cajas abiertas**; el cierre de caja compara el efectivo contado con el esperado.
- Turnos **solo informativos**, independientes de los cortes.

## 7. Flotantes

| Flotante | Se abre desde | Qué hace |
|---|---|---|
| Menú de sucursal | Selector del Panel y formularios | Elige una sucursal y actualiza la pantalla. |
| Calendario | Periodo *Fechas* (rango personalizado) | Sin fechas futuras. |
| Popover **?** | Iconos de ayuda (autonomía, captura manual, bomba opcional, primer corte, tolerancia del cuadre, "Sin cortes cerrados hoy") | Muestra la explicación; se cierra tocando fuera. |
| Alerta | Cerrar corte · Registrar y vaciar · Cerrar caja · Anular venta | **Cancelar** / confirmar. |
| Hojas de formulario | Casi todas las altas | **X** para cerrar. |

**Limitaciones del prototipo:** los campos de texto no se pueden escribir en Figma (los valores son de ejemplo) y los cálculos
(cuadre, vuelto, autonomía) se muestran ya resueltos para cada variante.
