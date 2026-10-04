// Gestión de usuarios: crear, restablecer contraseña y activar/desactivar.
// Usa la clave de administrador de Supabase, que solo existe en el servidor (nunca va en las apps).
// Quién puede qué:
//   Gerente General     -> cualquier usuario (menos él mismo en restablecer/cambiar_estado)
//   Gerente de Sucursal -> solo cajeros de su propia sucursal
//   Cajero              -> nada
import { createClient } from "npm:@supabase/supabase-js@2";

type Rol = "gerente_general" | "gerente_sucursal" | "cajero";
const ROLES: Rol[] = ["gerente_general", "gerente_sucursal", "cajero"];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

class ErrorHttp extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function claveSecreta(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const nuevas = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  return nuevas["default"];
}

const admin = createClient(Deno.env.get("SUPABASE_URL")!, claveSecreta(), {
  auth: { autoRefreshToken: false, persistSession: false },
});

const texto = (v: unknown): string => (typeof v === "string" ? v.trim() : "");

function validarPassword(v: unknown): string {
  if (typeof v !== "string" || v.length < 8 || v.length > 72) {
    throw new ErrorHttp(400, "La contraseña temporal debe tener entre 8 y 72 caracteres.");
  }
  return v;
}

// Traduce errores de la base de datos a mensajes claros (sin filtrar detalles internos)
function errorBD(e: { code?: string; message?: string }, porDefecto: string): ErrorHttp {
  if (e.code === "23505") {
    const m = e.message ?? "";
    if (m.includes("perfiles_un_gerente_activo_uq")) {
      return new ErrorHttp(409, "Esa sucursal ya tiene un Gerente de Sucursal activo.");
    }
    if (m.includes("perfiles_correo_uq")) {
      return new ErrorHttp(409, "Ya existe un usuario con ese correo.");
    }
    return new ErrorHttp(409, "Ya existe un registro igual.");
  }
  // P0001 = reglas propias de la base de datos, ya redactadas en español
  if (e.code === "P0001" && e.message) return new ErrorHttp(400, e.message);
  console.error("Error de base de datos:", e.code, e.message);
  return new ErrorHttp(500, porDefecto);
}

interface Yo {
  id: string;
  rol: Rol;
  sucursal_id: string | null;
}

async function autenticar(req: Request): Promise<Yo> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new ErrorHttp(401, "Falta iniciar sesión.");
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data?.user) throw new ErrorHttp(401, "La sesión no es válida.");

  const { data: perfil } = await admin
    .from("perfiles")
    .select("id, rol, sucursal_id, activo")
    .eq("id", data.user.id)
    .maybeSingle();
  if (!perfil || !perfil.activo) throw new ErrorHttp(403, "Tu usuario no está activo.");
  if (perfil.rol === "cajero") throw new ErrorHttp(403, "No tienes permiso para esta acción.");

  if (perfil.rol === "gerente_sucursal") {
    const { data: suc } = await admin
      .from("sucursales")
      .select("activa")
      .eq("id", perfil.sucursal_id)
      .maybeSingle();
    if (!suc?.activa) throw new ErrorHttp(403, "Tu sucursal está desactivada.");
  }
  return { id: perfil.id, rol: perfil.rol as Rol, sucursal_id: perfil.sucursal_id };
}

async function crear(yo: Yo, b: Record<string, unknown>) {
  const correo = texto(b.correo).toLowerCase();
  const nombre = texto(b.nombre);
  const rol = b.rol as Rol;
  const password = validarPassword(b.password_temporal);

  if (!EMAIL_RE.test(correo) || correo.length > 120) {
    throw new ErrorHttp(400, "El correo no tiene un formato válido.");
  }
  if (nombre.length < 2 || nombre.length > 80) {
    throw new ErrorHttp(400, "El nombre debe tener entre 2 y 80 caracteres.");
  }
  if (!ROLES.includes(rol)) throw new ErrorHttp(400, "El rol no es válido.");

  let sucursalId: string | null = null;
  if (yo.rol === "gerente_sucursal") {
    if (rol !== "cajero") throw new ErrorHttp(403, "Solo puedes crear cajeros de tu sucursal.");
    sucursalId = yo.sucursal_id;
  } else if (rol !== "gerente_general") {
    const s = texto(b.sucursal_id);
    if (!UUID_RE.test(s)) throw new ErrorHttp(400, "Selecciona una sucursal.");
    sucursalId = s;
  }

  if (sucursalId) {
    const { data: suc } = await admin
      .from("sucursales")
      .select("activa, tiene_tienda")
      .eq("id", sucursalId)
      .maybeSingle();
    if (!suc || !suc.activa) throw new ErrorHttp(400, "La sucursal no existe o está desactivada.");
    if (rol === "cajero" && !suc.tiene_tienda) {
      throw new ErrorHttp(400, "Esa sucursal no tiene tienda: no puede tener cajeros.");
    }
    if (rol === "gerente_sucursal") {
      const { count } = await admin
        .from("perfiles")
        .select("id", { count: "exact", head: true })
        .eq("sucursal_id", sucursalId)
        .eq("rol", "gerente_sucursal")
        .eq("activo", true);
      if ((count ?? 0) > 0) {
        throw new ErrorHttp(409, "Esa sucursal ya tiene un Gerente de Sucursal activo.");
      }
    }
  }

  const { data: nuevo, error: e1 } = await admin.auth.admin.createUser({
    email: correo,
    password,
    email_confirm: true,
  });
  if (e1 || !nuevo?.user) {
    if (e1 && /already|registered|exists/i.test(e1.message)) {
      throw new ErrorHttp(409, "Ya existe un usuario con ese correo.");
    }
    console.error("No se pudo crear el usuario de autenticación:", e1?.message);
    throw new ErrorHttp(500, "No se pudo crear el usuario.");
  }

  const { error: e2 } = await admin.from("perfiles").insert({
    id: nuevo.user.id,
    correo,
    nombre,
    rol,
    sucursal_id: sucursalId,
    debe_cambiar_password: true,
  });
  if (e2) {
    // Deshacer: que no quede un usuario de autenticación sin perfil
    await admin.auth.admin.deleteUser(nuevo.user.id);
    throw errorBD(e2, "No se pudo crear el perfil del usuario.");
  }
  return { id: nuevo.user.id };
}

// Usuario sobre el que se actúa, con las reglas de permiso
async function objetivo(yo: Yo, idCrudo: unknown) {
  const id = texto(idCrudo);
  if (!UUID_RE.test(id)) throw new ErrorHttp(400, "El usuario no es válido.");
  if (id === yo.id) throw new ErrorHttp(400, "No puedes hacer esto sobre tu propio usuario.");
  const { data: t } = await admin
    .from("perfiles")
    .select("id, rol, sucursal_id, activo")
    .eq("id", id)
    .maybeSingle();
  if (!t) throw new ErrorHttp(404, "No se encontró el usuario.");
  if (yo.rol === "gerente_sucursal" && !(t.rol === "cajero" && t.sucursal_id === yo.sucursal_id)) {
    throw new ErrorHttp(403, "Solo puedes administrar cajeros de tu sucursal.");
  }
  return t;
}

async function restablecerPassword(yo: Yo, b: Record<string, unknown>) {
  const password = validarPassword(b.password_temporal);
  const t = await objetivo(yo, b.usuario_id);

  const { error: e1 } = await admin.auth.admin.updateUserById(t.id, { password });
  if (e1) {
    console.error("No se pudo cambiar la contraseña:", e1.message);
    throw new ErrorHttp(500, "No se pudo restablecer la contraseña.");
  }
  const { error: e2 } = await admin
    .from("perfiles")
    .update({ debe_cambiar_password: true })
    .eq("id", t.id);
  if (e2) throw errorBD(e2, "La contraseña cambió, pero no se pudo marcar el cambio obligatorio.");
  return { ok: true };
}

async function cambiarEstado(yo: Yo, b: Record<string, unknown>) {
  if (typeof b.activo !== "boolean") throw new ErrorHttp(400, "Indica si el usuario queda activo.");
  const activo = b.activo;
  const t = await objetivo(yo, b.usuario_id);
  if (t.activo === activo) return { ok: true };

  const { error: e1 } = await admin.from("perfiles").update({ activo }).eq("id", t.id);
  if (e1) throw errorBD(e1, "No se pudo cambiar el estado del usuario.");

  // Además de la base de datos, se bloquea el inicio de sesión
  const { error: e2 } = await admin.auth.admin.updateUserById(t.id, {
    ban_duration: activo ? "none" : "876000h",
  });
  if (e2) {
    await admin.from("perfiles").update({ activo: t.activo }).eq("id", t.id); // revertir
    console.error("No se pudo bloquear/desbloquear el inicio de sesión:", e2.message);
    throw new ErrorHttp(500, "No se pudo cambiar el estado del usuario.");
  }
  return { ok: true };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "Método no permitido." });

  try {
    const yo = await autenticar(req);

    let cuerpo: Record<string, unknown>;
    try {
      cuerpo = await req.json();
    } catch {
      throw new ErrorHttp(400, "El cuerpo de la petición no es JSON válido.");
    }

    switch (cuerpo.accion) {
      case "crear":
        return json(201, await crear(yo, cuerpo));
      case "restablecer_password":
        return json(200, await restablecerPassword(yo, cuerpo));
      case "cambiar_estado":
        return json(200, await cambiarEstado(yo, cuerpo));
      default:
        throw new ErrorHttp(400, "Acción no válida.");
    }
  } catch (e) {
    if (e instanceof ErrorHttp) return json(e.status, { error: e.message });
    console.error("Error inesperado:", e instanceof Error ? e.message : e);
    return json(500, { error: "Ocurrió un error inesperado." });
  }
});
