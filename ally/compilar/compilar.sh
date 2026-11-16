#!/usr/bin/env bash
# Compila el juego para Windows (la ROG Ally) desde Linux o macOS con Docker.
#
#   ally/compilar/compilar.sh <tu-juego.nup> <carpeta de salida> [más opciones de nx2/make_game.py]
#
# Ejemplo: ally/compilar/compilar.sh ~/juego/mi-copia.nup ~/LongshotAlly
# Solo comprobar que tu copia es la versión correcta, sin compilar: añade --check al final.
#
# Variables opcionales:
#   RX_MARCH       CPU de destino. Por defecto znver4 (Ryzen Z1, Z1 Extreme y Z2 Extreme).
#                  Para un chip Zen 2 o Zen 3 (por ejemplo la ROG Xbox Ally con Z2 A) usa RX_MARCH=x86-64-v3.
#   LONGSHOT_JOBS  compiladores en paralelo (por defecto, uno por hilo según la memoria libre).
#   DOCKER_MEM     memoria del contenedor, por ejemplo 32g (por defecto, la que deje Docker).
#   TOOLS          dónde se guardan llvm-mingw y cpm (por defecto ~/.cache/longshot-ally-tools).
#   WORK           carpeta de trabajo (por defecto <salida>-work). Consérvala: la siguiente compilación es más rápida.
set -euo pipefail

if [ $# -lt 2 ]; then
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi

REPO=$(cd "$(dirname "$0")/../.." && pwd)
[ -f "$1" ] || { echo "No existe: $1" >&2; exit 1; }
NUP_DIR=$(cd "$(dirname "$1")" && pwd)
NUP_NAME=$(basename "$1")
mkdir -p "$2"
OUT=$(cd "$2" && pwd)
shift 2
WORK=${WORK:-$OUT-work}
TOOLS=${TOOLS:-$HOME/.cache/longshot-ally-tools}
mkdir -p "$WORK" "$TOOLS"
IMAGE=longshot-ally-cross

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# llvm-mingw para Linux x86-64 (el compilador que genera el .exe de Windows)
LLVM_VER=20261104
LLVM_NAME=llvm-mingw-$LLVM_VER-ucrt-ubuntu-22.04-x86_64
LLVM_SHA=919380403de87dca3c581c2053230cd298af5e891286628ba0613b7fed370926
if [ ! -x "$TOOLS/llvm-mingw/bin/clang" ]; then
    echo "== descargando $LLVM_NAME"
    curl -fL --retry 3 -o "$TOOLS/llvm-mingw.tar.xz" \
        "https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_VER/$LLVM_NAME.tar.xz"
    [ "$(sha256_of "$TOOLS/llvm-mingw.tar.xz")" = "$LLVM_SHA" ] || { echo "llvm-mingw: SHA-256 incorrecto" >&2; exit 1; }
    rm -rf "$TOOLS/llvm-mingw" "$TOOLS/$LLVM_NAME"
    tar -xJf "$TOOLS/llvm-mingw.tar.xz" -C "$TOOLS"
    mv "$TOOLS/$LLVM_NAME" "$TOOLS/llvm-mingw"
    rm -f "$TOOLS/llvm-mingw.tar.xz"
fi

# cpm para Windows (cabeceras de Vulkan, SPIR-V y VMA, y FFmpeg): el mismo paquete que fija tools.lock de Longshot
CPM_SHA=4eeae3a8d50118dd5c15f2c18dcdc452fbf1dfafceeffcad3bca97aadffe829b
CPM_URLS="https://git-cdn.magicbean.dev/api/packages/MagicBeanDev/generic/cpm-windows-x64/hookshot-v2.1.0-dav1d-1.5.4/$CPM_SHA-cpm.zip
https://git.magicbean.dev/api/packages/MagicBeanDev/generic/cpm-windows-x64/hookshot-v2.1.0-dav1d-1.5.4/$CPM_SHA-cpm.zip"
if [ ! -d "$TOOLS/cpm/vulkanheaders" ]; then
    echo "== descargando cpm"
    ok=
    for u in $CPM_URLS; do
        if curl -fL --retry 2 -o "$TOOLS/cpm.zip" "$u"; then ok=1; break; fi
    done
    [ -n "$ok" ] || { echo "no se pudo descargar cpm" >&2; exit 1; }
    [ "$(sha256_of "$TOOLS/cpm.zip")" = "$CPM_SHA" ] || { echo "cpm: SHA-256 incorrecto" >&2; exit 1; }
    rm -rf "$TOOLS/cpm" "$TOOLS/cpm.tmp"
    mkdir -p "$TOOLS/cpm.tmp"
    unzip -q "$TOOLS/cpm.zip" -d "$TOOLS/cpm.tmp"
    mv "$TOOLS/cpm.tmp/cpm" "$TOOLS/cpm"
    rm -rf "$TOOLS/cpm.tmp" "$TOOLS/cpm.zip"
fi

echo "== imagen de Docker"
docker build --platform linux/amd64 -q -t "$IMAGE" -f "$REPO/ally/compilar/Dockerfile" "$REPO" >/dev/null

MARCH=${RX_MARCH:-znver4}
# (las variables HOOKSHOT_* son para hookshot-ally; Longshot las ignora)
ENVS=(-e RX_TARGET=windows -e RX_MARCH="$MARCH" -e RX_CPM=/b/tools/cpm
      -e LONGSHOT_MINGW=/b/tools/llvm-mingw -e HOOKSHOT_MINGW=/b/tools/llvm-mingw)
[ -n "${LONGSHOT_JOBS:-}" ] && ENVS+=(-e LONGSHOT_JOBS="$LONGSHOT_JOBS" -e HOOKSHOT_JOBS="$LONGSHOT_JOBS")
[ -n "${RX_MTUNE:-}" ] && ENVS+=(-e RX_MTUNE="$RX_MTUNE")
echo "== compilando para Windows (RX_MARCH=$MARCH): $NUP_NAME -> $OUT"
docker run --rm --platform linux/amd64 ${DOCKER_MEM:+--memory "$DOCKER_MEM"} \
    -v "$REPO":/b/src -v "$NUP_DIR":/b/dump:ro -v "$OUT":/b/out -v "$WORK":/b/work -v "$TOOLS":/b/tools \
    "${ENVS[@]}" -w /b/src "$IMAGE" \
    python3 -I nx2/make_game.py --nup "/b/dump/$NUP_NAME" --work /b/work --out /b/out "$@"
echo "== listo: $OUT"
