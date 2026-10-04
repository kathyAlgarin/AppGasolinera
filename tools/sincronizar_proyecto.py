#!/usr/bin/env python3
"""Registra en App76.xcodeproj todos los .swift de App76/ (grupos incluidos) y la dependencia supabase-swift.

Úsalo después de agregar o borrar archivos .swift:   python3 tools/sincronizar_proyecto.py
Es idempotente: los identificadores salen de la ruta del archivo, así que correrlo dos veces no cambia nada.
Cierra Xcode antes de correrlo (o reabre el proyecto después).
"""
import hashlib
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PBX = RAIZ / "App76.xcodeproj" / "project.pbxproj"
FUENTES = RAIZ / "App76"

GRUPO_APP = "DBB0CBA73068410F00C7BC00"      # grupo "App76"
FASE_SOURCES = "DBB0CBA13068410F00C7BC00"
FASE_FRAMEWORKS = "DBB0CBA23068410F00C7BC00"
TARGET = "DBB0CBA43068410F00C7BC00"
PROYECTO = "DBB0CB9D3068410F00C7BC00"
GRUPOS_FIJOS = {"DBB0CB9C3068410F00C7BC00", "DBB0CBA63068410F00C7BC00", GRUPO_APP, "DBB0CBAE3068411100C7BC00"}
ID_ASSETS = "DBB0CBAC3068411100C7BC00"
ID_PREVIEW = "DBB0CBAE3068411100C7BC00"

ID_PAQUETE = "5A1C0DE0A1B2C3D4E5F60718"
ID_PRODUCTO = "5A1C0DE0A1B2C3D4E5F60719"
ID_BUILD_PRODUCTO = "5A1C0DE0A1B2C3D4E5F6071A"
URL_PAQUETE = "https://github.com/supabase/supabase-swift"


def nuevo_id(texto: str) -> str:
    return hashlib.md5(texto.encode()).hexdigest()[:24].upper()


def main() -> None:
    t = PBX.read_text()

    # 1. Quitar todo lo relacionado con archivos .swift y grupos de código
    t = re.sub(r"^\t\t[0-9A-F]{24} /\* [^*]*\.swift in Sources \*/ = \{isa = PBXBuildFile;.*\n", "", t, flags=re.M)
    t = re.sub(r"^\t\t[0-9A-F]{24} /\* [^*]*\.swift \*/ = \{isa = PBXFileReference;.*\n", "", t, flags=re.M)
    t = re.sub(r"^\t\t\t\t[0-9A-F]{24} /\* [^*]*\.swift in Sources \*/,\n", "", t, flags=re.M)

    def quitar_grupo(m: re.Match) -> str:
        return m.group(0) if m.group(1) in GRUPOS_FIJOS else ""

    t = re.sub(r"^\t\t([0-9A-F]{24}) /\* [^*]* \*/ = \{\n\t\t\tisa = PBXGroup;.*?\n\t\t\};\n",
               quitar_grupo, t, flags=re.M | re.S)

    # 2. Generar desde el disco
    archivos = sorted(p.relative_to(FUENTES) for p in FUENTES.rglob("*.swift"))
    carpetas = {Path(".")}
    for a in archivos:
        for padre in a.parents:
            carpetas.add(padre)

    def id_grupo(c: Path) -> str:
        return GRUPO_APP if c == Path(".") else nuevo_id("grupo:" + c.as_posix())

    refs, builds, sources, grupos = [], [], [], []
    for a in archivos:
        ref, build = nuevo_id("ref:" + a.as_posix()), nuevo_id("build:" + a.as_posix())
        refs.append(f'\t\t{ref} /* {a.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
                    f'path = {a.name}; sourceTree = "<group>"; }};\n')
        builds.append(f'\t\t{build} /* {a.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {a.name} */; }};\n')
        sources.append(f'\t\t\t\t{build} /* {a.name} in Sources */,\n')

    for c in sorted(carpetas, key=lambda p: p.as_posix()):
        if c == Path("."):
            continue  # el grupo raíz se reescribe aparte
        hijos = [f"{id_grupo(s)} /* {s.name} */" for s in sorted(carpetas) if s != Path(".") and s.parent == c]
        hijos += [f"{nuevo_id('ref:' + a.as_posix())} /* {a.name} */" for a in archivos if a.parent == c]
        cuerpo = "".join(f"\t\t\t\t{h},\n" for h in hijos)
        grupos.append(f'\t\t{id_grupo(c)} /* {c.name} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{cuerpo}'
                      f'\t\t\t);\n\t\t\tpath = {c.name};\n\t\t\tsourceTree = "<group>";\n\t\t}};\n')

    raiz_hijos = [f"{ID_ASSETS} /* Assets.xcassets */", f"{ID_PREVIEW} /* Preview Content */"]
    raiz_hijos += [f"{id_grupo(s)} /* {s.name} */" for s in sorted(carpetas) if s != Path(".") and s.parent == Path(".")]
    raiz_hijos += [f"{nuevo_id('ref:' + a.as_posix())} /* {a.name} */" for a in archivos if a.parent == Path(".")]
    cuerpo_raiz = "".join(f"\t\t\t\t{h},\n" for h in raiz_hijos)
    t, n = re.subn(rf"(\t\t{GRUPO_APP} /\* App76 \*/ = \{{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n).*?(\t\t\t\);)",
                   lambda m: m.group(1) + cuerpo_raiz + m.group(2), t, flags=re.S)
    if n != 1:
        sys.exit("No encontré el grupo App76 en el proyecto.")

    t = t.replace("/* End PBXBuildFile section */", "".join(builds) + "/* End PBXBuildFile section */")
    t = t.replace("/* End PBXFileReference section */", "".join(refs) + "/* End PBXFileReference section */")
    t = t.replace("/* End PBXGroup section */", "".join(grupos) + "/* End PBXGroup section */")
    t = re.sub(rf"(\t\t{FASE_SOURCES} /\* Sources \*/ = \{{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \(\n)",
               lambda m: m.group(1) + "".join(sources), t)

    # 3. Dependencia supabase-swift (solo si falta)
    if "XCRemoteSwiftPackageReference" not in t:
        t = t.replace("/* Begin PBXBuildFile section */\n",
                      f"/* Begin PBXBuildFile section */\n\t\t{ID_BUILD_PRODUCTO} /* Supabase in Frameworks */ = "
                      f"{{isa = PBXBuildFile; productRef = {ID_PRODUCTO} /* Supabase */; }};\n")
        t = re.sub(rf"(\t\t{FASE_FRAMEWORKS} /\* Frameworks \*/ = \{{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \(\n)",
                   lambda m: m.group(1) + f"\t\t\t\t{ID_BUILD_PRODUCTO} /* Supabase in Frameworks */,\n", t)
        t = re.sub(rf"(\t\t{TARGET} /\* App76 \*/ = \{{.*?\t\t\tname = App76;\n)",
                   lambda m: m.group(1) + f"\t\t\tpackageProductDependencies = (\n\t\t\t\t{ID_PRODUCTO} /* Supabase */,\n\t\t\t);\n",
                   t, count=1, flags=re.S)
        t = re.sub(rf"(\t\t{PROYECTO} /\* Project object \*/ = \{{.*?\t\t\tmainGroup = [0-9A-F]+;\n)",
                   lambda m: m.group(1) + f"\t\t\tpackageReferences = (\n\t\t\t\t{ID_PAQUETE} /* XCRemoteSwiftPackageReference \"supabase-swift\" */,\n\t\t\t);\n",
                   t, count=1, flags=re.S)
        seccion = (
            "\n/* Begin XCRemoteSwiftPackageReference section */\n"
            f'\t\t{ID_PAQUETE} /* XCRemoteSwiftPackageReference "supabase-swift" */ = {{\n'
            "\t\t\tisa = XCRemoteSwiftPackageReference;\n"
            f'\t\t\trepositoryURL = "{URL_PAQUETE}";\n'
            "\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 2.0.0;\n\t\t\t};\n"
            "\t\t};\n/* End XCRemoteSwiftPackageReference section */\n"
            "\n/* Begin XCSwiftPackageProductDependency section */\n"
            f"\t\t{ID_PRODUCTO} /* Supabase */ = {{\n\t\t\tisa = XCSwiftPackageProductDependency;\n"
            f"\t\t\tpackage = {ID_PAQUETE} /* XCRemoteSwiftPackageReference \"supabase-swift\" */;\n"
            "\t\t\tproductName = Supabase;\n\t\t};\n/* End XCSwiftPackageProductDependency section */\n"
        )
        t = t.replace("/* End XCConfigurationList section */\n", "/* End XCConfigurationList section */\n" + seccion)
        if "XCRemoteSwiftPackageReference section" not in t:
            sys.exit("No pude insertar la sección de paquetes.")

    PBX.write_text(t)
    print(f"Registrados {len(archivos)} archivos .swift y {len(carpetas) - 1} grupos.")


if __name__ == "__main__":
    main()
