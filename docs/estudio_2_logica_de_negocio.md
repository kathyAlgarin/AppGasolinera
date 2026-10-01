# Guía de estudio 2: la lógica de negocio (en lenguaje natural)

## La idea en una frase
El gerente anota **dos veces al día** qué hay en sus tanques y cuánto vendió cada bomba. Con eso la app calcula sola cuánto se vendió y cuánto dinero entró, y **verifica con una segunda opinión (el tanque)** que los números tengan sentido.

---

## 1. Los dos cortes diarios

| | Apertura (al empezar) | Cierre (al terminar) |
|---|---|---|
| Qué anotas | Nivel de los 3 tanques | Nivel de los 3 tanques **y** los litros que vendió cada bomba |
| Cuántos números | 3 | 3 + 18 (6 bombas × 3 combustibles) |
| Condición | Ninguna | Ya haber hecho la apertura de hoy |

**Reglas que la app hace cumplir**
- Una apertura y un cierre por sucursal y por día.
- No puedes cerrar sin haber abierto.
- Los niveles deben estar **entre 0 y la capacidad** del tanque.
- En el cierre deben venir las 18 ventas y ninguna puede ser negativa.
- Un corte **ya guardado no se edita**: el formulario lo muestra de solo lectura y el botón dice "Corte ya registrado".

**Ayudas al gerente:** el formulario viene con los niveles actuales precargados, muestra la capacidad de cada tanque y avisa en rojo si te pasas.

### ¿Por qué el nivel de tanque se puede escribir a mano (incluso en el cierre)?
Porque es una **medición física** (con varilla o sonda). Es justo lo que luego se compara con lo que dijeron las bombas. Si la app lo calculara sola, la comparación siempre saldría perfecta y no servirías para detectar fugas.

---

## 2. Recepciones y pérdidas

- **Recepción:** cuando llega un camión cisterna. Sube el nivel del tanque. No puede pasar de la capacidad (*"solo caben 3,000 L más"*).
- **Pérdida:** combustible que se perdió (fuga, derrame…). Baja el nivel. Lleva **razón obligatoria** y no puede ser mayor que lo que hay en el tanque.
- **Cuándo:** solo con el **turno abierto**, es decir, después de la apertura y antes del cierre.

**¿Por qué solo con el turno abierto?** Imagina que llega el camión, mides el tanque para el cierre (ya con el combustible adentro) y *luego* registras la recepción. Esa recepción quedaría fuera de la cuenta del cuadre y saldría una diferencia falsa. Lo que ocurra fuera del turno se corrige al medir el nivel en la apertura siguiente.

---

## 3. Juntar las 6 bombas (consolidación)

1. Cada bomba tiene sus litros vendidos por combustible (del cierre).
2. Se suman las 6 por combustible → "vendimos 700 L de Regular".
3. Se multiplica por el precio de esa sucursal → dinero.
4. El Gerente General suma las sucursales **activas** → total de la empresa.

```
6 bombas → total de la sucursal → suma de sucursales activas
```

**Ejemplo (76 Centro):** 700 L × $1.05 + 400 L × $1.25 + 600 L × $0.98 = **$1,823.00**.

El reporte del día solo existe cuando hay **apertura y cierre**. Mientras no, el panel dice *"Aún no hay corte de apertura y cierre de hoy"*.

---

## 4. El cuadre con los tanques (la segunda opinión)

Dos formas independientes de saber cuánto salió:
- **Las bombas** dicen cuánto se *vendió*.
- **El tanque** dice cuánto *bajó*.

```
Bajó el tanque = apertura + lo que llegó en camión − cierre
Diferencia     = bajó el tanque − lo que vendieron las bombas − pérdidas registradas
```

**Analogía:** cuadrar la caja. Las ventas dicen cuánto *debería* haber; el efectivo contado dice cuánto *hay*. Si no coinciden, algo pasó.

**Ejemplo que cuadra (Regular):**
- Apertura 5,000 L · Recibió 1,000 L · Pérdida registrada 50 L · Cierre 5,350 L · Bombas 600 L
- El tanque bajó 5,000 + 1,000 − 5,350 = **650 L**
- Bombas 600 + pérdida 50 = **650 L** → diferencia **0** → **Cuadra** ✅

**Si olvidas registrar la pérdida:** diferencia de **50 L** → **No cuadra** ❌ (la app te dice que del tanque salieron 50 L más de los que explican las bombas).

**Tolerancia:** medir un tanque nunca es perfecto, por eso se acepta una diferencia de hasta **1 % de lo vendido (mínimo 1 L)**. En 700 L vendidos, hasta ±7 L.

**¿Cuál número es el oficial?** El de las **bombas**. El cuadre no cambia totales, solo avisa.

La pantalla explica el porqué por combustible: muestra la cuenta del tanque, las bombas, las pérdidas, la diferencia, la tolerancia y una frase en lenguaje claro.

---

## 5. Indicadores de nivel de tanque

Cada tanque muestra "6,800 / 10,000 L" y una barra. La barra es `nivel ÷ capacidad` (entre 0 y 1). El nivel cambia por:
- un **corte** (se reemplaza por lo medido),
- una **recepción** (se suma),
- una **pérdida** (se resta).

---

## 6. Resumen de validaciones (para memorizar)

| Qué | Regla |
|---|---|
| Nivel en un corte | 0 ≤ nivel ≤ capacidad |
| Apertura / cierre | 1 de cada uno por día; cierre exige apertura |
| Cierre | 18 ventas completas y ≥ 0 |
| Recepción | > 0 y ≤ espacio libre; solo con turno abierto |
| Pérdida | > 0, ≤ nivel actual, con razón; solo con turno abierto |
| Cuadre | diferencia ≤ max(1 % de lo vendido, 1 L) |

## 7. Datos demo para comprobar
- 76 Centro: 1,700 L y $1,823.00; por bomba 330, 270, 280, 260, 320, 240 L.
- Panel general: 5,100 L y $5,469.00.
- Para probar cortes desde cero: `prueba@gas76.com` / `1234` (sucursal "76 Pruebas").

## 8. Frases útiles para el informe
- "Las ventas oficiales se calculan a partir de las bombas; el tanque funciona como control cruzado."
- "Las recepciones y pérdidas se restringen al turno abierto para que siempre caigan dentro de la ventana del cuadre."
- "El nivel de tanque es una medición física, por eso es un dato capturado y no calculado."
