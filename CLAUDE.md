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

- Base de datos: **aplicada y probada**. Edge Function `gestionar-usuarios`: **desplegada, camino de éxito sin probar**
  (necesita una sesión real). Correo (SMTP de Gmail + plantilla con `{{ .Token }}`): lo configura la usuaria.
- **El código de la app iOS actual es una demo anterior** (datos en memoria, litros, "premium", cortes Apertura/Cierre):
  **no coincide con el diseño nuevo** y debe reescribirse sobre Supabase. El `README.md` y `FIGMA_INTERACCIONES.md` también
  están desactualizados respecto a `docs/FLUJO.md`.
- Decidido: **primero la app iOS completa, después la web** (React + Node.js), **todo en local, sin despliegue**.
- **Limitación**: el código se escribe en Windows; **no se puede compilar ni ejecutar SwiftUI aquí**. Nunca afirmar que el código iOS
  compila: lo compila y prueba la usuaria en un Mac y pega los errores.
- La Edge Function debe tener **apagado** "Verify JWT with legacy secret" (el proyecto firma sesiones con ES256); la función ya valida la sesión sola.
