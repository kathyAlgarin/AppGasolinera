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

## 2. Cómo se verifica

Se trabajó en **macOS con Xcode**, así que el código **sí se compila y se ejecuta** (antes se escribía en Windows y no podía). Hay tres niveles:

1. **Compilación**: `xcodebuild -project App76.xcodeproj -scheme App76 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`.
2. **Pruebas de lógica** (`tools/correr_pruebas.sh`, sin simulador): modelos, validadores, fechas y **todos los ViewModels** con servicios falsos,
   más la decodificación de **JSON real** del servidor (`Pruebas/datos_reales_vistas.json`, capturado de un escenario completo en una transacción
   deshecha). Hoy: 480 verificaciones.
3. **Simulador**: se recorrieron las pantallas con datos de ejemplo en una versión anterior (el modo demo se retiró; la app queda conectada solo al backend).

**Lo que no se ha ejercitado**: nada de la app contra el servidor real con una **sesión** (login, llamadas RPC de cada pantalla, Edge Function,
código por correo). No hay credenciales en el entorno de trabajo y no se piden ni se crean cuentas. Eso lo prueba Katherinne (lista «Qué probar»).

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

### Fase 0 · Preparación
**Estado: hecha.** Compila; el proyecto registra los archivos con `tools/sincronizar_proyecto.py`; el cliente Supabase usa decodificador `snake_case`.
- Sin paquete local: el código vive directo en `App76/` (MVVM). Los archivos nuevos se registran en el proyecto con
  `python3 tools/sincronizar_proyecto.py` (cierra Xcode antes; también agrega `supabase-swift` ≥ 2.0.0).
- Hecho: `Core/` (Configuracion, ClienteSupabase, ErrorApp, Formateadores), `Services/ConexionService`, `ArranqueViewModel`, `RootView`.
  Se borró la demo anterior; se conservaron `Theme/Colors`, `SummaryCard` y `ActionCard`.
- **Listo cuando**: el proyecto compila y arranca en una pantalla vacía conectada al cliente.
- **Qué probar**: pegar la clave `sb_publishable_…` en `Core/Configuracion.swift`; compila; al abrir dice «Conectado al servidor».

### Fase 1 · Acceso y navegación por rol
**Estado: escrita y probada con falsos y por HTTP contra el servidor; falta el recorrido manual con sesión real.** Incluye cambio obligatorio de contraseña y recuperación por código (3 pasos).
- Login, sesión persistente, enrutamiento por rol, cambio obligatorio de contraseña, "Olvidé mi contraseña" (código), perfil y cerrar sesión.
- **Listo cuando**: Katherinne inicia sesión y ve el esqueleto de pestañas del Gerente General; un usuario inactivo no entra.
- **Qué probar**: login correcto e incorrecto; cerrar sesión y volver a abrir la app (sesión persistente); el código por correo (después de configurar el SMTP).

### Fase 2 · Gerente General: sucursales, usuarios, precios y catálogo
**Estado: escrita; la Edge Function sigue sin ejercitar.**
- Sucursales (crear con tanques, editar, activar/desactivar, tienda), precios (individual o a todas), usuarios (crear, restablecer, activar), catálogo.
- **Listo cuando**: se crea una sucursal con 3 tanques y se ve su 6×3; se crea un Gerente de Sucursal; se fijan los 3 precios.
- **Qué probar**: la **Edge Function** con un caso real (su camino de éxito todavía no se ha ejercitado); errores como un segundo gerente en la misma sucursal.

### Fase 3 · Gerente de Sucursal: corte completo
**Estado: escrita; «Resumen y cierre» usa la función `resumen_previo_corte` (migración aplicada).** El borrador de niveles se guarda en el teléfono hasta cerrar.
- Inicio con tanques; corte en curso: bombas (lecturas, primer corte con inicial y final, cambio de medidor), compras, pérdidas, descarga errónea y vaciado,
  niveles medidos, resumen con cuadre, cierre; historial y reporte; ajuste del Gerente General.
- **Listo cuando**: se cierra un corte completo y el siguiente queda en curso con las lecturas iniciales derivadas.
- **Qué probar**: lecturas inválidas, cierre incompleto, cuadre con diferencia, vaciado, ajuste.

### Fase 4 · Dashboards
**Estado: escrita** (Panel con Swift Charts, detalle de combustible y de sucursal, pérdidas globales).
- Panel del Gerente General (filtros, tendencia, ranking, tanques críticos, sucursales sin corte, mensajes "Sin cortes cerrados hoy"), detalle por sucursal y combustible.
- **Listo cuando**: las cifras coinciden con los reportes de corte y se explican los ceros.

### Fase 5 · Personal y turnos
**Estado: escrita** (empleados, turnos, horario semanal, «Quién trabaja ahora»; el Gerente General solo consulta).
- Empleados, turnos (que cruzan la medianoche, con solapes), asignaciones, horario semanal, "Quién trabaja ahora".

### Fase 6 · Tienda, caja y ventas
**Estado: escrita; el stock mínimo usa `fijar_stock_minimo` (migración aplicada).** El pago es simulado.
- Inventario, entradas y bajas (Gerente de Sucursal); POS del Cajero con carrito, cobro, vuelto y **animación de pago simulado**; cierre de caja;
  anulaciones; cierre forzado; bloque "Tienda y servicios" en los dashboards; crear cajeros.
- **Listo cuando**: se vende, se anula, se cierra una caja con diferencia y el corte se puede cerrar solo sin cajas abiertas.

### Fase 7 · Pulido
**Estado: parcial.** Hecho: validaciones en todos los campos numéricos y de texto, estados de carga/vacío/error en todas las pantallas, etiquetas de accesibilidad en los botones de icono, revisión contra `FIGMA_INTERACCIONES.md`. Pendiente: probar con Dynamic Type grande y modo oscuro en dispositivo, y actualizar el prototipo de Figma.
- Validaciones en todos los campos, estados vacíos y de error, accesibilidad básica, revisión contra `FIGMA_INTERACCIONES.md`, actualización del prototipo en Figma.

## 6. Web (después de la app)

Cuando la app esté lista: **React + Node.js** (herramientas de Node para construir y ejecutar), **todo en local**. Hablará con el **mismo** Supabase usando
`supabase-js`, con las mismas funciones y vistas, de modo que las reglas se comportan igual que en iOS. El orden de fases se repite.
La clave que lleve será solo la publishable. Si el ingeniero espera además un servidor propio en Node.js, se define entonces: hoy el backend es Supabase.

## 7. Pendientes y riesgos

| Pendiente | Quién | Nota |
|---|---|---|
| Probar la app con la cuenta real | Katherinne | Login, un corte completo, POS, Edge Function (crear usuario). Pegar cualquier error. |
| Apagar «Verify JWT with legacy secret» en la Edge Function | Katherinne | El proyecto firma sesiones con ES256; la función ya verifica la sesión por su cuenta. |
| SMTP de Gmail + plantilla «Reset password» con `{{ .Token }}` | Katherinne | Necesario para «Olvidé mi contraseña». |
| Camino de éxito de `gestionar-usuarios` sin ejercitar | Se prueba al crear el primer usuario | Solo se verificaron los rechazos. |
| Borrar a mano `ArranqueViewModel.swift` y `ConexionService.swift` (fase 0, ya sin uso) y correr el script de sincronización | Katherinne | Un permiso del entorno impidió borrarlos desde la sesión. |
| Prototipo de Figma desactualizado | Al final | `FIGMA_INTERACCIONES.md` ya describe el diseño nuevo. |
| Versión web (React + Node.js) | Después de la app | Mismo Supabase, mismas funciones y vistas. |
| Primer corte de cada sucursal | Operación | Pide lecturas iniciales y finales de las 18 mangueras y si es Matutino o Vespertino. |
