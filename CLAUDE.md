# Sistema de gestión de franquicia de gasolineras (El Salvador)

App iOS (SwiftUI, MVVM) **y** versión web (tecnología por definir), ambas con las mismas funcionalidades, sobre un
mismo backend **Supabase**. Se entrega **completo**, no por fases. Requisitos originales: el `.md` del Laboratorio 22
(Gerente General + Gerente de Sucursal; los puntos "pospuestos al Parcial 2" **también entran**).

## Dónde está cada cosa (leer en este orden)

1. `docs/FLUJO.md` — **fuente de verdad del negocio**: decisiones cerradas por tema (sucursal, corte, compras y pérdidas,
   precios, tanques y alertas, usuarios, dashboards, empleados y turnos, tienda y POS, vaciado de tanque).
2. `docs/BASE_DE_DATOS.md` — esquema, funciones del servidor, vistas, permisos (RLS), contrato de la Edge Function de
   usuarios y la verificación realizada.
3. `docs/PLAN_DESARROLLO.md` — arquitectura iOS, mapa pantallas ↔ funciones/vistas de la BD, fases y pendientes.
4. `FIGMA_INTERACCIONES.md` — pantallas e interacciones del diseño nuevo (el archivo de Figma aún es del diseño anterior).
5. `supabase/migrations/` — SQL aplicado al proyecto. `supabase/functions/gestionar-usuarios/` — Edge Function.
6. `docs/PANTALLAS.md` (y `docs/PANTALLAS.html`, una sola página) — guía de cada pantalla con capturas (`docs/capturas/`) y qué hace/cómo funciona; videos por rol en `docs/video/`. Se regenera con `python3 tools/generar_guia_pantallas.py`.

Si algo del código contradice `docs/FLUJO.md`, manda `docs/FLUJO.md`. Una decisión ya cerrada ahí no se reabre sin preguntar.

## Supabase

- Proyecto: `app_gasolinera`, ref `kpzdedcztufqwsqoywdp`, organización "kathyAlgarin Personal".
  **No tocar** los otros proyectos de esa cuenta (BiteBoss, PracticaDMAW).
- Las apps solo llaman a **funciones** (RPC) y leen **vistas**; las reglas viven en la base de datos. Las apps no calculan
  totales, cuadres ni precios. Los usuarios se crean/administran con la Edge Function `gestionar-usuarios`.
- Las apps solo llevan la clave **publishable**. Nunca la clave secreta/service_role, ni contraseñas, en el repo.
- Usuarios: Gerente General (Katherinne, `katerin.algarin@gmail.com`), Gerente de Sucursal, Cajero.

## Reglas del dominio que no se deben romper

- Unidad: **galones**; dinero en **USD**; combustibles `super`, `regular`, `diesel` (en la UI: Súper, Regular, Diésel).
- 6 bombas × 3 mangueras por sucursal; 1 tanque por combustible. Captura manual de lecturas y niveles.
- Un corte cerrado es inmutable; nada se borra (se desactiva o se anula). Ajustes solo del Gerente General.
- Nombres de tablas, columnas y mensajes: **español**.
- Toda captura numérica se valida: sin letras, negativos, vacíos ni más de 2 decimales.

## Forma de trabajar

- Todo en **local**: sin `git push`, PR ni merge hasta que se pida. No commitear sin que se pida.
- Cambios en la base de datos = nueva migración en `supabase/migrations/` (nunca editar las ya aplicadas). Se aplican solo
  con confirmación, y se verifican con pruebas reales que se deshacen (transacción terminada en error), sin dejar datos.
- "Verificado" solo si se ejercitó el comportamiento real; si no, decir "no lo ejercité".
- Credenciales: nunca se escriben ni se piden en el chat; las configura la usuaria en el panel de Supabase.

## Estado actual

- Base de datos: **aplicada y probada** (14 migraciones; las 2 últimas, `resumen_previo_corte` y `fijar_stock_minimo`, se aplicaron el 2026-10-04 con confirmación
  de la usuaria, tras probarlas en una transacción deshecha: la vista previa coincide exactamente con el cierre real).
- Edge Function `gestionar-usuarios`: **desplegada y con «Verify JWT with legacy secret» apagado (verificado)**. Camino de éxito **probado el 2026-10-04** con usuarios
  temporales: crear (201), correo repetido (409), contraseña corta (400), restablecer, desactivar (bloquea el inicio de sesión), reactivar, no actuar sobre uno mismo,
  y el usuario creado entra con la temporal, cambia su contraseña y `marcar_password_cambiada` apaga la bandera. Correo por código (SMTP): sin probar.
- Credenciales locales de pruebas en `.env` (ignorado por git; incluye la clave secreta, **solo para pruebas desde esta máquina**, nunca en la app). La clave secreta se
  compartió en un chat: **conviene rotarla** en Supabase (Settings → API Keys) cuando terminen las pruebas.
- Los usuarios temporales de las pruebas se eliminaron (a pedido de la usuaria, en una operación atómica que reactiva la protección `perfiles_no_borrar` al terminar); solo queda su usuario real.
- **Datos de ejemplo cargados el 2026-10-04** a pedido de la usuaria (3 sucursales «… (ejemplo)»: Centro y Santa Ana con tienda, Aeropuerto sin tienda; 5 días de historial con
  27 cortes cerrados, ventas, cajas, compras, pérdidas, un vaciado, un cambio de medidor y un ajuste por sucursal con extras; personal y turnos). Usuarios de ejemplo
  `gerente.centro|aeropuerto|santaana@example.com` y `cajero.centro|santaana@example.com`, con contraseñas temporales en `.env` (`EJEMPLO_*`; la app obliga a cambiarlas).
  Son datos reales de la BD: **no se pueden borrar** (cortes y ventas son inmutables; las sucursales solo se desactivan). Para que el historial tenga varios días se reubicaron
  las fechas de los cortes desactivando y reactivando las protecciones dentro de la misma transacción (verificado: quedan todas activas). La sucursal «76 centro» es de la usuaria.
- La Edge Function ahora también tiene `cambiar_correo` (versión 2, probada: correo nuevo entra, el viejo no, correo repetido 409, uno mismo 400).
- **App iOS: fases 0–7 escritas, compiladas (`xcodebuild`) y recorridas en el simulador.** Contra el servidor real se probó por HTTP (login, RLS, vistas, Edge Function,
  formas de consulta de PostgREST) pero **la app misma nunca inició sesión real** (el simulador no recibe texto tecleado desde la herramienta): falta el recorrido manual con la cuenta real.
  La lógica está cubierta por `tools/correr_pruebas.sh` (480 verificaciones, incluida la decodificación de JSON real del servidor).
- Estructura: `App76/{Core,Models,Services,ViewModels,Views,Theme}`. Los ViewModels solo dependen de protocolos de `Services/Protocolo*.swift`
  (se prueban con falsos en `Pruebas/`); las vistas arman cada ViewModel con `Servicios.<x>` (`Services/Servicios.swift`).
- Archivos obsoletos de la fase 0 que se pueden borrar a mano: `App76/ViewModels/ArranqueViewModel.swift` y `App76/Services/ConexionService.swift`
  (ya no se usan; luego correr `python3 tools/sincronizar_proyecto.py`).
- **Entorno de trabajo ahora es macOS con Xcode**: sí se puede compilar y correr el simulador. Aun así, afirmar «funciona» solo de lo ejercitado.
- Pendiente: probar con la cuenta real, apagar «Verify JWT with legacy secret» en la Edge Function,
  configurar el SMTP, actualizar el prototipo de Figma y la **versión web** (React + Node.js, después de la app).
- Decidido: **primero la app iOS completa, después la web**, **todo en local, sin despliegue**.
