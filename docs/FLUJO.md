# FLUJO DEL SISTEMA — decisiones cerradas

Fuente de verdad para el rediseño (flujo → pantallas → base de datos en Supabase).
Contexto: franquicia de gasolineras en El Salvador. Alcance: `proyecto_practico_laboratorio_22.md`
**incluyendo** lo que el `.md` marca como "pospuesto al Parcial 2" (empleados, turnos, tienda/lubricantes,
otros servicios): todo entra en este proyecto. Solo se anota aquí lo que ya quedó decidido.

**Plataformas**: la app iOS (SwiftUI) **y** una versión web (otra tecnología, por definir) con las **mismas
funcionalidades** para todos los roles, sobre el **mismo backend Supabase**. El proyecto se entrega **completo**
(no por fases). Por eso las reglas de negocio, permisos y validaciones viven en la BD y en funciones del
servidor, no duplicadas en cada cliente.

---

## 1. Estructura física de una sucursal — CERRADO

- **Bomba** = surtidor que despacha a los carros. Cada sucursal tiene **exactamente 6**.
- **Manguera**: cada bomba tiene **3 mangueras**, una por combustible (Súper, Regular, Diésel).
  El **totalizador** (contador acumulado) vive en la manguera. Son **18 mangueras** por sucursal.
- **Tanque**: **1 por combustible** → 3 por sucursal. La BD no debe impedir tener más de uno por producto.
- **Unidad**: **galones** en toda la app y la BD. Precios en **USD por galón**.
- **Combustibles**: Súper, Regular, Diésel (el código viejo decía `premium`).
- **Alta de sucursal** (Gerente General) pide solo: **nombre, dirección**, capacidad de cada tanque
  y nivel inicial de cada tanque. (Sin departamento/municipio, sin código.)
  Al crearla, el sistema **genera solo** las 6 bombas, las 18 mangueras y los 3 tanques.
- **Una sucursal se desactiva, nunca se borra** (los cortes históricos dependen de ella).

---

## 2. El corte — CERRADO

- Un **corte** es el cierre de un periodo de operación de **una sucursal**. Hay **2 por día**:
  Matutino y Vespertino. La lectura final de cada manguera es la **lectura inicial del siguiente corte**.
- Siempre hay un **corte en curso** (el periodo que empezó cuando cerró el anterior). Mientras está en curso
  se registran compras y pérdidas; al final se capturan lecturas y niveles y se **cierra**. Al cerrar, todo
  queda **bloqueado**.
- **Captura 100 % manual**: el gerente teclea la lectura del totalizador de cada manguera y el nivel de
  cada tanque (medido con varilla/sonda, ya en galones). La app **no** se conecta a las bombas.
  **UI**: icono "?" en el formulario del corte que explica que se ingresa manualmente.
- Galones vendidos por manguera = lectura final − lectura inicial. Ingreso oficial en USD = galones × precio vigente.
- **El corte no se puede cerrar** sin las 6 bombas × 3 lecturas (18).
- Al cerrar, el sistema consolida las 6 bombas en el reporte del corte.
- **Orden obligatorio**: el Vespertino exige el Matutino del mismo día cerrado, y el Matutino exige el
  Vespertino del día anterior cerrado (la cadena de lecturas no se rompe).
- **Primer corte** de una sucursal (solo al empezar a usar la app): pide inicial y final de las 18 mangueras
  (la inicial se teclea una sola vez). Desde el segundo corte solo se captura la final. El nivel inicial de
  tanques es el capturado al crear la sucursal.
- **Un solo cuadre: medidor vs tanque.** Nivel teórico = inicial + compras − galones del medidor − pérdidas;
  se compara con el nivel medido. La diferencia es **solo un indicador visible** (sin alertas ni umbral configurable).
- **No hay registro de ventas por despachador** (eso es de un POS, fuera de alcance). Solo 2 roles:
  Gerente General y Gerente de Sucursal.
- **Ajustes** a un corte cerrado: los registra solo el **Gerente General**, como registro aparte
  (manguera, valor correcto, motivo, quién, cuándo); el original se conserva y los reportes marcan "Ajustado".
  Solo posibles mientras el **siguiente corte no esté cerrado**; después es definitivo (política interna,
  sin norma salvadoreña conocida).
- Los cortes **no tienen hora fija** (se registra la hora real de cierre). Los **turnos de personal son
  independientes** de los cortes y son **solo información** (quién trabaja a cada hora), sin efecto en cortes ni pagos.
- **Empleados** = registro de personal sin usuario en la app, administrado por el Gerente de Sucursal.
- Nota de diseño para la BD: la lectura inicial de un corte se **deriva** de la final del anterior
  (no se guarda copia), así un ajuste se propaga solo.

---

## 3. Compras y pérdidas — CERRADO

Se registran como **líneas** dentro del corte en curso. Mientras el corte está en curso se pueden corregir o
eliminar; al cerrarlo quedan bloqueadas.

- **Compra (recepción de cisterna)**: combustible (= tanque), galones recibidos, fecha/hora (automática) y
  **nombre del proveedor** (opcional, texto libre). Sin número de documento. Puede haber varias por corte.
  Sube el nivel teórico del tanque. Va **por tanque**, no por bomba.
- **Pérdida o daño**: tipo (merma, fuga, falla técnica, derrame; además "contaminación", que solo genera el flujo de
  Descarga errónea y vaciado del tema 9), combustible, galones perdidos,
  **bomba (opcional)** y nota explicativa. Baja el nivel teórico del tanque.
  **UI**: icono "?" junto a "Bomba" que explica por qué es opcional (un derrame o falla ocurre en una bomba;
  una fuga, en el tanque).
- Lo que **no** se reporta como pérdida aparece como diferencia en el cuadre.
- Cada sucursal muestra el **listado de sus pérdidas registradas con detalle**; si no hay, estado vacío.
- ⚠ El `.md` pide "información individual de las 6 bombas": se cumple con las **ventas por bomba**
  (lecturas de mangueras). Compras por tanque; pérdidas con bomba opcional. (Decisión del usuario: seguir así.)

### Reglas de validación (aplican a TODA captura numérica de la app)

- Solo números; **sin letras, sin signos negativos, sin campos vacíos, sin más de un punto decimal**,
  máximo 2 decimales. Teclado numérico decimal.
- Compras y pérdidas: galones **> 0**.
- Una compra no puede superar el **espacio libre** del tanque.
- Una pérdida no puede superar el **nivel teórico** del tanque.
- Lecturas de manguera ≥ 0; la **final no puede ser menor que la inicial**.
- Nivel medido de tanque ≥ 0 y ≤ capacidad.
- Capacidad de tanque > 0; nivel inicial ≤ capacidad.
- Textos (nota, proveedor, nombre, dirección): longitud máxima, nota de pérdida obligatoria.
- Se valida en la app **y también en la BD** (restricciones `CHECK`), para que un dato inválido no entre por ningún lado.
- **Cambio de medidor** (CERRADO, opción B): si se cambia físicamente el totalizador de una manguera (el contador
  nuevo marca 0 o un valor bajo), el **Gerente de Sucursal** lo registra en el corte en curso: lectura final del
  contador viejo + lectura inicial del nuevo + nota obligatoria. Galones de esa manguera en el corte =
  `(final del viejo − inicial) + (final del nuevo − inicial del nuevo)`. El reporte lo marca con
  "Cambio de medidor" y el Gerente General lo ve. Tabla: `cambios_medidor` (id, corte_id, manguera_id,
  lectura_final_viejo, lectura_inicial_nuevo, nota, registrado_por, creado_en).

### Implicación para la BD (borrador, no aplicado)

| Tabla | Campos clave |
|---|---|
| `sucursales` | id, nombre, direccion, activa |
| `tanques` | id, sucursal_id, combustible, capacidad_gal, nivel_actual_gal |
| `bombas` | id, sucursal_id, numero (1–6) |
| `mangueras` | id, bomba_id, combustible, totalizador_actual_gal |
| `cortes` | id, sucursal_id, estado (en_curso/cerrado), cerrado_en, cerrado_por |
| `lecturas_manguera` | corte_id, manguera_id, lectura_inicial (solo 1.er corte), lectura_final |
| `niveles_tanque_corte` | corte_id, tanque_id, nivel_medido_gal |
| `compras` | id, corte_id, tanque_id, galones, proveedor (null), creada_en |
| `perdidas` | id, corte_id, tanque_id, tipo, galones, bomba_id (null), nota, creada_en |
| `ajustes_lectura` | id, corte_id, manguera_id, valor_correcto, motivo, ajustado_por, creado_en |
| `empleados` | id, sucursal_id, nombre, cargo, activo (turno: tema 8) |

---

## 4. Precios — CERRADO

Referencia (resúmenes de prensa, no verificado en la fuente oficial): la Dirección General de Energía,
Hidrocarburos y Minas publica precios por producto y por zona (central, occidental, oriental) cada quincena.

- Los precios son **por sucursal y por combustible** (no por zona: la sucursal no tiene departamento/municipio).
- **Solo el Gerente General** los cambia. El Gerente de Sucursal los ve, no los edita.
- **Cada cambio guarda su fecha de inicio** (`vigente_desde`); nunca se sobrescribe, el historial es dato.
- El Gerente General puede **aplicar un precio a todas las sucursales a la vez**, además de editarlo una por una.
- Se guarda **solo el precio final por galón** (ya con impuestos), sin desglose: el desglose es de facturación.
- Un corte usa el **precio vigente al cerrarlo** y **lo guarda dentro del corte**, así cambiar el precio después
  no altera cortes cerrados. Simplificación aceptada: si el precio cambia a mitad de periodo, todo el corte usa el
  precio al cierre (con captura manual no se sabe cuántos galones se vendieron antes/después).
- Una sucursal sin los 3 precios **no puede cerrar un corte**; la app lo avisa con un mensaje claro.
- Validación: precio > 0, máximo 2 decimales, mismas reglas numéricas de siempre.

| Tabla | Campos clave |
|---|---|
| `precios` | id, sucursal_id, combustible, precio_gal, vigente_desde, creado_por |
| `precios_corte` | corte_id, combustible, precio_gal (copia del vigente al cerrar) |

---

## 5. Tanques y alertas — CERRADO

- **Nivel mostrado** = nivel medido en el **último corte cerrado** + compras − pérdidas del corte en curso,
  con la **fecha/hora del corte visible** ("estimado al corte del …"). No es un nivel en vivo: la app solo sabe
  cuánto se vendió cuando se cierra un corte.
- **Estado** (Crítico / Medio / Óptimo) = el **peor** entre dos criterios:
  - Porcentaje: Crítico ≤ 20 %, Medio ≤ 50 %, Óptimo > 50 %.
  - Autonomía en días = nivel estimado ÷ promedio diario de galones vendidos en los **últimos 7 días con cortes
    cerrados**: Crítico < 2 días, Medio < 5 días, Óptimo ≥ 5 días.
- Sucursal **sin 7 días de historial**: el estado usa solo el porcentaje y la pantalla indica que la autonomía
  aún no está disponible.
- Gerente de Sucursal ve sus 3 tanques (nivel, %, estado, días de autonomía). Gerente General ve todos, con los
  Críticos destacados arriba.
- Alertas **solo visuales** (colores y etiquetas), sin notificaciones push por ahora.
- Los umbrales (20 %, 50 %, 2 días, 5 días, 7 días) los propuso el asistente; no salen de ninguna norma.
  Deben quedar como constantes fáciles de cambiar.

---

## 6. Usuarios, roles y acceso (Supabase Auth) — CERRADO

- Roles: **Gerente General** y **Gerente de Sucursal**. Los empleados no tienen usuario.
- Acceso con correo y contraseña por **Supabase Auth**; la app nunca guarda contraseñas.
- El **primer Gerente General se crea a mano** en Supabase. Desde ahí, **cualquier Gerente General puede crear
  más Gerentes Generales y Gerentes de Sucursal** desde la app.
- Crear usuarios y restablecer contraseñas requiere la clave de administrador de Supabase, que **no puede ir
  en la app**: lo hace una **Edge Function** que verifica que quien llama es Gerente General.
- Alta: nombre, correo, **contraseña temporal** y sucursal (solo para Gerente de Sucursal).
  En el primer inicio de sesión la app **obliga a cambiarla** (`debe_cambiar_password`).
- **Olvidé mi contraseña** en el login: se envía un **código de 6 dígitos por correo** que se escribe en la app
  y luego se define la nueva contraseña. (Supabase lo soporta editando la plantilla "Reset password" para
  incluir `{{ .Token }}` y verificando el código en la app.) El Gerente General también puede restablecer
  contraseñas como respaldo.
  ⚠ **Requisito**: el servidor de correo por defecto de Supabase solo entrega a direcciones del equipo del
  proyecto y tiene un límite de mensajes por hora; para correos de cualquier gerente hace falta un **SMTP propio**.
- **Un solo Gerente de Sucursal activo por sucursal** (lo impone la BD con un índice único parcial).
- Los usuarios se **desactivan, nunca se borran**; un desactivado no puede iniciar sesión y los cortes que
  cerró conservan su nombre.
- **Seguridad en la BD (RLS)**: el Gerente de Sucursal solo ve y modifica datos de **su** sucursal; el Gerente
  General ve todo. Aunque alguien modifique la app, la BD rechaza el acceso.
- Validaciones: correo con formato válido; contraseña de al menos 8 caracteres.
- No se puede desactivar al **último Gerente General activo** ni a uno mismo (evita quedar sin acceso).
- **Correo**: se configura un **SMTP propio (Gmail con contraseña de aplicación) para pruebas**. Con SMTP propio
  Supabase envía a cualquier dirección: **no hace falta** agregar a los usuarios como miembros del equipo.
  Credenciales las configura el usuario en el panel de Supabase, nunca en el repo ni en el chat.

| Tabla | Campos clave |
|---|---|
| `perfiles` | id (= auth.users.id), nombre, rol, sucursal_id (null para Gerente General), activo, debe_cambiar_password |

---

## 7. Dashboards y pantallas — CERRADO

**Dashboard del Gerente General**
- Filtros: **Todas las sucursales** o una específica; periodo **Hoy / 7 días / 30 días / personalizado**.
- Por combustible (Súper, Regular, Diésel): galones vendidos, ingreso USD (galones × precio del corte),
  compras (gal) y pérdidas (gal). Totales consolidados.
- Gráfico de tendencia de galones vendidos por día; ranking de sucursales por ventas.
- Tanques en estado Crítico destacados; sucursales **sin corte cerrado hoy**; cuántos cortes del periodo
  tuvieron diferencia en el cuadre.
- **Las métricas cuentan solo cortes cerrados** (las ventas solo se conocen al cerrar). Se muestra de cuántos
  cortes salen los datos ("Datos de 1 de 2 cortes de hoy"); sin cortes cerrados = en cero con la etiqueta
  "Sin cortes cerrados hoy". Compras y pérdidas también se suman al dashboard al cerrar el corte; mientras
  tanto solo afectan el nivel estimado del tanque.
- **Indicadores obligatorios en UI**: (a) cuando una cifra sale en cero porque no hay cortes cerrados, texto
  explicativo "Sin cortes cerrados hoy" (no son ventas en cero reales); (b) en el nivel estimado de cada tanque,
  indicar que **sí** lo afectan las compras y pérdidas del corte en curso ("Incluye N compras y M pérdidas
  registradas en el corte en curso").

**Detalle de sucursal (Gerente General, solo lectura)**: lo mismo que ve el gerente de esa sucursal, más su
gerente asignado y sus precios.

**Dashboard del Gerente de Sucursal**: los 3 tanques (nivel, %, estado, días de autonomía); el corte en curso
con acciones (registrar compra, registrar pérdida, continuar captura); resumen de lo vendido hoy en cortes cerrados.

**Captura del corte** (flujo de las 6 bombas):
1. Registro **bomba por bomba** (3 lecturas por bomba + cambio de medidor si aplica). Cada bomba se guarda
   como **borrador editable** hasta cerrar; progreso visible "N de 6 bombas".
2. Captura del nivel medido de los 3 tanques.
3. **Resumen consolidado** (con el cuadre) antes de cerrar.
4. "Cerrar corte": solo se activa con las 6 bombas y los 3 niveles completos. Al cerrar, queda bloqueado.

**Historial de cortes** (ambos roles; el Gerente de Sucursal solo su sucursal). Cada corte abre su reporte:
las 6 bombas (inicial, final, galones, USD), consolidado por combustible, compras y pérdidas, cuadre (nivel
teórico, medido, diferencia), marca "Ajustado" y marca "Cambio de medidor" si aplican.

---

## 8. Empleados y turnos — CERRADO

- Empleados = **registro de personal sin usuario** en la app. Lo administra el **Gerente de Sucursal** (agrega,
  edita, desactiva); el **Gerente General solo consulta**.
- Datos: nombre completo, **cargo** (lista fija: Despachador, Cajero, Supervisor, Mantenimiento, Otro), teléfono
  (opcional), fecha de ingreso (opcional), activo/inactivo. **Sin DUI** ni otro documento (dato sensible innecesario).
  Se desactivan, nunca se borran.
- **Turnos por sucursal**: nombre, hora de inicio, hora de fin. Un fin menor que el inicio significa "al día
  siguiente" (turno que cruza la medianoche, ej. 22:00–06:00). Se permiten **solapes y huecos**; solo se exige
  inicio ≠ fin. Los turnos son **solo informativos**: no afectan cortes, pagos ni gestiones.
- **Asignación**: cada empleado tiene **un turno y los días de la semana** que trabaja. Sin rotaciones.
- Vistas: **"Quién trabaja ahora"** (según día y hora actuales, empleados activos cuyo turno incluye este momento)
  y **horario semanal** (turnos × días).
- No incluye: ausencias, vacaciones, pagos, asignación de empleado a bomba.

| Tabla | Campos clave |
|---|---|
| `empleados` | id, sucursal_id, nombre, cargo, telefono (null), fecha_ingreso (null), activo |
| `turnos` | id, sucursal_id, nombre, hora_inicio, hora_fin |
| `asignaciones_turno` | empleado_id, turno_id, dias (lunes…domingo) |

---

## Temas que faltan por conversar

9. Tienda/lubricantes y otros servicios (EN CURSO, ver abajo) · 10. Diagrama de base de datos.

---

## 9. Tienda, lubricantes y otros servicios — CERRADO

### Acordado

- **Catálogo único de la franquicia**, administrado por el Gerente General: nombre, categoría (Lubricantes,
  Bebidas, Snacks, Otros productos, Servicios), tipo (**producto** con inventario / **servicio** sin inventario),
  precio de venta final en USD, activo. Se desactivan, nunca se borran. Solo el Gerente General cambia precios.
- **Inventario por sucursal** (solo productos): stock actual y **stock mínimo**; indicador "Stock bajo".
  **Entradas de mercadería** (artículo, cantidad, proveedor opcional) y **bajas** (vencido/dañado, cantidad,
  motivo) como líneas en el corte en curso, registradas por el Gerente de Sucursal.
- **Bloque aparte "Tienda y servicios"** en el dashboard del Gerente General, sin mezclar con combustible.
- En vez de "opcional", cada sucursal tiene un **indicador `tiene_tienda`** (lo fija el Gerente General en el
  alta/edición de la sucursal). Solo si está activo la sucursal hace corte de tienda y ve el módulo.

### POS con rol Cajero — ACORDADO

- El POS cobra **solo tienda y servicios**. El combustible sigue por medidor y tanque.
- **Cajero** = rol con usuario. Lo crea el **Gerente de Sucursal** de su propia sucursal (misma Edge Function,
  contraseña temporal con cambio obligatorio). Varios por sucursal. Solo ve el POS de su sucursal (no combustible,
  cortes ni dashboards).
- Los cajeros usan **correo real**, con el **mismo flujo que los gerentes** (incluido el código por correo, vía
  el SMTP propio del tema 6); su Gerente de Sucursal también puede restablecerles la contraseña.
- **Anulaciones**: solo el **Gerente de Sucursal**, con **motivo obligatorio**, y **solo mientras la caja de esa
  venta siga abierta** (después del cierre de caja la venta es definitiva; devoluciones posteriores fuera de
  alcance). La venta anulada se conserva marcada "Anulada" (quién, cuándo, por qué); revierte stock, ingreso y
  efectivo esperado. El Gerente General ve el conteo de anulaciones por sucursal.
- **Cierre forzado de caja**: si un cajero deja su caja abierta, el Gerente de Sucursal puede cerrarla (cuenta él
  el efectivo, motivo obligatorio); queda marcada "cierre forzado" en el reporte.
- **Venta** = ticket: líneas (artículo, cantidad, precio unitario del catálogo, subtotal), total, método
  (**Efectivo** / **Tarjeta simulada**), recibido y vuelto (solo efectivo). Botón **Pagar** con animación que
  **simula** el pago: no se procesa ningún pago real ni se piden datos de tarjeta. Total y vuelto los calcula el
  **servidor** con los precios del catálogo. El stock baja con cada venta; no se vende más que el stock.
- **Cierre de caja** (el arqueo; en la UI se llama "Cierre de caja" para no confundirlo con el "corte" de la
  sucursal): **sesión de caja** por cajero (apertura con fondo inicial en efectivo; cierre con efectivo
  contado). Esperado = fondo inicial + ventas en efectivo; la diferencia es un **indicador** faltante/sobrante.
  Un cajero tiene una sola sesión abierta; pueden coexistir cajas de varios cajeros.
- **El corte no se puede cerrar con cajas abiertas** (así cada caja cae entera dentro de un corte).
- Los **turnos no gobiernan la caja**: la responsabilidad del dinero es de la sesión de caja de cada cajero.

### Descarga errónea y vaciado de tanque — ACORDADO

Flujo desde el tanque afectado, solo para el **Gerente de Sucursal**, dentro del corte en curso. Dos motivos:

1. **Descarga de combustible equivocado** (ej. la cisterna trae Diésel y se descarga en el tanque de Regular).
   Captura: combustible que traía la cisterna (distinto al del tanque), galones descargados por error, **nivel
   medido con varilla tras la descarga**, nota. El sistema genera:
   - **Pérdida "contaminación"** del combustible del tanque por `nivel medido − galones descargados`.
   - **Compra + pérdida "contaminación"** del combustible erróneo por los galones descargados (neto cero en su
     tanque, pero queda constancia de que se compró y se perdió). Esas líneas **no se validan contra el espacio
     libre** de ese tanque, porque nunca entraron físicamente a él.
   - El tanque afectado queda en **0** hasta que entre una compra nueva.
2. **Otra contaminación o mantenimiento** (agua en el tanque, mantenimiento): captura nivel medido y nota; todo
   se registra como pérdida "contaminación"; el tanque queda en 0.

- Se usa el **nivel medido**, no el estimado (el estimado no incluye lo vendido desde el último corte); así el
  cuadre queda correcto. Tras el vaciado el nivel estimado muestra 0 (el vaciado actúa como nueva base de medición).
- **No existe un botón "vaciar" suelto sin motivo** (sería una forma fácil de esconder un faltante).
- El Gerente General ve los eventos de contaminación por sucursal.

| Tabla | Campos clave |
|---|---|
| `vaciados_tanque` | id, corte_id, tanque_id, motivo, combustible_erroneo (null), galones_erroneos (null), nivel_medido, nota, registrado_por, creado_en |

### Propuesta original del usuario (referencia)

- Un **rol Cajero con usuario** registra las ventas en una pantalla tipo POS (artículo, cantidad, precio,
  recibido, vuelto, botón Pagar con animación que **simula** el pago), en lugar del resumen de unidades por corte.
- Las ventas deben **cuadrar con el dinero en caja** (arqueo).
- El ingeniero quiere esta misma app **también en web**.
- (Resuelto: ver arriba. Web + iOS con las mismas funcionalidades, entrega completa.)
