#!/bin/bash
# Compila y corre las pruebas de lógica (modelos, validadores y ViewModels) en macOS, sin Xcode ni simulador.
# Solo entran los archivos que dependen únicamente de Foundation; los servicios y las vistas se prueban compilando la app.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SALIDA="${TMPDIR:-/tmp}/pruebas_app76"
mkdir -p "$SALIDA"
swiftc -o "$SALIDA/pruebas" \
  "$RAIZ"/App76/Core/{Fechas,Decodificador,Validadores,Formateadores,ErrorApp}.swift \
  "$RAIZ"/App76/Models/*.swift \
  $(find "$RAIZ/App76/ViewModels" -name '*.swift' ! -name 'ArranqueViewModel.swift') \
  $(find "$RAIZ/App76/Services" -name 'Protocolo*.swift' 2>/dev/null) \
  "$RAIZ"/Pruebas/Marco.swift "$RAIZ"/Pruebas/Pruebas*.swift "$RAIZ"/Pruebas/Falsos*.swift "$RAIZ"/Pruebas/main.swift
cd "$RAIZ" && "$SALIDA/pruebas"
