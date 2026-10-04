# Gasolineras — gestión de franquicia (El Salvador)

Sistema para administrar una franquicia de estaciones de servicio: sucursales con 6 bombas, tanques, cortes de combustible
(Súper, Regular y Diésel), precios, tienda de conveniencia y servicios, personal y turnos. Una **app iOS** (SwiftUI) y, después,
una **versión web** (React + Node.js) con las mismas funcionalidades, sobre un mismo backend **Supabase**.

> **Estado: app iOS completa (fases 0–7), pendiente de probar con datos reales; la web aún no existe.**
> La base de datos está aplicada y probada; la app iOS ya se reescribió sobre Supabase, compila y corre en el simulador
> en el simulador). Faltan tus pruebas con la cuenta real. Ver el estado detallado en
> [`docs/PLAN_DESARROLLO.md`](docs/PLAN_DESARROLLO.md).

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

- Mac con **Xcode 15** o superior (se compiló y probó con Xcode 27 y el simulador iPhone 17 Pro)
- **iOS 17.2+**, Swift 5
- Paquete `supabase-swift` ≥ 2.0.0 (Swift Package Manager; Xcode lo resuelve solo)

La configuración (URL del proyecto y clave **publishable**) vive en `App76/Core/Configuracion.swift`; la clave secreta nunca.

## Ejecución (iOS)

1. Clona el repositorio y abre `App76.xcodeproj` en Xcode.
2. Selecciona un simulador y presiona **Run** (⌘R). Inicia sesión con tu usuario de Supabase.
3. Si agregas o borras archivos `.swift`, corre `python3 tools/sincronizar_proyecto.py` (con Xcode cerrado) para registrarlos en el proyecto.

## Pruebas

```bash
tools/correr_pruebas.sh
```

Compila y corre en macOS (sin simulador) las pruebas de lógica: modelos, validadores, fechas, **todos los ViewModels** con servicios
falsos, y la decodificación de JSON **real** que devuelve el servidor (`Pruebas/datos_reales_vistas.json`). Hoy: **480 verificaciones**.
Los servicios de Supabase y las vistas se verifican compilando la app (`xcodebuild`) y en el simulador.

## Diseño

Prototipo en Figma: https://www.figma.com/design/P4lxHxo4WqEK2xvQu4XRXq — **corresponde al diseño anterior** y se actualizará
al final del desarrollo. Las pantallas e interacciones vigentes están en [`FIGMA_INTERACCIONES.md`](FIGMA_INTERACCIONES.md).
