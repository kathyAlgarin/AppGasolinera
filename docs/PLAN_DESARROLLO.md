# PLAN DE DESARROLLO

Puente entre el negocio (`docs/FLUJO.md`), la base de datos (`docs/BASE_DE_DATOS.md`) y las pantallas
(`FIGMA_INTERACCIONES.md`). **Orden acordado: primero la app iOS completa y, cuando esté lista, la web.**
Todo se trabaja en **local**: no hay despliegue, ni `git push`, ni commits hasta que se pidan.

---

## 1. Decisiones

| Tema | Decisión |
|---|---|
| Plataformas | **iOS** (SwiftUI, MVVM) primero; **web** después con **React + Node.js**. Mismas funcionalidades en ambas. |
| Backend | Supabase `app_gasolinera` (ya aplicado y probado). Las apps llaman a **funciones** y leen **vistas**; no calculan nada. |
| Despliegue | Ninguno por ahora: todo local. |
| iOS mínimo | iOS 17.2, Xcode 15+ (lo que ya tiene el proyecto). |
| Cliente Supabase en iOS | Paquete `supabase-swift` (Swift Package Manager). **Verificar su API contra la documentación al implementar**; este plan no fija firmas de métodos. |
| Claves en la app | Solo la clave **publishable** y la URL del proyecto. Nunca la secreta ni contraseñas en el código. |

## 2. Cómo se verifica (límite importante)

El código se escribe en **Windows**, donde **no se puede compilar ni ejecutar SwiftUI** (Xcode solo existe en Mac).
Por eso:

- Yo escribo el código y **no puedo afirmar que compila**. Lo compila y lo prueba Katherinne en un Mac con Xcode.
- Cada fase termina con una lista **"Qué probar"**. Los errores de compilación o de ejecución se pegan tal cual y se corrigen.
- Las reglas de negocio ya están probadas en la base de datos; en la app se prueba que **se llame bien y se muestre bien**.
- Para que el trabajo avance en pasos pequeños y comprobables, cada fase es corta y deja la app **ejecutable**.

## 3. Arquitectura iOS

```
App76/
├── Core/          Configuración (URL y clave publishable), cliente Supabase, errores, formateadores, validadores
├── Models/        Estructuras Codable que reflejan tablas, vistas y respuestas de funciones
├── Services/      Un servicio por dominio, detrás de un protocolo (AuthService, SucursalesService, CortesService, …)
├── ViewModels/    Un ViewModel por pantalla; solo hablan con protocolos de servicio (se pueden probar con falsos)
├── Views/         Pantallas SwiftUI por rol: Auth, GeneralManager, BranchManager, Cashier, Shared
└── Theme/         Colores y estilos
```

Reglas de código:

- **MVVM estricto**: la vista no llama a Supabase; el ViewModel no importa SwiftUI.
- Los servicios devuelven modelos o lanzan un error con el **mensaje en español que ya manda el servidor**; la app lo muestra tal cual.
- **Decimales**: galones y dólares se leen como `Decimal`. Solo se **muestran** (formateados); nunca se calculan totales, cuadres ni
  precios en el cliente. La excepción es el vuelto que se previsualiza en el POS, que el servidor recalcula al registrar la venta.
- **Zona horaria**: las fechas "del día" y los filtros usan `America/El_Salvador`; `fecha_operativa` ya llega como fecha.
- **Campos numéricos**: un único componente reutilizable que no acepta letras, signos negativos ni más de 2 decimales
  (los enteros, como las cantidades de tienda, no aceptan decimales). Se valida en la app y de todos modos en el servidor.
- **Sesión**: la guarda el SDK. Al iniciar se lee `perfiles` (rol, sucursal, `activo`, `debe_cambiar_password`) y se enruta por rol.
  Si `debe_cambiar_password` es verdadero, la única pantalla posible es el cambio de contraseña; al terminar se llama a `marcar_password_cambiada`.
- **Estados de pantalla** en todas: cargando, vacío (con texto útil), error (con reintento), contenido.
- **Información "?"**: componente de ayuda reutilizable para las explicaciones acordadas (captura manual, bomba opcional, autonomía, etc.).

El código actual de la app es una **demo anterior** (datos en memoria, litros, "premium", cortes Apertura/Cierre) y **se reescribe**.
En la fase 0 se revisa qué de lo visual se puede reutilizar (`Theme`, `ViewModel` base, componentes como tarjetas y filas de tanque);
modelos, servicios, `AppRepository` y `SalesCalculator` se eliminan.

## 4. Mapa de pantallas ↔ base de datos

### Todos los roles
| Pantalla | Usa |
|---|---|
| Login, sesión | Supabase Auth; lectura de `perfiles` |
| Olvidé mi contraseña (código) | Supabase Auth (código de 6 dígitos por correo; **requiere el SMTP**) |
| Cambio obligatorio de contraseña | Auth + `marcar_password_cambiada()` |
| Perfil | `perfiles`; Auth (cambiar contraseña, cerrar sesión) |

### Gerente General
| Pantalla | Lee | Escribe (función) |
|---|---|---|
| Panel (filtros sucursal y periodo) | `v_dashboard_combustible`, `v_estado_tanque`, `cortes`, `v_tienda_ingresos`, `v_tienda_anulaciones`, `v_tienda_cajas`, `v_stock_bajo` | — |
| Detalle de combustible / de sucursal | `v_resumen_corte`, `v_estado_tanque`, `precios`, `perdidas_combustible`, `vaciados_tanque`, `perfiles` | — |
| Reporte de corte | `v_resumen_corte`, `v_lecturas_efectivas`, `compras_combustible`, `perdidas_combustible`, `cambios_medidor`, `ajustes_lectura` | `registrar_ajuste` |
| Sucursales | `sucursales`, `tanques` | `crear_sucursal`, `editar_sucursal`, `cambiar_estado_sucursal`, `configurar_tienda` |
| Precios | `precios` | `fijar_precio` (una, varias o todas las sucursales) |
| Usuarios | `perfiles` | Edge Function `gestionar-usuarios` (`crear`, `restablecer_password`, `cambiar_estado`) |
| Catálogo | `articulos` | `insert` / `update` sobre `articulos` |
| Personal y turnos (consulta) | `empleados`, `turnos`, `asignaciones_turno` | `empleados_en_turno` (lectura) |

### Gerente de Sucursal
| Pantalla | Lee | Escribe (función) |
|---|---|---|
| Inicio | `v_estado_tanque`, `cortes`, `v_dashboard_combustible` | — |
| Bombas del corte | `bombas`, `mangueras`, `v_lecturas_efectivas` | `guardar_lecturas_bomba`, `registrar_cambio_medidor`, `eliminar_cambio_medidor` |
| Compras | `compras_combustible` | `registrar_compra`, `editar_compra`, `eliminar_compra` |
| Pérdidas | `perdidas_combustible` | `registrar_perdida`, `editar_perdida`, `eliminar_perdida` |
| Descarga errónea y vaciado | `vaciados_tanque` | `registrar_vaciado` |
| Niveles, resumen y cierre | `v_nivel_tanque_estimado`, `v_cuadre_tanque_corte` | `cerrar_corte` |
| Historial y reporte | `cortes`, `v_resumen_corte` | — |
| Tienda: inventario, entradas, bajas | `inventario_sucursal`, `articulos`, `entradas_inventario`, `bajas_inventario` | `registrar_entrada`, `eliminar_entrada`, `registrar_baja`, `eliminar_baja` |
| Ventas, anulaciones y cajas | `ventas`, `venta_lineas`, `sesiones_caja`, `v_tienda_cajas` | `anular_venta`, `cerrar_caja_forzado` |
| Personal | `empleados`, `turnos`, `asignaciones_turno` | `insert`/`update` directos; `empleados_en_turno` |
| Cajeros | `perfiles` | Edge Function `gestionar-usuarios` (solo cajeros de su sucursal) |

### Cajero
| Pantalla | Lee | Escribe (función) |
|---|---|---|
| Caja / abrir | `sesiones_caja` | `abrir_caja` |
| POS | `articulos` (activos), `inventario_sucursal` | `registrar_venta` |
| Mis ventas | `ventas`, `venta_lineas` | — |
| Cerrar caja | `sesiones_caja` | `cerrar_caja` |

## 5. Fases de la app iOS

Cada fase deja la app ejecutable. "Listo cuando" es el criterio de aceptación; "Qué probar" lo hace Katherinne en el Mac.

### Fase 0 · Preparación (código escrito, pendiente de compilar en el Mac)
- Sin paquete local: el código vive directo en `App76/` (MVVM). Los archivos nuevos se registran en el proyecto con
  `python3 tools/sincronizar_proyecto.py` (cierra Xcode antes; también agrega `supabase-swift` ≥ 2.0.0).
- Hecho: `Core/` (Configuracion, ClienteSupabase, ErrorApp, Formateadores), `Services/ConexionService`, `ArranqueViewModel`, `RootView`.
  Se borró la demo anterior; se conservaron `Theme/Colors`, `SummaryCard` y `ActionCard`.
- **Listo cuando**: el proyecto compila y arranca en una pantalla vacía conectada al cliente.
- **Qué probar**: pegar la clave `sb_publishable_…` en `Core/Configuracion.swift`; compila; al abrir dice «Conectado al servidor».

### Fase 1 · Acceso y navegación por rol
- Login, sesión persistente, enrutamiento por rol, cambio obligatorio de contraseña, "Olvidé mi contraseña" (código), perfil y cerrar sesión.
- **Listo cuando**: Katherinne inicia sesión y ve el esqueleto de pestañas del Gerente General; un usuario inactivo no entra.
- **Qué probar**: login correcto e incorrecto; cerrar sesión y volver a abrir la app (sesión persistente); el código por correo (después de configurar el SMTP).

### Fase 2 · Gerente General: sucursales, usuarios, precios y catálogo
- Sucursales (crear con tanques, editar, activar/desactivar, tienda), precios (individual o a todas), usuarios (crear, restablecer, activar), catálogo.
- **Listo cuando**: se crea una sucursal con 3 tanques y se ve su 6×3; se crea un Gerente de Sucursal; se fijan los 3 precios.
- **Qué probar**: la **Edge Function** con un caso real (su camino de éxito todavía no se ha ejercitado); errores como un segundo gerente en la misma sucursal.

### Fase 3 · Gerente de Sucursal: corte completo
- Inicio con tanques; corte en curso: bombas (lecturas, primer corte con inicial y final, cambio de medidor), compras, pérdidas, descarga errónea y vaciado,
  niveles medidos, resumen con cuadre, cierre; historial y reporte; ajuste del Gerente General.
- **Listo cuando**: se cierra un corte completo y el siguiente queda en curso con las lecturas iniciales derivadas.
- **Qué probar**: lecturas inválidas, cierre incompleto, cuadre con diferencia, vaciado, ajuste.

### Fase 4 · Dashboards
- Panel del Gerente General (filtros, tendencia, ranking, tanques críticos, sucursales sin corte, mensajes "Sin cortes cerrados hoy"), detalle por sucursal y combustible.
- **Listo cuando**: las cifras coinciden con los reportes de corte y se explican los ceros.

### Fase 5 · Personal y turnos
- Empleados, turnos (que cruzan la medianoche, con solapes), asignaciones, horario semanal, "Quién trabaja ahora".

### Fase 6 · Tienda, caja y ventas
- Inventario, entradas y bajas (Gerente de Sucursal); POS del Cajero con carrito, cobro, vuelto y **animación de pago simulado**; cierre de caja;
  anulaciones; cierre forzado; bloque "Tienda y servicios" en los dashboards; crear cajeros.
- **Listo cuando**: se vende, se anula, se cierra una caja con diferencia y el corte se puede cerrar solo sin cajas abiertas.

### Fase 7 · Pulido
- Validaciones en todos los campos, estados vacíos y de error, accesibilidad básica, revisión contra `FIGMA_INTERACCIONES.md`, actualización del prototipo en Figma.

## 6. Web (después de la app)

Cuando la app esté lista: **React + Node.js** (herramientas de Node para construir y ejecutar), **todo en local**. Hablará con el **mismo** Supabase usando
`supabase-js`, con las mismas funciones y vistas, de modo que las reglas se comportan igual que en iOS. El orden de fases se repite.
La clave que lleve será solo la publishable. Si el ingeniero espera además un servidor propio en Node.js, se define entonces: hoy el backend es Supabase.

## 7. Pendientes y riesgos

| Pendiente | Quién | Nota |
|---|---|---|
| Apagar "Verify JWT with legacy secret" en la Edge Function | Katherinne | El proyecto firma sesiones con ES256; con la opción encendida pueden rechazarse. La función ya verifica la sesión por su cuenta. |
| SMTP de Gmail + plantilla "Reset password" con `{{ .Token }}` | Katherinne | Necesario para "Olvidé mi contraseña" (fase 1). |
| Camino de éxito de `gestionar-usuarios` sin ejercitar | Se prueba en la fase 2 | Solo se verificaron los rechazos. |
| Compilación y ejecución en iOS | Katherinne en Mac | No se puede hacer desde Windows. |
| Prototipo de Figma desactualizado | Se actualiza al final (fase 7) | `FIGMA_INTERACCIONES.md` ya describe el diseño nuevo. |
| Decimales `numeric` de Postgres en JSON | Revisar en la fase 0 | Mostrar siempre formateados a 2 decimales; no operar en el cliente. |
