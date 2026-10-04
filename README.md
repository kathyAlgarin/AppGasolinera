# Gasolineras — gestión de franquicia (El Salvador)

Sistema para administrar una franquicia de estaciones de servicio: sucursales con 6 bombas, tanques, cortes de combustible
(Súper, Regular y Diésel), precios, tienda de conveniencia y servicios, personal y turnos. Una **app iOS** (SwiftUI) y, después,
una **versión web** (React + Node.js) con las mismas funcionalidades, sobre un mismo backend **Supabase**.

> **Estado: en desarrollo.** La base de datos está aplicada y probada. La app iOS que hay en el repositorio es una **demo
> anterior** (datos en memoria) que se está reescribiendo sobre Supabase; la versión web aún no existe.
> Ver [`docs/PLAN_DESARROLLO.md`](docs/PLAN_DESARROLLO.md).

## Roles

| Rol | Qué hace |
|---|---|
| **Gerente General** | Dashboard consolidado (país o una sucursal, por periodo); crea sucursales, usuarios, precios y catálogo; consulta cortes, pérdidas, personal y tienda; registra ajustes a cortes. |
| **Gerente de Sucursal** | Registra los **2 cortes diarios** (Matutino y Vespertino) con las lecturas de sus 6 bombas, compras, pérdidas y niveles de tanque; administra personal, turnos, inventario y cajeros de su sucursal. |
| **Cajero** | Cobra en el POS de la tienda, abre y cierra su caja. |

## Cómo funciona (resumen)

- Cada sucursal tiene **6 bombas × 3 mangueras** (18 totalizadores) y **1 tanque por combustible**. Todo en **galones** y **USD**.
- **Captura manual**: el gerente teclea las lecturas de las mangueras y el nivel de los tanques (varilla). La app no se conecta a las bombas.
- **Corte**: cierra un periodo de la sucursal; la lectura final de cada manguera es la inicial del siguiente. No se cierra sin las 6 bombas.
  Cerrado, es inmutable; los errores se corrigen con un **ajuste** del Gerente General (solo mientras el siguiente corte siga abierto).
- **Cuadre**: nivel teórico (`inicial + compras − galones del medidor − pérdidas`) contra el nivel medido, como indicador.
- **Alertas de tanque** (Crítico / Medio / Óptimo) por porcentaje y por autonomía en días.
- **Tienda**: el Cajero cobra en un POS (pago simulado), y su **cierre de caja** compara el efectivo contado con el esperado.
- Nada se borra: se desactiva o se anula.

El detalle de cada regla está en [`docs/FLUJO.md`](docs/FLUJO.md).

## Documentación

| Archivo | Contenido |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Índice y reglas del proyecto (para sesiones de trabajo) |
| [`docs/FLUJO.md`](docs/FLUJO.md) | Decisiones de negocio, tema por tema (fuente de verdad) |
| [`docs/BASE_DE_DATOS.md`](docs/BASE_DE_DATOS.md) | Esquema, funciones, vistas, permisos y verificación |
| [`docs/PLAN_DESARROLLO.md`](docs/PLAN_DESARROLLO.md) | Arquitectura, mapa pantallas ↔ base de datos y fases |
| [`FIGMA_INTERACCIONES.md`](FIGMA_INTERACCIONES.md) | Pantallas e interacciones del prototipo |
| `supabase/migrations/` | SQL aplicado al proyecto de Supabase |
| `supabase/functions/gestionar-usuarios/` | Edge Function para crear y administrar usuarios |

## Backend (Supabase)

Proyecto `app_gasolinera`. Las reglas de negocio, los permisos por rol y las validaciones viven en la base de datos
(funciones, vistas, seguridad por fila y disparadores): las apps solo llaman a funciones y leen vistas. Los usuarios se crean
con la Edge Function `gestionar-usuarios`, que usa una clave de administrador que **nunca** va en las apps.

**Primer uso**: el primer Gerente General se crea a mano en Supabase (Authentication → Users) y se le crea su fila en `perfiles`.
Los demás usuarios se crean desde la app. La recuperación de contraseña por código necesita un servidor de correo (SMTP) configurado
en Supabase.

## Requisitos (app iOS)

- Mac con **Xcode 15** o superior
- **iOS 17.2+**, Swift 5
- Paquete `supabase-swift` (Swift Package Manager)

La configuración (URL del proyecto y clave **publishable**) vive en la app; la clave secreta nunca.

## Ejecución (iOS)

1. Clona el repositorio.
2. Abre `App76.xcodeproj` en Xcode.
3. Selecciona un simulador y presiona **Run** (⌘R).

> Mientras se completa la reescritura, el proyecto puede no compilar o seguir mostrando la demo anterior.

## Diseño

Prototipo en Figma: https://www.figma.com/design/P4lxHxo4WqEK2xvQu4XRXq — **corresponde al diseño anterior** y se actualizará
al final del desarrollo. Las pantallas e interacciones vigentes están en [`FIGMA_INTERACCIONES.md`](FIGMA_INTERACCIONES.md).
