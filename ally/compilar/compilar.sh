#!/usr/bin/env bash
# EN: Builds the game for Windows (the ROG Ally) on Linux or macOS with Docker.
# ES: Compila el juego para Windows (la ROG Ally) desde Linux o macOS con Docker.
#
#   ally/compilar/compilar.sh <your-game.nup> <output folder> [more nx2/make_game.py options]
#   ally/compilar/compilar.sh <tu-juego.nup> <carpeta de salida> [más opciones de nx2/make_game.py]
#
# EN: Example: ally/compilar/compilar.sh ~/game/my-copy.nup ~/LongshotAlly
#     To only check that your copy is the right version, without building, add --check at the end.
# ES: Ejemplo: ally/compilar/compilar.sh ~/juego/mi-copia.nup ~/LongshotAlly
#     Para solo comprobar que tu copia es la versión correcta, sin compilar, añade --check al final.
#
# Options / Opciones (environment variables / variables de entorno):
#   RX_MARCH       EN: the CPU to build for. Default: znver4 (Ryzen Z1, Z1 Extreme and Z2 Extreme; for a Zen 2 or Zen 3 chip use x86-64-v3).
#                  ES: la CPU de destino. Por defecto: znver4 (Ryzen Z1, Z1 Extreme y Z2 Extreme; para un chip Zen 2 o Zen 3 usa x86-64-v3).
#   LONGSHOT_JOBS  EN: compilers in parallel (default: one per thread, as memory allows).
#                  ES: compiladores en paralelo (por defecto, uno por hilo según la memoria libre).
#   DOCKER_MEM     EN: the container's memory, e.g. 32g.   ES: memoria del contenedor, p. ej. 32g.
#   TOOLS          EN: where llvm-mingw and cpm are kept (default ~/.cache/longshot-ally-tools).
#                  ES: dónde se guardan llvm-mingw y cpm (por defecto ~/.cache/longshot-ally-tools).
#   WORK           EN: the work folder (default <output>-work); keep it, the next build is faster.
#                  ES: la carpeta de trabajo (por defecto <salida>-work); consérvala, la siguiente compilación es más rápida.
set -euo pipefail

if [ $# -lt 2 ]; then
    sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi

REPO=$(cd "$(dirname "$0")/../.." && pwd)
[ -f "$1" ] || { echo "Not found / No existe: $1" >&2; exit 1; }
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

# llvm-mingw for Linux x86-64 (the compiler that makes the Windows .exe) / el compilador que genera el .exe de Windows
LLVM_VER=20261104
LLVM_NAME=llvm-mingw-$LLVM_VER-ucrt-ubuntu-22.04-x86_64
LLVM_SHA=919380403de87dca3c581c2053230cd298af5e891286628ba0613b7fed370926
if [ ! -x "$TOOLS/llvm-mingw/bin/clang" ]; then
    echo "== llvm-mingw: $LLVM_NAME"
    curl -fL --retry 3 -o "$TOOLS/llvm-mingw.tar.xz" \
        "https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_VER/$LLVM_NAME.tar.xz"
    [ "$(sha256_of "$TOOLS/llvm-mingw.tar.xz")" = "$LLVM_SHA" ] || { echo "llvm-mingw: wrong SHA-256 / SHA-256 incorrecto" >&2; exit 1; }
    rm -rf "$TOOLS/llvm-mingw" "$TOOLS/$LLVM_NAME"
    tar -xJf "$TOOLS/llvm-mingw.tar.xz" -C "$TOOLS"
    mv "$TOOLS/$LLVM_NAME" "$TOOLS/llvm-mingw"
    rm -f "$TOOLS/llvm-mingw.tar.xz"
fi

# cpm for Windows (Vulkan, SPIR-V and VMA headers, FFmpeg): the package Longshot's tools.lock pins
# cpm para Windows (cabeceras de Vulkan, SPIR-V y VMA, y FFmpeg): el paquete que fija tools.lock de Longshot
CPM_SHA=4eeae3a8d50118dd5c15f2c18dcdc452fbf1dfafceeffcad3bca97aadffe829b
CPM_URLS="https://git-cdn.magicbean.dev/api/packages/MagicBeanDev/generic/cpm-windows-x64/hookshot-v2.1.0-dav1d-1.5.4/$CPM_SHA-cpm.zip
https://git.magicbean.dev/api/packages/MagicBeanDev/generic/cpm-windows-x64/hookshot-v2.1.0-dav1d-1.5.4/$CPM_SHA-cpm.zip"
if [ ! -d "$TOOLS/cpm/vulkanheaders" ]; then
    echo "== cpm"
    ok=
    for u in $CPM_URLS; do
        if curl -fL --retry 2 -o "$TOOLS/cpm.zip" "$u"; then ok=1; break; fi
    done
    [ -n "$ok" ] || { echo "cpm: download failed / no se pudo descargar" >&2; exit 1; }
    [ "$(sha256_of "$TOOLS/cpm.zip")" = "$CPM_SHA" ] || { echo "cpm: wrong SHA-256 / SHA-256 incorrecto" >&2; exit 1; }
    rm -rf "$TOOLS/cpm" "$TOOLS/cpm.tmp"
    mkdir -p "$TOOLS/cpm.tmp"
    unzip -q "$TOOLS/cpm.zip" -d "$TOOLS/cpm.tmp"
    mv "$TOOLS/cpm.tmp/cpm" "$TOOLS/cpm"
    rm -rf "$TOOLS/cpm.tmp" "$TOOLS/cpm.zip"
fi

echo "== Docker image / imagen de Docker"
docker build --platform linux/amd64 -q -t "$IMAGE" -f "$REPO/ally/compilar/Dockerfile" "$REPO" >/dev/null

MARCH=${RX_MARCH:-znver4}
# (both names are set: LONGSHOT_* for Longshot, HOOKSHOT_* for Hookshot; each ignores the other's)
ENVS=(-e RX_TARGET=windows -e RX_MARCH="$MARCH" -e RX_CPM=/b/tools/cpm
      -e LONGSHOT_MINGW=/b/tools/llvm-mingw -e HOOKSHOT_MINGW=/b/tools/llvm-mingw)
[ -n "${LONGSHOT_JOBS:-}" ] && ENVS+=(-e LONGSHOT_JOBS="$LONGSHOT_JOBS" -e HOOKSHOT_JOBS="$LONGSHOT_JOBS")
echo "== building for Windows / compilando para Windows (RX_MARCH=$MARCH): $NUP_NAME -> $OUT"
docker run --rm --platform linux/amd64 ${DOCKER_MEM:+--memory "$DOCKER_MEM"} \
    -v "$REPO":/b/src -v "$NUP_DIR":/b/dump:ro -v "$OUT":/b/out -v "$WORK":/b/work -v "$TOOLS":/b/tools \
    "${ENVS[@]}" -w /b/src "$IMAGE" \
    python3 -I nx2/make_game.py --nup "/b/dump/$NUP_NAME" --work /b/work --out /b/out "$@"
echo "== done / listo: $OUT"
