#!/usr/bin/env python3
"""Genera la guía de pantallas de la app a partir de un solo contenido:
  - docs/PANTALLAS.md          (Markdown; imágenes en docs/capturas/mini/)
  - docs/PANTALLAS.html        (una sola página con las imágenes incluidas)

Uso:  python3 tools/generar_guia_pantallas.py
Las capturas originales están en docs/capturas/*.png (se reducen a docs/capturas/mini/*.jpg con ffmpeg).
Si se recaptura una pantalla: reemplazar el .png, regenerar la miniatura y volver a correr este script.
"""
import base64
import html
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MINI = os.path.join(RAIZ, "docs", "capturas", "mini")

# --------------------------------------------------------------------------------------------
# Contenido. Cada pantalla: titulo, imgs=[(archivo, pie)], que, como=[...], nota (opcional),
# sin_captura (texto que explica por qué no hay captura; la descripción sale del código).
# --------------------------------------------------------------------------------------------

def P(titulo, que, como, imgs=(), nota=None, sin_captura=None):
    return dict(titulo=titulo, que=que, como=list(como), imgs=list(imgs), nota=nota, sin_captura=sin_captura)


SECCIONES = []

# ============================================================================================
SECCIONES.append(dict(
    id="acceso", titulo="1. Acceso y cuenta (todos los roles)",
    intro="Estas pantallas son las mismas para el Gerente General, el Gerente de Sucursal y el Cajero. "
          "Después de iniciar sesión, la app muestra solo lo que le corresponde al rol.",
    pantallas=[
        P("Inicio de sesión",
          "Es la puerta de entrada. Sirve para identificarse con el correo y la contraseña de la cuenta que creó el Gerente General.",
          ["Se escribe el **correo** y la **contraseña** (el ojo la muestra u oculta). **Ingresar** queda gris hasta que ambos campos tengan algo.",
           "Si los datos son incorrectos aparece el mensaje «Correo o contraseña incorrectos.» y desaparece al volver a escribir.",
           "Si la cuenta tiene una **contraseña temporal**, la app lleva primero a «Cambia tu contraseña» (más abajo). Si no, entra directo al inicio del rol.",
           "Una cuenta desactivada no puede entrar.",
           "**¿Olvidaste tu contraseña?** abre la recuperación."],
          [("00-login", "Login")]),
        P("Recuperar contraseña · paso 1: correo",
          "Primer paso para quien olvidó su contraseña: la app envía un código de 6 dígitos al correo de la cuenta.",
          ["Se escribe el correo (si ya se había escrito en el login, llega precargado). **Enviar código** se habilita cuando el formato es válido."],
          [("01-recuperar-correo", "Paso 1")]),
        P("Recuperar contraseña · paso 2: código",
          "Segundo paso: se escribe el código recibido por correo.",
          ["Seis casillas que se llenan con un solo teclado numérico. **Verificar** se habilita cuando están las 6.",
           "Si el código es incorrecto o venció: «Código incorrecto o vencido.»",
           "**Reenviar código** tiene una espera con cuenta regresiva en segundos. **Cambiar correo** vuelve al paso 1."],
          sin_captura="Este flujo lo prueba la usuaria directamente (implica escribir su correo y un código de verificación), por eso no se grabó ni se capturó. "
                      "El envío del código depende del SMTP del proyecto Supabase, que sigue pendiente de configurar y de probar."),
        P("Recuperar contraseña · paso 3: nueva contraseña",
          "Último paso: definir la contraseña nueva.",
          ["Nueva contraseña y confirmación, de 8 a 72 caracteres. **Guardar** se habilita cuando coinciden.",
           "Al terminar, vuelve al login con un aviso de éxito."],
          sin_captura="Mismo motivo que el paso 2."),
        P("Cambio de contraseña obligatorio",
          "Aparece justo después de entrar con una **contraseña temporal** (cuentas nuevas o con contraseña restablecida). No deja usar la app hasta cambiarla.",
          ["Pantalla completa sin botón «atrás»: título «Cambia tu contraseña» y el texto «Entraste con una contraseña temporal. Define una nueva para continuar.»",
           "Nueva y confirmar (8 a 72 caracteres). **Guardar** cambia la contraseña, apaga la bandera de «debe cambiarla» y entra al inicio del rol.",
           "Arriba a la derecha hay **Cerrar sesión** por si no se quiere continuar."],
          sin_captura="Es una pantalla que aparece una sola vez por cuenta y pide escribir contraseñas, así que no se capturó. La usuaria la vio al entrar con las cuentas de ejemplo."),
        P("Perfil",
          "Muestra los datos de la cuenta y permite cambiar la contraseña o cerrar sesión. Existe en los tres roles; el Gerente de Sucursal y el Cajero ven además su sucursal.",
          ["Nombre, correo, rol (y sucursal) en solo lectura: no se editan aquí.",
           "**Cambiar contraseña** abre una hoja (siguiente captura). **Cerrar sesión** pide confirmación y vuelve al login."],
          [("gg-64-perfil", "Perfil del Gerente General"),
           ("gs-78-perfil", "Perfil del Gerente de Sucursal"),
           ("cj-40-perfil", "Perfil del Cajero")]),
        P("Cambiar contraseña (hoja) y confirmar «Cerrar sesión»",
          "Cambio voluntario de contraseña, y la ventana que evita cerrar la sesión por accidente.",
          ["La hoja pide nueva contraseña y confirmación (8 a 72 caracteres); **Guardar** queda gris hasta que sean válidas y coincidan.",
           "En la ventana «¿Cerrar sesión?», **Cancelar** no hace nada y **Cerrar sesión** vuelve al login."],
          [("gg-65-cambiar-password", "Hoja «Cambiar contraseña»"),
           ("gg-66-cerrar-sesion-alerta", "Confirmación de cerrar sesión")]),
    ]))

# ============================================================================================
SECCIONES.append(dict(
    id="gg", titulo="2. Gerente General",
    intro="Ve **toda la franquicia**: todas las sucursales, sus precios, usuarios y catálogo. Su barra inferior tiene cinco pestañas: "
          "**Panel · Sucursales · Precios · Usuarios · Más**. Consulta los cortes de las sucursales, pero **no los registra**. "
          "Es el único que puede fijar precios, crear usuarios y ajustar una lectura de un corte ya cerrado.",
    pantallas=[
        P("Panel",
          "Es el tablero principal: resume las ventas de combustible y los problemas que requieren atención, para una sucursal o para todas.",
          ["**Sucursal** (menú desplegable): «Todas las sucursales» o una en concreto; todas las cifras se recalculan.",
           "**Periodo**: Hoy · 7 días · 30 días · Fechas. «Fechas» muestra dos fechas para elegir un rango (nunca futuro).",
           "El texto «Datos de 27 de 56 cortes» indica cuántos cortes **cerrados** entran en las cifras, de los que hay en el periodo. "
           "El servidor solo cuenta lo que ya cerró, porque las ventas de combustible se conocen al cerrar el corte.",
           "Tarjetas **Galones vendidos** e **Ingreso en combustible**, y debajo una tarjeta por combustible (Súper, Regular, Diésel) con vendido, ingreso, compras y pérdidas. Tocar una abre el detalle de ese combustible.",
           "Si no hay sucursales, en lugar de cifras sale «No hay datos todavía. Crea una sucursal en la pestaña Sucursales…»."],
          [("gg-10-panel-7dias", "Panel, 7 días, todas las sucursales"),
           ("gg-10b-panel-menu-sucursal", "Menú de sucursal")],
          nota="Esta captura y la del menú de sucursal se tomaron antes de renombrar la pestaña «Personalizado» a «Fechas»; la app actual dice «Fechas»."),
        P("Panel · rango de fechas",
          "Para ver cualquier periodo que no sea Hoy, 7 o 30 días.",
          ["Al elegir **Fechas** aparecen dos botones (desde y hasta) que abren un calendario en español. No permite fechas futuras ni un rango invertido.",
           "Al cambiar una fecha el panel se vuelve a cargar solo."],
          [("gg-10c-panel-personalizado", "Pestaña «Fechas» con el rango"),
           ("gg-10d-panel-calendario", "Calendario")]),
        P("Panel · tendencia, ranking y tanques críticos",
          "La parte de abajo del Panel: cómo evolucionan las ventas y dónde hay que actuar.",
          ["**Tendencia de galones vendidos**: barras apiladas por día, con un color por combustible.",
           "**Ranking de sucursales por ventas**: ordenadas de mayor a menor; tocar una fila abre el detalle de la sucursal.",
           "**Tanques en estado Crítico**: lista de los tanques que están en rojo (20 % o menos, o poca autonomía). Tocar una fila abre esa sucursal.",
           "**Sucursales sin corte cerrado hoy**: aviso informativo.",
           "**Cortes con diferencia en el cuadre**: cuántos cortes tuvieron diferencia entre lo que marcó el medidor y lo que midió el tanque. El **?** explica la tolerancia del 0.5 %. Es un indicador, no una alerta que bloquee nada."],
          [("gg-11-panel-scroll1", "Tendencia y ranking"),
           ("gg-12-panel-scroll2", "Críticos, cortes con diferencia y tienda"),
           ("gg-13-panel-ayuda-cuadre", "Ayuda del cuadre")]),
        P("Panel · bloque «Tienda y servicios»",
          "Resume la tienda de las sucursales **por separado del combustible**: ingreso por categoría (lubricantes, bebidas, snacks, otros productos, servicios), ventas anuladas, cierres de caja con diferencia, cierres forzados y productos con stock bajo.",
          ["El enlace **Ver tienda y cajas** abre el detalle completo (pantalla «Tienda y cajas», más abajo)."],
          [("gg-12-panel-scroll2", "Bloque de tienda al final del Panel")]),
        P("Detalle de combustible",
          "Muestra, para un combustible, cuánto vendió, compró y perdió cada sucursal en el periodo.",
          ["Cuatro tarjetas arriba: vendido, ingreso, compras y pérdidas.",
           "Debajo, una tarjeta por sucursal con sus cifras y la **fila del tanque**: galones, porcentaje de llenado, barra de color y estado (Óptimo/Medio/Crítico).",
           "La **autonomía** (días que dura el combustible) aparece cuando hay historial suficiente; el **?** explica cómo se calcula. «Estimado al corte del …» indica de cuándo es el dato."],
          [("gg-14-detalle-combustible", "Regular")]),
        P("Detalle de sucursal (consulta)",
          "Ficha completa de una sucursal para el Gerente General. Es solo de consulta: desde aquí no se registran cortes.",
          ["Arriba: dirección, etiqueta «Con tienda» y el **Gerente asignado** con su correo.",
           "**Tanques**: nivel estimado al último corte, porcentaje, estado, autonomía y el texto «Incluye N compras y M pérdidas del corte en curso».",
           "**Precios vigentes** por combustible. **Cortes recientes**: tocar uno abre su reporte; «Ver historial completo» lista todos.",
           "**Pérdidas registradas**: tipo (Merma, Fuga, Derrame, Contaminación…), galones y nota. **Personal**: empleados y turnos activos, con enlace a verlos. **Tienda y servicios** de los últimos 30 días."],
          [("gg-15-detalle-sucursal", "Encabezado y tanques"),
           ("gg-17-detalle-sucursal-cortes", "Precios, cortes recientes y pérdidas"),
           ("gg-16-detalle-sucursal-abajo", "Personal y tienda")]),
        P("Reporte de un corte",
          "El documento de un corte cerrado: qué marcó cada manguera, cuánto se vendió y si el tanque cuadra con el medidor. También lo ve el Gerente de Sucursal.",
          ["Encabezado: sucursal, tipo (Matutino/Vespertino), fecha, hora de cierre y quién lo cerró. Etiquetas **Ajustado** y **Cambio de medidor** si aplican; se pueden tocar para ver qué significan.",
           "**Bombas**: las 6, con las 3 mangueras (Súper, Regular, Diésel): lectura inicial → final, galones y dólares.",
           "**Consolidado por combustible**: galones, ingreso, compras y pérdidas.",
           "**Cuadre (medidor vs tanque)**: nivel inicial, teórico, medido y diferencia; «Cuadra» (verde) o «Diferencia» (naranja). El **?** explica la regla: se considera que cuadra si la diferencia es menor al 0.5 % de los galones despachados.",
           "**Pérdidas** y **Ajustes** del corte (con el motivo escrito). Los números salen del servidor; la app no recalcula nada."],
          [("gg-18-reporte-corte", "Encabezado y bombas"),
           ("gg-19-reporte-corte-2", "Bombas 5 y 6 y consolidado"),
           ("gg-19b-reporte-corte-3", "Cuadre, pérdidas y ajustes")]),
        P("Ajustar lectura (hoja, solo Gerente General)",
          "Permite corregir una lectura de manguera de un corte ya cerrado cuando se descubre un error de captura. El corte no se reescribe: el ajuste se guarda aparte.",
          ["El botón **Ajustar lectura** aparece al final del reporte, solo si el corte siguiente sigue abierto. Si el siguiente ya se cerró, no aparece y el corte es definitivo.",
           "Se elige la **manguera**, se escribe el **valor correcto de la lectura final** (no puede ser menor a la lectura inicial) y un **motivo** obligatorio. **Guardar ajuste** queda gris hasta tener ambos.",
           "Después, el reporte muestra la etiqueta «Ajustado», la lectura original se conserva y el ajuste queda en la sección Ajustes."],
          [("gg-19c-ajustar-lectura", "Hoja «Ajustar lectura»")],
          nota="Se capturó la hoja vacía; no se guardó ningún ajuste (cambiaría un corte real)."),
        P("Sucursales",
          "Lista de todas las sucursales de la franquicia. Es el punto de partida para crear, editar o desactivar sucursales.",
          ["Cada fila muestra nombre y dirección, con las etiquetas **Con tienda** o **Inactiva**. Tocar una fila abre su edición.",
           "El **+** de arriba a la derecha abre «Nueva sucursal»."],
          [("gg-20-sucursales", "Lista de sucursales")]),
        P("Editar sucursal",
          "Cambia el nombre, la dirección o el estado de una sucursal existente.",
          ["Nombre y dirección editables. Interruptores **Activa** (una sucursal se desactiva, nunca se borra) y **Tiene tienda** (no se puede apagar si hay cajas abiertas).",
           "Los **tanques** (capacidad y nivel inicial) se ven en solo lectura: no se editan.",
           "**Guardar cambios** queda gris hasta que se modifica algo válido."],
          [("gg-21-detalle-sucursal", "Edición"),
           ("gg-22-editar-sucursal-fin", "Interruptores y tanques")]),
        P("Nueva sucursal (hoja)",
          "Crea una sucursal nueva con todo lo necesario para operar.",
          ["Datos: **nombre**, **dirección** y el interruptor **Tiene tienda**.",
           "Para cada combustible (Súper, Regular, Diésel): **capacidad** del tanque (obligatoria, mayor que 0) y **nivel inicial** (opcional: si se deja vacío queda en 0, y no puede superar la capacidad).",
           "Al crearla se generan automáticamente **6 bombas, 18 mangueras y 3 tanques**.",
           "**Crear sucursal** está gris mientras falte algo, y un texto explica qué: «Para crearla completa el nombre, la dirección y la capacidad de los tres tanques.»"],
          [("gg-23-nueva-sucursal", "Formulario"),
           ("gg-23b-nueva-sucursal-fin", "Final del formulario")]),
        P("Precios",
          "Muestra el precio vigente de cada combustible en la sucursal elegida y es la puerta para cambiarlos. Solo el Gerente General fija precios.",
          ["Selector de sucursal; tres filas con el precio por galón y la fecha desde la que rige. Si falta un precio sale el aviso «Sin precio: la sucursal no podrá cerrar cortes».",
           "**Fijar precio** abre la hoja para cambiarlo. **Ver historial de precios** muestra los anteriores."],
          [("gg-30-precios", "Precios vigentes")]),
        P("Fijar precio (hoja)",
          "Cambia el precio de un combustible en una, varias o todas las sucursales a la vez.",
          ["Se elige el **combustible**, el **precio por galón** (mayor que 0, hasta 2 decimales; es el precio final con impuestos; el **?** lo explica) y **Aplicar a**: Esta sucursal · Elegir sucursales · Todas.",
           "Con «Elegir sucursales» aparece una lista con casillas. **Guardar** queda gris hasta que el precio y el destino sean válidos.",
           "Cada cambio guarda su fecha de inicio: el historial nunca se sobrescribe. El corte usa el precio vigente en el momento de cerrarse."],
          [("gg-31-fijar-precio", "Hoja"),
           ("gg-32-fijar-precio-ayuda", "Ayuda del precio"),
           ("gg-33-fijar-precio-elegir", "Elegir sucursales")]),
        P("Historial de precios",
          "Lista cronológica de los precios que ha tenido cada combustible en la sucursal. Solo consulta.",
          ["Agrupado por combustible, del más reciente al más antiguo, con fecha y hora de inicio."],
          [("gg-34-historial-precios", "Historial")]),
        P("Usuarios",
          "Lista de las cuentas del sistema. Desde aquí se crean usuarios y se administran los existentes.",
          ["Filtros por **sucursal** y por **rol**. Cada fila muestra nombre, correo, rol, sucursal y la etiqueta **Inactivo** si corresponde. Tocar una fila abre su edición; el **+** abre «Nuevo usuario»."],
          [("gg-40-usuarios", "Lista de usuarios")]),
        P("Nuevo usuario (hoja)",
          "Crea una cuenta nueva (la Edge Function `gestionar-usuarios` lo hace en el servidor; la app nunca guarda claves secretas).",
          ["**Nombre**, **correo** (formato válido) y **contraseña temporal** (8 a 72 caracteres, con ojo para verla). El usuario deberá cambiarla al iniciar sesión.",
           "**Rol**: Gerente General, Gerente de Sucursal o Cajero (menú desplegable). Para los dos últimos aparece **Sucursal** (el Cajero solo puede asignarse a sucursales con tienda).",
           "**Crear usuario** queda gris hasta que todo es válido. Errores del servidor, por ejemplo: «Esa sucursal ya tiene un Gerente de Sucursal activo.» o correo repetido."],
          [("gg-41-nuevo-usuario", "Formulario")]),
        P("Editar usuario",
          "Permite corregir el correo, activar/desactivar la cuenta y restablecer la contraseña.",
          ["**Cambiar correo**: para cuando se escribió mal; el usuario deberá iniciar sesión con el correo nuevo. No se puede cambiar el propio.",
           "Interruptor **Activo**: un usuario desactivado no puede entrar y nunca se borra. No se puede desactivar al último Gerente General ni a uno mismo.",
           "**Restablecer contraseña**: se escribe una contraseña temporal nueva; el usuario deberá cambiarla al entrar."],
          [("gg-42-editar-usuario", "Edición")]),
        P("Más",
          "Menú con lo que no cabe en la barra inferior.",
          ["**Catálogo**, **Pérdidas y contaminaciones**, **Tienda y cajas**, **Personal** y **Perfil**."],
          [("gg-50-mas", "Menú Más")]),
        P("Catálogo",
          "Lista de productos y servicios de la tienda, comunes a toda la franquicia.",
          ["Cada fila: nombre, categoría, tipo (Producto o Servicio) y precio; **Inactivo** si está desactivado. El **+** crea un artículo; tocar una fila lo edita."],
          [("gg-51-catalogo", "Catálogo")]),
        P("Nuevo artículo (hoja)",
          "Alta de un producto (con inventario) o un servicio (sin inventario).",
          ["**Nombre**, **categoría** (Lubricantes, Bebidas, Snacks, Otros productos, Servicios), **tipo** (Producto o Servicio; si la categoría es Servicios, el tipo queda en Servicio), **precio de venta** (mayor que 0) y el interruptor **Activo**.",
           "Al editar un artículo existente, el tipo y la categoría ya no se pueden cambiar. **Guardar** queda gris hasta que nombre y precio son válidos."],
          [("gg-52-articulo", "Formulario")]),
        P("Pérdidas y contaminaciones",
          "Lista global de las pérdidas de combustible registradas en cualquier sucursal.",
          ["Filtros: sucursal, **tipo** (Merma, Fuga, Falla técnica, Derrame, Contaminación) y un interruptor **Filtrar por fechas**.",
           "Cada fila: sucursal, combustible, tipo, galones, nota y fecha. Las de **Contaminación** llevan etiqueta propia (tocarla explica qué es)."],
          [("gg-53-perdidas", "Lista de pérdidas")],
          nota="Las filas de Metrocentro son pruebas de la usuaria (vaciado por descarga errónea con la nota «error»)."),
        P("Tienda y cajas",
          "Vista de consulta de la tienda de todas las sucursales: cuánto se vendió, cómo cerraron las cajas y qué productos se están acabando.",
          ["Arriba: sucursal, periodo (Hoy · 7 días · 30 días · Fechas) y dos tarjetas: **Ingreso de tienda** y **Cajas con diferencia**.",
           "Un selector de tres secciones evita una pantalla larguísima: **Cierres de caja**, **Anulaciones** y **Stock bajo**.",
           "**Cierres de caja**: por cajero, fondo / esperado / contado, y la diferencia (Sobrante, Faltante, o $0.00 en verde). La etiqueta **Forzado** se puede tocar para ver qué significa.",
           "**Anulaciones**: por sucursal, cuántas ventas se anularon y su monto. **Stock bajo**: productos que llegaron al mínimo; los que están en cero dicen «Agotado»."],
          [("gg-54-tienda-cierres", "Cierres de caja"),
           ("gg-55-tienda-anulaciones", "Anulaciones"),
           ("gg-56-tienda-stock", "Stock bajo"),
           ("gg-57-tienda-cierres-scroll", "Cierres, más abajo"),
           ("gg-58-forzado-explicacion", "Explicación de «Forzado»")],
          nota="Las tres primeras capturas muestran la pestaña de periodo con el nombre antiguo («Personalizado»); la app actual dice «Fechas»."),
        P("Personal (consulta)",
          "El Gerente General ve el personal de cualquier sucursal, sin poder editarlo (lo administra el Gerente de Sucursal). Los turnos son solo informativos: no afectan cortes, pagos ni cajas.",
          ["Selector de sucursal. **Quién trabaja ahora** muestra los empleados activos del turno actual.",
           "**Empleados**: nombre, cargo y turno. **Turnos**: horas de inicio y fin (el turno «Noche» termina al día siguiente). **Horario semanal**: cuadrícula de turnos por día de la semana (se desliza hacia la derecha)."],
          [("gg-59-personal", "Personal"),
           ("gg-60-empleados", "Empleados"),
           ("gg-61-turnos", "Turnos"),
           ("gg-62-horario", "Horario semanal"),
           ("gg-63-horario-derecha", "Horario, fin de semana")]),
        P("Pantallas del Gerente General sin captura",
          "Acciones que existen pero que no se ejecutaron para no modificar datos reales.",
          ["**Crear un usuario, restablecer una contraseña o cambiar un correo**: se capturaron los formularios vacíos; las probaron antes por HTTP contra el servidor (crear 201, correo repetido 409, restablecer, desactivar, cambiar correo).",
           "**Guardar un precio, una sucursal o un artículo**: se ven los formularios y su validación, pero no se confirmó ninguno.",
           "**Guardar un ajuste de lectura**: ver la nota de la pantalla correspondiente."],
          sin_captura="Cualquier guardado cambia la base de datos real; varias de esas cosas (cortes, ventas, ajustes) son además inmutables."),
    ]))

# ============================================================================================
SECCIONES.append(dict(
    id="gs", titulo="3. Gerente de Sucursal",
    intro="Ve y opera **solo su sucursal**. Su barra inferior: **Inicio · Corte · Tienda · Personal · Más**. "
          "«Tienda» y «Cajeros» solo aparecen si la sucursal tiene tienda. Es quien registra el **corte** (la captura de lecturas, compras, pérdidas y niveles) y quien administra la tienda, el personal y los cajeros.",
    pantallas=[
        P("Inicio",
          "Pantalla de bienvenida con el estado de los tanques y del corte en curso. Responde: «¿cómo está mi sucursal ahora?».",
          ["**Tanques** (Súper, Regular, Diésel): galones, porcentaje, barra y estado (Óptimo/Medio/Crítico, que se pueden tocar para ver su regla). "
           "«Estimado al corte del …» dice de cuándo es el dato y «Incluye N compras y M pérdidas del corte en curso» aclara qué se sumó desde entonces.",
           "**Autonomía**: días que dura el combustible al ritmo de ventas de los últimos 7 días. En sucursales con poco historial dice «Autonomía aún no disponible» y el estado usa solo el porcentaje. El **?** explica la regla completa.",
           "**Corte en curso**: bombas guardadas (3 de 6), compras y pérdidas. **Continuar corte** lleva a la pestaña Corte; **Registrar compra** y **Registrar pérdida** son atajos.",
           "**Hoy, en cortes cerrados**: galones e ingreso de los cortes cerrados hoy, por combustible; «Sin cortes cerrados hoy» si no hay."],
          [("gs-10-inicio", "Tanques"),
           ("gs-11-ayuda-autonomia", "Ayuda de autonomía"),
           ("gs-12-inicio-abajo", "Corte en curso y resumen de hoy")]),
        P("Corte en curso (centro del flujo)",
          "Es el tablero del corte abierto. Un **corte** es el cierre de un turno de combustible: se captura qué marcó cada manguera, se registran compras y pérdidas, se mide cada tanque y se cierra. Hay dos por día (Matutino y Vespertino).",
          ["Lista de secciones con su estado: **Bombas** (3 de 6 guardadas), **Compras**, **Pérdidas**, **Descarga errónea y vaciado**, **Tienda** (si hay) y **Niveles de tanque**.",
           "**Resumen y cierre** está gris hasta tener las 6 bombas y los 3 niveles; debajo dice qué falta: «Faltan: Bomba 4, Bomba 5, Bomba 6 · nivel de Súper, Regular, Diésel».",
           "El **?** de arriba recuerda que las lecturas y los niveles se ingresan **a mano**: se lee el totalizador de cada manguera y se mide el tanque con varilla; la app no se conecta a las bombas."],
          [("gs-20-corte", "Corte en curso"),
           ("gs-21-corte-ayuda", "Ayuda de captura manual"),
           ("gs-22-corte-faltan", "Qué falta para cerrar")]),
        P("Bombas",
          "Lista de las 6 bombas del corte, para capturar las lecturas de sus 3 mangueras.",
          ["Cada bomba está **Pendiente** (círculo vacío) o **Guardada** (✓). Una bomba guardada se puede volver a abrir y editar hasta que se cierre el corte."],
          [("gs-30-bombas", "Lista de bombas")]),
        P("Bomba N (captura de lecturas)",
          "Formulario de una bomba: una tarjeta por manguera (Súper, Regular, Diésel).",
          ["Se escribe la **lectura final** del totalizador de cada manguera. La **lectura inicial** aparece como dato fijo: es la final del corte anterior.",
           "En el **primer corte de la sucursal** también se pide la lectura inicial (una sola vez), con un **?** que lo explica.",
           "Reglas de validación: sin letras, sin negativos y máximo 2 decimales; la final no puede ser menor que la inicial («La lectura final no puede ser menor que la inicial»). **Guardar bomba** queda gris hasta que las tres sean válidas.",
           "El enlace **El medidor se cambió** abre la hoja de cambio de medidor."],
          [("gs-31-bomba-pendiente", "Bomba 4, sin datos")],
          nota="Se capturó la bomba sin datos escritos; no se guardó nada para no alterar el corte real en curso."),
        P("Cambio de medidor (hoja)",
          "Para cuando se reemplazó físicamente el contador de una manguera (el nuevo marca 0 o un valor bajo): evita que los galones salgan negativos o absurdos.",
          ["Se elige la manguera, la **lectura final del medidor viejo**, la **lectura inicial del nuevo** (normalmente 0) y una **nota** obligatoria.",
           "Los galones de esa manguera pasan a ser (final del viejo − inicial) + (final − inicial del nuevo). El corte queda marcado «Cambio de medidor».",
           "Si ya existe, se puede ver, corregir o **quitar** el cambio."],
          [("gs-32-cambio-medidor", "Hoja")]),
        P("Compras",
          "Registro de las descargas de combustible que llegaron en este corte (camiones cisterna).",
          ["Lista con combustible, galones, proveedor y hora. El **+** abre «Nueva compra». Tocar una fila (o deslizarla hacia la izquierda) permite **Editar** o **Eliminar**. "
           "Las compras que genera un vaciado quedan bloqueadas y dicen «Generada por una descarga errónea»."],
          [("gs-33-compras", "Lista de compras")]),
        P("Nueva compra (hoja)",
          "Alta de una descarga recibida en un tanque.",
          ["Se elige el **tanque** (combustible), los **galones recibidos** (mayor que 0) y el **proveedor** (opcional, solo el nombre). La fecha y la hora se registran solas.",
           "Si la compra excede el espacio libre del tanque, el servidor lo rechaza: «La compra excede el espacio libre del tanque (libre: N gal).»"],
          [("gs-34-nueva-compra", "Formulario")]),
        P("Pérdidas",
          "Registro de combustible que se perdió y no se vendió: mermas, fugas, fallas o derrames.",
          ["Lista con tipo, combustible, galones y nota. El **+** abre «Nueva pérdida»; también se puede editar o eliminar tocando o deslizando la fila. Las pérdidas que genera un vaciado (Contaminación) llevan un candado y no se editan. «Sin pérdidas registradas» si está vacía."],
          [("gs-35-perdidas", "Lista de pérdidas")]),
        P("Nueva pérdida (hoja)",
          "Alta de una pérdida de combustible.",
          ["**Tipo**: Merma, Fuga, Falla técnica o Derrame. **Combustible**, **galones perdidos** (mayor que 0 y no más que el nivel estimado del tanque) y **nota** obligatoria.",
           "**Bomba (opcional)**: un derrame o una falla ocurre en una bomba; una fuga, en el tanque. El **?** lo explica.",
           "Lo que no se reporta como pérdida aparece luego como diferencia en el cuadre."],
          [("gs-36-nueva-perdida", "Formulario")]),
        P("Descarga errónea y vaciado (hoja)",
          "Para cuando se descargó combustible en el tanque equivocado, o hay que vaciar un tanque por contaminación o mantenimiento. No existe un botón de «vaciar» sin motivo.",
          ["**Motivo**: «Descarga de combustible equivocado» u «Otra contaminación o mantenimiento».",
           "**Tanque afectado**; con el primer motivo también el **combustible que traía la cisterna** y los **galones descargados por error**.",
           "**Nivel medido tras la descarga (varilla)**: se usa el medido y no el estimado (el **?** explica por qué). **Nota** obligatoria.",
           "Una vista previa lista lo que se va a registrar («Se registrarán…»: pérdida de X gal, compra y pérdida de Y gal del otro combustible, y que el tanque quedará en 0).",
           "**Registrar y vaciar** (botón rojo) pide confirmación. Genera las pérdidas de tipo Contaminación y, si fue descarga errónea, una compra del otro combustible; ya no se pueden editar."],
          [("gs-38-vaciado", "Formulario"),
           ("gs-39-vaciado-ayuda", "Ayuda del nivel medido")],
          nota="Se capturó el formulario vacío; registrar un vaciado cambia los niveles del tanque y no se puede deshacer."),
        P("Niveles de tanque",
          "Se mide cada tanque con varilla o sonda y se escribe el nivel en galones. Estos niveles son los que se comparan con el cálculo del sistema (el cuadre) al cerrar el corte.",
          ["Un campo por tanque (Súper, Regular, Diésel), mostrando su capacidad. No pueden superarla.",
           "**Guardar niveles** queda gris con el texto «Faltan los niveles de: …» hasta tener los tres. Los niveles se guardan en el teléfono y se envían al cerrar el corte."],
          [("gs-40-niveles", "Niveles de tanque")]),
        P("Resumen y cierre",
          "Vista previa de cómo quedará el corte **antes** de cerrarlo, calculada por el servidor con los mismos números del cierre real.",
          ["Si es el **primer corte** de la sucursal, pregunta si es Matutino o Vespertino (desde el segundo se alternan solos).",
           "Tarjetas de **galones** e **ingreso**, y una tarjeta por combustible: vendido, precio vigente, ingreso, compras, pérdidas, nivel teórico, nivel medido y el indicador **Cuadra / Diferencia**.",
           "Avisos que bloquean el cierre: «La sucursal no tiene precio de … Pídele al Gerente General que lo fije.» o «Hay N cajas abiertas: cierra las cajas antes de cerrar el corte.»",
           "La diferencia del cuadre es solo un indicador: no impide cerrar. **Cerrar corte** abre la ventana «¿Cerrar el corte? Después de cerrarlo no se podrá modificar.»"],
          sin_captura="Para llegar aquí deben estar guardadas las 6 bombas y los 3 niveles, lo que exige teclear lecturas reales y, al final, **cerrar el corte, que es permanente e inmutable**. "
                      "No se hizo para no alterar los datos reales de la sucursal."),
        P("Corte cerrado",
          "Confirmación después de cerrar el corte.",
          ["Muestra «Corte cerrado», el tipo (Matutino/Vespertino) y la fecha operativa, y avisa que ya no se puede modificar y que el siguiente corte quedó abierto con las lecturas iniciales derivadas.",
           "**Ver reporte** abre el reporte del corte; **Volver al inicio** regresa a Inicio."],
          sin_captura="Es el resultado de cerrar un corte (ver «Resumen y cierre»)."),
        P("Tienda · Inventario",
          "Inventario de la tienda de la sucursal: qué hay y qué falta. Aparece solo si la sucursal tiene tienda.",
          ["Cada producto muestra su stock y el **mínimo** configurado; la etiqueta **Stock bajo** se puede tocar para ver su significado.",
           "Arriba, **Entrada** (llegó mercadería) y **Baja** (se pierde mercadería). Un selector separa **Inventario · Ventas · Cajas**."],
          [("gs-50-tienda", "Inventario"),
           ("gs-51-stock-bajo-ayuda", "Explicación de «Stock bajo»")]),
        P("Entrada y baja de mercadería (hojas)",
          "Mantienen el inventario al día.",
          ["**Entrada**: producto, cantidad entera mayor que 0 y proveedor opcional.",
           "**Baja**: producto, cantidad (no más que el stock), **motivo** (Vencido, Dañado u Otro; con «Otro» la nota es obligatoria)."],
          [("gs-52-entrada", "Entrada"),
           ("gs-53-baja", "Baja")]),
        P("Tienda · Ventas y anulación",
          "Tickets vendidos por los cajeros en el corte. El Gerente puede anular una venta si la caja de esa venta sigue abierta.",
          ["Cada ticket: número, cajero, método, hora y total; las anuladas llevan la etiqueta **Anulada**.",
           "**Anular venta** abre una hoja que pide un **motivo** obligatorio. La venta se conserva marcada, se devuelve el stock y no cuenta en el efectivo esperado de la caja.",
           "Si la caja ya se cerró, la venta es definitiva y no se puede anular."],
          [("gs-54-ventas", "Ventas"),
           ("gs-55-anular-venta", "Hoja «Anular venta»")],
          nota="No se anuló ninguna venta."),
        P("Tienda · Cajas y cierre forzado",
          "Estado de las cajas de los cajeros en el corte. Una caja abierta bloquea el cierre del corte.",
          ["Cada caja: cajero, estado (**Abierta** o cerrada), fondo inicial y, si cerró, esperado / contado / diferencia. La etiqueta **Forzado** indica que la cerró el Gerente.",
           "**Cierre forzado**: cuando un cajero se fue sin cerrar. La hoja pide el **efectivo contado** y un **motivo** obligatorio; la caja queda marcada «Forzado»."],
          [("gs-56-cajas", "Cajas"),
           ("gs-57-cierre-forzado", "Cierre forzado")],
          nota="No se forzó ninguna caja."),
        P("Personal",
          "El Gerente de Sucursal administra los empleados de su sucursal (no son usuarios de la app) y sus turnos. Los turnos son solo informativos: no afectan cortes, pagos ni cajas.",
          ["**Quién trabaja ahora**: empleados activos del turno actual («Nadie en turno» si hay un hueco).",
           "Accesos a **Empleados**, **Turnos** y **Horario semanal**."],
          [("gs-60-personal", "Personal"),
           ("gs-61-empleados", "Empleados")]),
        P("Nuevo empleado y nuevo turno (hojas)",
          "Altas de personal y de turnos.",
          ["**Empleado**: nombre completo, cargo (Despachador, Cajero, Supervisor, Mantenimiento, Otro), teléfono y fecha de ingreso opcionales, interruptor Activo. **No se guarda DUI ni documentos**; un empleado se desactiva, nunca se borra.",
           "**Turno**: nombre, hora de inicio y fin (distintas). Si el fin es menor que el inicio, el turno termina al día siguiente; se permiten turnos que se solapan y huecos.",
           "**Guardar** queda gris hasta que los datos son válidos."],
          [("gs-62-nuevo-empleado", "Nuevo empleado"),
           ("gs-63-nuevo-turno", "Nuevo turno")]),
        P("Horario semanal y asignar turno",
          "Cuadrícula de qué empleados trabajan cada turno cada día, y la forma de asignarlos.",
          ["La cuadrícula cruza turnos con días (L M X J V S D). Debajo, la lista «Asignar turno y días»: tocar un empleado abre una hoja.",
           "Cada empleado tiene **un turno y los días que trabaja**, sin rotaciones. **Guardar** aplica; **Quitar turno** lo desasigna."],
          [("gs-64-horario", "Horario semanal"),
           ("gs-65-asignar-turno", "Asignar turno")]),
        P("Más y historial de cortes",
          "Menú con el historial de cortes, los cajeros y el perfil.",
          ["**Historial de cortes**: todos los cortes cerrados, del más reciente al más antiguo, con etiquetas **Ajustado**, **Diferencia** y **Cambio de medidor**. Tocar uno abre su reporte."],
          [("gs-70-mas", "Menú Más"),
           ("gs-71-historial", "Historial de cortes")]),
        P("Reporte de corte (vista del Gerente de Sucursal)",
          "Es el mismo reporte que ve el Gerente General (ver sección 2), sin el botón de ajustar lectura.",
          ["Bombas, consolidado, cuadre, pérdidas y ajustes. Tocar el **?** o las etiquetas explica cada concepto."],
          [("gs-72-reporte-corte", "Encabezado y bombas"),
           ("gs-73-reporte-cuadre", "Cuadre, pérdidas y ajustes"),
           ("gs-74-cuadre-ayuda", "Ayuda del cuadre")]),
        P("Cajeros",
          "Gestión de los cajeros de la sucursal (usuarios que cobran en el POS). Solo aparece si la sucursal tiene tienda.",
          ["Lista de cajeros. El **+** abre «Nuevo cajero»: nombre, correo y contraseña temporal (se crea con rol Cajero en esta sucursal).",
           "Tocar un cajero abre su edición: cambiar correo, activar/desactivar y restablecer contraseña."],
          [("gs-75-cajeros", "Lista"),
           ("gs-76-nuevo-cajero", "Nuevo cajero"),
           ("gs-77-editar-cajero", "Editar cajero")]),
        P("Pantallas del Gerente de Sucursal sin captura",
          "Varias pantallas dependen de escribir datos reales o de acciones permanentes.",
          ["**Resumen y cierre** y **Corte cerrado** (ver arriba).",
           "**Bomba con lecturas escritas** y sus errores de validación; el **cambio de medidor** con datos; **Guardar niveles** con los tres valores.",
           "**Editar o eliminar** una compra o una pérdida (se hace deslizando la fila).",
           "Confirmaciones de **Registrar y vaciar**, **Anular venta** y **Cierre forzado**."],
          sin_captura="Escribir texto en los campos de esta sesión no era posible sin pegar valores, y varias de estas acciones cambian datos reales que no se pueden deshacer (cortes, ventas y cajas son inmutables). "
                      "Las descripciones salen del código de la app y de `docs/FLUJO.md`, y la lógica está cubierta por las pruebas automáticas (496 verificaciones)."),
    ]))

# ============================================================================================
SECCIONES.append(dict(
    id="cj", titulo="4. Cajero",
    intro="Cobra en la tienda de su sucursal. Su barra inferior: **Caja · Ventas · Perfil**. "
          "Solo puede tener **una caja abierta** a la vez y **no puede anular ventas** (eso lo hace el Gerente de Sucursal). El pago con tarjeta es **simulado**: la app nunca pide datos de tarjeta.",
    pantallas=[
        P("Caja",
          "Pantalla principal del Cajero: el estado de su caja y el acceso a cobrar y a cerrar.",
          ["Con caja abierta: etiqueta «Caja abierta desde …», **Fondo inicial**, **Vendido** (cantidad de ventas) y **Efectivo según tus ventas** (fondo + ventas en efectivo). El **?** aclara que el cierre oficial compara ese esperado con el efectivo que se cuente.",
           "**Cobrar** abre el POS. **Cerrar caja** abre el cierre."],
          [("cj-10-caja", "Caja abierta"),
           ("cj-11-efectivo-ayuda", "Ayuda del efectivo")]),
        P("Sin caja abierta · Abrir caja",
          "Estado inicial del turno: no se puede cobrar hasta abrir una caja.",
          ["Muestra «No tienes una caja abierta» y **Abrir caja**.",
           "La hoja pide el **fondo inicial en USD** (puede ser 0). **Abrir** queda gris hasta que hay un valor válido. Si ya hay una caja abierta, el servidor responde «Ya tienes una caja abierta.»"],
          [("cj-54-sin-caja", "Sin caja"),
           ("cj-55-abrir-caja", "Hoja «Abrir caja»")],
          nota="No se abrió una caja nueva en la demostración."),
        P("Cobrar · punto de venta (POS)",
          "Catálogo de la tienda y carrito de la venta.",
          ["Búsqueda por nombre y chips de categoría (Todo, Lubricantes, Bebidas, Snacks, …).",
           "Tocar un artículo lo agrega al carrito; con **＋ / −** se cambia la cantidad (entera y sin pasar del stock). Los artículos sin stock aparecen atenuados; los servicios no tienen stock.",
           "La barra de abajo muestra la cantidad de artículos y el total; **Vaciar** limpia el carrito y **Cobrar** abre el cobro. El total es una vista previa: el servidor lo recalcula con los precios del catálogo."],
          [("cj-20-pos", "Catálogo"),
           ("cj-21-pos-bebidas", "Filtro por categoría"),
           ("cj-22-pos-carrito", "Carrito con 2 artículos")]),
        P("Cobro (hoja)",
          "Cierra la venta: se elige cómo paga el cliente.",
          ["**Efectivo**: se escribe el **monto recibido**; el **vuelto** se calcula en pantalla y no se puede pagar con menos del total. **Pago exacto** llena el monto con el total.",
           "**Tarjeta (simulada)**: no se pide ningún dato de tarjeta.",
           "**Pagar** queda gris hasta que el pago es válido."],
          [("cj-23-cobro-efectivo", "Cobro, sin monto"),
           ("cj-24-cobro-listo", "Con pago exacto")],
          nota="El flujo con tarjeta y el de pagar con vuelto o con monto insuficiente no se capturaron; se comportan igual salvo por los campos descritos."),
        P("Pago y ticket",
          "Resultado de la venta.",
          ["Una animación «Procesando el pago…» dura un mínimo de unos 1.6 segundos aunque el servidor responda antes, con el aviso «Pago simulado: no se procesa ningún pago real».",
           "Después aparece **Venta registrada** con el número de ticket, las líneas, total, método, recibido y vuelto. **Nueva venta** vuelve al POS.",
           "Si el servidor rechaza la venta (por ejemplo «Stock insuficiente de …») vuelve al carrito con el mensaje."],
          [("cj-25-pago-animacion", "Procesando"),
           ("cj-26-ticket", "Ticket n.º 53")],
          nota="Esta venta (ticket n.º 53, $2.75) es real y quedó guardada en la sucursal Centro de ejemplo."),
        P("Caja actualizada",
          "Después de una venta, la pantalla Caja ya refleja el nuevo total.",
          ["Pasó de 3 a 4 ventas y de $34.75 a $37.50 de efectivo esperado."],
          [("cj-27-caja-actualizada", "Caja con 4 ventas")]),
        P("Ventas",
          "Lista de los tickets de la caja abierta (solo de este cajero).",
          ["Cada ticket: número, método, hora y total. Tocar uno abre el detalle (líneas, total, recibido y vuelto) en solo lectura.",
           "Un texto aclara: «Pide al Gerente de Sucursal que anule una venta.»"],
          [("cj-30-ventas", "Mis ventas"),
           ("cj-31-detalle-ticket", "Detalle de un ticket")]),
        P("Cerrar caja",
          "Cierre del turno: se cuenta el efectivo y el servidor lo compara con lo esperado.",
          ["Se escribe el **efectivo contado**; el aviso recuerda que después no se pueden anular ventas de esa caja. **Cerrar caja** queda gris hasta tener un valor.",
           "Una ventana pide confirmar: «¿Cerrar la caja? Se comparará el efectivo contado con el esperado.»",
           "El resultado muestra **efectivo esperado, contado y diferencia** (faltante o sobrante). La diferencia es solo un indicador. Después, el Cajero queda sin caja abierta."],
          [("cj-50-cerrar-caja", "Cierre"),
           ("cj-51-cerrar-caja-contado", "Con el efectivo contado"),
           ("cj-52-cerrar-caja-confirmar", "Confirmación"),
           ("cj-53-caja-cerrada", "Resultado: caja cerrada, diferencia $0.00")],
          nota="La caja de la demostración se cerró con efectivo contado igual al esperado ($37.50)."),
        P("Pantallas del Cajero sin captura",
          "Casos que no se grabaron.",
          ["**Pago con tarjeta** y **efectivo con vuelto o con monto insuficiente**.",
           "**Cierre de caja con faltante o sobrante** (en la demostración cerró exacto).",
           "Errores del servidor, como «Stock insuficiente» o «Ya tienes una caja abierta»."],
          sin_captura="Cada venta o cierre real queda guardado de forma permanente en la sucursal de ejemplo; se hizo una venta y un cierre para mostrar el flujo y no se repitieron las variantes."),
    ]))

# ============================================================================================
GLOSARIO = [
    ("Corte", "Cierre de un turno de combustible: lecturas de las 6 bombas, compras, pérdidas y nivel medido de los 3 tanques. Hay 2 por día (Matutino y Vespertino). Un corte cerrado es inmutable."),
    ("Cuadre", "Compara el nivel teórico del tanque (inicial + compras − galones del medidor − pérdidas) con el nivel medido. «Cuadra» si la diferencia es menor al 0.5 % de los galones despachados. Es solo un indicador."),
    ("Estado del tanque", "Crítico: 20 % o menos, o autonomía menor a 2 días. Medio: 50 % o menos, o autonomía menor a 5 días. Óptimo: lo demás. Vale el peor de los dos criterios."),
    ("Autonomía", "Días que dura el combustible al ritmo de venta de los últimos 7 días con cortes cerrados. En sucursales con poco historial no se muestra y el estado usa solo el porcentaje."),
    ("Ajustado", "El Gerente General corrigió una lectura después de cerrar el corte; la original se conserva."),
    ("Cambio de medidor", "Se reemplazó el contador de una manguera durante el corte."),
    ("Contaminación", "Pérdida por descarga en el tanque equivocado, agua u otro problema; la genera «Descarga errónea y vaciado»."),
    ("Forzado", "Caja que el Gerente de Sucursal cerró por el cajero, con el efectivo contado y un motivo."),
    ("Anulada", "Venta anulada por el Gerente de Sucursal mientras su caja seguía abierta; se conserva marcada y se devuelve el stock."),
    ("Stock bajo / Agotado", "El stock llegó al mínimo configurado (o a cero)."),
    ("Inactivo / Inactiva", "Nada se borra: se desactiva y conserva su historial."),
]

CAMPOS = [
    "Los campos numéricos **no aceptan letras, signos negativos ni más de 2 decimales** (las cantidades de tienda, solo enteros). Lo que no cabe se descarta al escribir o pegar.",
    "Los botones de guardar se mantienen **grises hasta que el formulario es válido**; los errores del servidor aparecen en rojo con su mensaje exacto y se quitan al volver a escribir.",
    "Las pantallas con datos tienen cuatro estados: **cargando**, **vacío** (con un texto útil), **error** (con «Reintentar») y **contenido**. Si una recarga falla, se conservan los datos anteriores.",
    "Casi toda captura de datos se hace en **hojas** que suben desde abajo (se cierran con la X) y los datos importantes tienen un **?** que abre un globo de ayuda.",
    "Las **etiquetas de color** (Forzado, Ajustado, Crítico, Cuadra…) se pueden tocar para ver qué significan.",
    "Unidades: **galones** y **dólares (USD)**. La app no calcula cuadres ni precios: los resuelve el servidor (Supabase), salvo vistas previas como el total del carrito.",
]

ANEXO_SIN_CAPTURA = [
    ("Recuperar contraseña (pasos 2 y 3) y Cambio obligatorio", "Los hace la usuaria directamente: implican escribir un correo, un código de verificación y contraseñas. Descritos desde el código."),
    ("Resumen y cierre del corte, ventana de confirmación y Corte cerrado", "Exigen guardar las 6 bombas y los 3 niveles con datos reales y terminan en una acción **permanente** (cerrar el corte). No se ejecutó. Descritos desde el código."),
    ("Bomba con lecturas, cambio de medidor con datos, Guardar niveles con valores", "Habría que teclear lecturas reales en un corte real en curso. Se capturaron los formularios vacíos. Su validación está cubierta por las pruebas automáticas."),
    ("Editar/eliminar compras y pérdidas, vaciado, anular venta, cierre forzado, ajustar lectura", "Cada una modifica datos reales de forma irreversible o difícil de revertir. Se capturaron los formularios y se describió el efecto."),
    ("Crear usuarios, precios, sucursales o artículos", "Se capturaron los formularios y su validación; no se guardó ninguno. El servidor de usuarios se probó aparte por HTTP."),
    ("Pago con tarjeta, pago con vuelto, cierre de caja con diferencia", "Solo se mostró un flujo de venta y un cierre de caja (ambos reales y permanentes)."),
    ("Un intento de cerrar la caja bloqueado", "Durante la demostración el sistema de permisos de la herramienta bloqueó el último toque de «Cerrar caja»; lo confirmó la usuaria a mano y el resultado quedó capturado (cj-53)."),
]


# --------------------------------------------------------------------------------------------
# Generación
# --------------------------------------------------------------------------------------------

def mini(nombre):
    ruta = os.path.join(MINI, nombre + ".jpg")
    if not os.path.exists(ruta):
        raise SystemExit(f"Falta la miniatura {ruta}")
    return ruta


def md_img_tabla(imgs):
    """Tablas de hasta 3 capturas por fila para que se lean bien en Markdown."""
    if not imgs:
        return ""
    bloques = []
    for i in range(0, len(imgs), 3):
        g = imgs[i:i + 3]
        bloques.append("| " + " | ".join(f"![{pie}](capturas/mini/{a}.jpg)" for a, pie in g) + " |\n"
                       + "|" + "|".join(["---"] * len(g)) + "|\n"
                       + "| " + " | ".join(f"*{pie}*" for _, pie in g) + " |\n")
    return "\n".join(bloques)


def generar_md():
    o = []
    o.append("# Guía de pantallas de la app\n")
    o.append("Qué hace cada pantalla de la app iOS de **Gasolineras 76**, para qué sirve y cómo funciona, con capturas, "
             "para los tres roles: **Gerente General**, **Gerente de Sucursal** y **Cajero**.\n")
    o.append("> Capturas tomadas el 2026-10-04 en el simulador iPhone 17, contra el servidor real. Los datos de las sucursales Centro, "
             "Santa Ana y Aeropuerto son **datos de ejemplo**; los de Metrocentro son pruebas de la usuaria. "
             "Hay un video por rol en `docs/video/`.\n")
    o.append("## Contenido\n")
    for s in SECCIONES:
        o.append(f"- [{s['titulo']}](#{slug(s['titulo'])})")
    o.append("- [5. Cómo se lee la app (conceptos comunes)](#5-cómo-se-lee-la-app-conceptos-comunes)")
    o.append("- [6. Lo que no se pudo capturar](#6-lo-que-no-se-pudo-capturar)\n")
    for s in SECCIONES:
        o.append(f"## {s['titulo']}\n")
        o.append(s["intro"] + "\n")
        for p in s["pantallas"]:
            o.append(f"### {p['titulo']}\n")
            o.append(md_img_tabla(p["imgs"]))
            o.append(f"**Qué es y para qué sirve.** {p['que']}\n")
            o.append("**Cómo funciona.**\n")
            o.extend(f"- {c}" for c in p["como"])
            o.append("")
            if p["nota"]:
                o.append(f"> Nota: {p['nota']}\n")
            if p["sin_captura"]:
                o.append(f"> 📷 **Sin captura.** {p['sin_captura']}\n")
    o.append("## 5. Cómo se lee la app (conceptos comunes)\n")
    o.extend(f"- {c}" for c in CAMPOS)
    o.append("\n### Glosario\n")
    o.append("| Término | Qué significa |\n|---|---|")
    o.extend(f"| **{t}** | {d} |" for t, d in GLOSARIO)
    o.append("\n## 6. Lo que no se pudo capturar\n")
    o.append("Estas pantallas están descritas arriba a partir del código, pero **no tienen captura ni salen en los videos**, por los motivos indicados.\n")
    o.append("| Pantalla o acción | Por qué no se capturó |\n|---|---|")
    o.extend(f"| {a} | {b} |" for a, b in ANEXO_SIN_CAPTURA)
    o.append("\n> Dos capturas del Panel y tres de «Tienda y cajas» (`gg-10`, `gg-10b`, `gg-54` a `gg-56`) muestran el nombre antiguo de la pestaña de periodo («Personalizado»); la app actual dice «Fechas». "
             "Conviene recapturarlas con la sesión del Gerente General.\n")
    return "\n".join(o)


def slug(t):
    t = t.lower().strip()
    t = re.sub(r"[^\w\s-]", "", t, flags=re.UNICODE)
    return re.sub(r"\s+", "-", t)


def inline(t):
    t = html.escape(t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"`(.+?)`", r"<code>\1</code>", t)
    return t


def data_uri(nombre):
    with open(mini(nombre), "rb") as f:
        return "data:image/jpeg;base64," + base64.b64encode(f.read()).decode()


CSS = """
:root{--bg:#f4f5f8;--card:#fff;--ink:#1b2430;--muted:#5d6877;--brand:#ef6c1a;--navy:#14284b;--line:#e1e5ec;--note:#fff7ee;--cam:#eef2fb}
@media (prefers-color-scheme:dark){:root{--bg:#10141b;--card:#1a212c;--ink:#e8edf5;--muted:#9aa6b6;--brand:#ff8a3d;--navy:#9db8ee;--line:#2a3441;--note:#2a2018;--cam:#1c2638}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
header{padding:32px 16px 8px;max-width:1100px;margin:0 auto}
h1{margin:0 0 8px;font-size:2rem;color:var(--navy)}
main{max-width:1100px;margin:0 auto;padding:0 16px 60px}
nav{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:12px 18px;margin:16px 0}
nav a{color:var(--brand);text-decoration:none;display:block;padding:3px 0}
h2{margin:44px 0 6px;font-size:1.5rem;color:var(--navy);border-bottom:2px solid var(--brand);padding-bottom:6px}
.intro{color:var(--muted);margin:0 0 18px}
.pantalla{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:18px;margin:18px 0}
.pantalla h3{margin:0 0 12px;font-size:1.2rem}
.fotos{display:flex;gap:14px;overflow-x:auto;padding-bottom:10px;margin-bottom:8px}
figure{margin:0;flex:0 0 auto;width:210px}
figure img{width:100%;border-radius:18px;border:1px solid var(--line);display:block}
figcaption{font-size:.78rem;color:var(--muted);text-align:center;margin-top:6px}
.etq{font-weight:700;color:var(--brand)}
ul{margin:6px 0 4px;padding-left:20px}li{margin:4px 0}
.nota,.sin{border-radius:10px;padding:10px 14px;margin-top:10px;font-size:.92rem}
.nota{background:var(--note);border-left:4px solid var(--brand)}
.sin{background:var(--cam);border-left:4px solid var(--navy)}
table{width:100%;border-collapse:collapse;background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden}
th,td{padding:9px 12px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
th{background:var(--cam)}
code{background:var(--cam);padding:1px 5px;border-radius:5px;font-size:.9em}
@media (min-width:760px){.cuerpo{display:block}}
"""


def generar_html():
    o = ["<!doctype html><html lang='es'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
         "<title>Guía de pantallas</title><style>" + CSS + "</style></head><body>",
         "<header><h1>Guía de pantallas de la app</h1>",
         "<p class='intro'>Qué hace cada pantalla de la app iOS de <strong>Gasolineras 76</strong>, para qué sirve y cómo funciona, con capturas, para los tres roles: "
         "Gerente General, Gerente de Sucursal y Cajero. Capturas del 2026-10-04 en el simulador iPhone 17 contra el servidor real. "
         "Centro, Santa Ana y Aeropuerto son datos de ejemplo; Metrocentro son pruebas de la usuaria.</p></header><main>"]
    o.append("<nav><strong>Contenido</strong>")
    for s in SECCIONES:
        o.append(f"<a href='#{s['id']}'>{html.escape(s['titulo'])}</a>")
    o.append("<a href='#conceptos'>5. Cómo se lee la app</a><a href='#sin-captura'>6. Lo que no se pudo capturar</a></nav>")
    for s in SECCIONES:
        o.append(f"<h2 id='{s['id']}'>{html.escape(s['titulo'])}</h2><p class='intro'>{inline(s['intro'])}</p>")
        for p in s["pantallas"]:
            o.append("<section class='pantalla'><h3>" + html.escape(p["titulo"]) + "</h3>")
            if p["imgs"]:
                o.append("<div class='fotos'>")
                for a, pie in p["imgs"]:
                    o.append(f"<figure><img loading='lazy' src='{data_uri(a)}' alt='{html.escape(pie)}'><figcaption>{html.escape(pie)}</figcaption></figure>")
                o.append("</div>")
            o.append(f"<p><span class='etq'>Qué es y para qué sirve.</span> {inline(p['que'])}</p>")
            o.append("<p><span class='etq'>Cómo funciona.</span></p><ul>" + "".join(f"<li>{inline(c)}</li>" for c in p["como"]) + "</ul>")
            if p["nota"]:
                o.append(f"<div class='nota'><strong>Nota:</strong> {inline(p['nota'])}</div>")
            if p["sin_captura"]:
                o.append(f"<div class='sin'>📷 <strong>Sin captura.</strong> {inline(p['sin_captura'])}</div>")
            o.append("</section>")
    o.append("<h2 id='conceptos'>5. Cómo se lee la app (conceptos comunes)</h2><ul>" + "".join(f"<li>{inline(c)}</li>" for c in CAMPOS) + "</ul>")
    o.append("<h3>Glosario</h3><table><tr><th>Término</th><th>Qué significa</th></tr>" +
             "".join(f"<tr><td><strong>{html.escape(t)}</strong></td><td>{inline(d)}</td></tr>" for t, d in GLOSARIO) + "</table>")
    o.append("<h2 id='sin-captura'>6. Lo que no se pudo capturar</h2><p class='intro'>Descritas arriba a partir del código, pero sin captura ni video, por estos motivos.</p>")
    o.append("<table><tr><th>Pantalla o acción</th><th>Por qué no se capturó</th></tr>" +
             "".join(f"<tr><td>{inline(a)}</td><td>{inline(b)}</td></tr>" for a, b in ANEXO_SIN_CAPTURA) + "</table>")
    o.append("<div class='nota' style='margin-top:18px'><strong>Nota:</strong> dos capturas del Panel y tres de «Tienda y cajas» muestran el nombre antiguo de la pestaña de periodo («Personalizado»); "
             "la app actual dice «Fechas».</div>")
    o.append("</main></body></html>")
    return "".join(o)


if __name__ == "__main__":
    ruta_md = os.path.join(RAIZ, "docs", "PANTALLAS.md")
    ruta_html = os.path.join(RAIZ, "docs", "PANTALLAS.html")
    with open(ruta_md, "w", encoding="utf-8") as f:
        f.write(generar_md())
    with open(ruta_html, "w", encoding="utf-8") as f:
        f.write(generar_html())
    n = sum(len(s["pantallas"]) for s in SECCIONES)
    print(f"{n} pantallas → {ruta_md} y {ruta_html} ({os.path.getsize(ruta_html)//1024} KB)")
