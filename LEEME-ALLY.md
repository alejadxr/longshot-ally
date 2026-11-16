# Longshot para la ROG Ally

Fork no oficial de [Longshot](https://git.magicbean.dev/MagicBeanDev/Longshot) (la continuación de Hookshot) con parches y
ajustes para jugar en una **ROG Ally (Ryzen Z1 Extreme, 16 GB, Windows 11)**. Todo lo de aquí se midió en una Ally RC71L.

> **No incluye el juego.** Aquí no hay archivos del juego, ni claves de consola, ni shaders, ni cachés, ni partidas. Para
> compilar necesitas tu propia copia del juego sacada de tu consola, en la versión que soporta Longshot (la indica
> [README.md](README.md), en el apartado de requisitos).

## Los dos forks

| Repositorio | Base | Estado |
|---|---|---|
| **longshot-ally** (este) | Longshot `bbe7a07` + los parches de la Ally | Compila sin errores. **Todavía no se ha probado jugando en la Ally.** |
| [**hookshot-ally**](https://github.com/alejadxr/hookshot-ally) | Hookshot `15646d1` + los parches v5 | Es la versión que se juega a diario en la Ally. |

Los dos llevan los mismos parches y esta guía vale para ambos; las diferencias de Hookshot están en su `LEEME-ALLY.md`.

En este repositorio:

- `ally/longshot_env.txt`: los ajustes de la Ally.
- `ally/compilar/`: compilar desde Linux o macOS con Docker, como lo compilamos nosotros.
- `ally/windows/`: lanzador con prioridad alta y ajustes del registro.
- `ally/patches/`: los parches sueltos, para aplicarlos sobre una versión más nueva de Longshot.

Los dos primeros commits separan el código original de lo nuestro: `git show HEAD~1` enseña exactamente los parches. De
Longshot solo se quitó `assets/saves/kokiri-start`, una partida de prueba que el juego no necesita.

## Los parches

| Cambio | Dónde | Cómo se activa | Por qué |
|---|---|---|---|
| Hilos de trabajo a prioridad normal | `gpu/vk/vk_jobs.cpp` | `RX_VK_JOB_PRIO=normal` | Iban a "por debajo de lo normal" y, al entrar en una zona nueva, otros procesos les quitaban CPU. |
| Prioridad de la preparación de shaders | `gpu/vk/vk_draw.cpp` | `RX_VK_PREPARE_PRIO=high` (`above`, `normal`, `below`) | La primera preparación tarda menos. |
| Guardado de la caché de pipelines | `gpu/vk/vk_draw.cpp` | siempre | En juego, el fichero (~900 MB) se reescribía entero unas 15 veces por sesión. Ahora solo cuando creció bastante. |
| Fallback de task/mesh optimizado | `gpu/vk/vk_draw.cpp` | siempre (`RX_VK_FALLBACK_NOOPT=1` lo apaga) | Sin optimizador, en la 780M la geometría costaba ~21 ms de GPU por fotograma. |
| Rehacer la superficie si falla la swapchain | `gpu/vk/vk_main.cpp` | siempre | Al pulsar F11 dos veces la imagen se quedaba congelada (400+ reintentos). |
| Fallback de present en la generación de fotogramas | `gpu/vk/vk_framegen.cpp` | siempre | La pantalla se congelaba mientras el juego seguía (pasó tocando la ocarina). |
| Giroscopio de la Ally a 10 ms | `host/hos_imu_rate.c` | siempre (solo Windows) | Windows solo mandaba lecturas del sensor Bosch al pasar un umbral: al apuntar despacio se movía a saltos y el juego apagaba el giroscopio cada pocos segundos. |

## 1. Compilar

La compilación lee tu copia del juego y genera la carpeta del juego para Windows. Necesitas espacio libre de sobra (la
carpeta final ocupa ~26 GB, y la de trabajo más).

### Opción A: en Windows (en la propia Ally o en otro PC)

Son los pasos de la documentación de Longshot (README.md, apartado de compilar desde el código), con este repositorio en
vez del oficial:

1. Instala [Python 3](https://www.python.org/downloads/) y [Git](https://git-scm.com/download/win).
2. Clona el repositorio e instala las dependencias de Python:
   ```bat
   git clone <la URL de este repositorio> longshot-ally
   cd longshot-ally
   py -m pip install -r requirements.txt
   ```
3. Descarga `llvm-mingw-20261104-ucrt-x86_64.zip` de
   [mstorsjo/llvm-mingw](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261104) y descomprímelo dentro del clon,
   en una carpeta llamada `llvm-mingw` (tiene que quedar `llvm-mingw\bin\clang.exe`).
4. Descarga el paquete `cpm` para Windows: es la primera URL de la línea `tool cpm ... windows-x64` de `tools.lock`.
   Descomprímelo dentro del clon de forma que quede una carpeta `cpm` (con `vulkanheaders`, `ffmpeg`, etc. dentro).
5. Compila:
   ```bat
   py -I nx2/make_game.py --nup "C:\ruta\a\tu-juego.nup" --out "C:\Games\Longshot"
   ```
   Si compilas en la propia Ally no hace falta nada más (elige la CPU sola). Si compilas en **otro** PC para la Ally, antes
   pon `set RX_MARCH=znver4`.

### Opción B: Linux o macOS con Docker (lo que usamos nosotros)

```sh
git clone <la URL de este repositorio> longshot-ally
cd longshot-ally
ally/compilar/compilar.sh /ruta/a/tu-juego.nup ~/LongshotAlly
```

El script descarga llvm-mingw y `cpm` (comprueba su SHA-256), crea la imagen de Docker y compila para Windows. Más
detalles al principio de [`ally/compilar/compilar.sh`](ally/compilar/compilar.sh):

- `RX_MARCH`: por defecto `znver4`, para Ryzen Z1, Z1 Extreme y Z2 Extreme. **Si tu Ally lleva un chip Zen 2 o Zen 3**
  (por ejemplo la ROG Xbox Ally con Z2 A), usa `RX_MARCH=x86-64-v3`. Si no, el juego se cierra nada más abrirlo.
- `DOCKER_MEM`: la memoria del contenedor. En una Mac Pro con `DOCKER_MEM=44g` y 22 hilos tardó 2 h 09 min.
- Docker Desktop en Mac trae poca memoria por defecto: súbela en sus ajustes.
- En un Mac con Apple Silicon el contenedor corre emulado en x86 y tarda muchísimo más.

## 2. Instalar en la Ally

1. Copia la carpeta de salida entera a la Ally, por ejemplo a `C:\Games\Longshot`.
2. Copia [`ally/longshot_env.txt`](ally/longshot_env.txt) a esa carpeta, junto a `image.bin`. Si el build ya creó un
   `longshot_env.txt`, añade nuestras líneas al final en lugar de sustituirlo.
3. Copia [`ally/windows/lanzar.bat`](ally/windows/lanzar.bat) a la misma carpeta y abre el juego con él. Así arranca con
   prioridad por encima de lo normal.
4. **La primera vez prepara los shaders.** Tarda bastante y es normal. Las siguientes veces arranca rápido.
5. Partidas: al abrir el juego directamente, van en `user\save\` dentro de la carpeta del juego. Para traerlas de
   Hookshot, cierra los dos juegos, haz una copia de la carpeta `user\save` de Hookshot y luego:
   ```bat
   py -I scripts/longshot_saves.py import hookshot --hookshot "C:\Games\Hookshot\user\save"
   ```
   También vale copiar la carpeta `user\save` de Hookshot a la de Longshot: el formato es el mismo (docs/saves.md).

## 3. Ajustes de Windows y de la Ally

Esto es lo que más cambia el rendimiento, más que cualquier parche:

- **Driver AMD de octubre de 2026 (32.0.32015) o más nuevo.** Con el de mayo, los mesh shaders colgaban la GPU al terminar
  la cinemática del principio (DEVICE_LOST). Si tienes que quedarte con un driver viejo, añade
  `RX_VK_TASK_MESH_FALLBACK=1` y quita `RX_VK_MESH_OPT=1` del `longshot_env.txt`.
- **Memoria de GPU en Armoury Crate: 4 GB.** Con 16 GB de RAM, si le das más a la GPU el juego empieza a tirar del disco y
  va a tirones. Con 4 GB, Windows ve ~12 GB.
- **[`ally/windows/ajustes_ally.reg`](ally/windows/ajustes_ally.reg)** (doble clic y reinicia) hace dos cosas:
  - apaga HAGS (la programación de GPU acelerada por hardware), que dio un pantallazo azul `0x119` del driver AMD;
  - sube a 10 s el tiempo que Windows espera antes de reiniciar la GPU.

  `deshacer_ajustes_ally.reg` lo devuelve como estaba.
- **Modo Turbo en Armoury Crate, siempre enchufada.** Con batería la CPU y la GPU bajan a 14–25 W.
- **Si juegas en la tele con un hub USB-C**, la Ally se queda en ~25 W fijos, aunque el perfil diga más. Pon un cargador
  de 65 W o más (mejor 100 W) en el puerto PD del hub.
- **Escritorio de Windows a 1920×1080.** Si está a otra resolución, el juego sale a esa y se estira.
- Cierra la Xbox Game Bar y lo que tengas en segundo plano. La RAM está muy justa.

## 4. Ajustes del menú del juego

Lo que mejor nos fue:

- salida a 1920×1080;
- render al 50–58 % con FSR 3.1;
- generación de fotogramas del juego activada;
- filtrado anisótropo 8x.

La AFMF del driver AMD se nota peor que la generación de fotogramas del juego: déjala apagada.

## 5. Qué rendimiento esperar

Medido con [hookshot-ally](https://github.com/alejadxr/hookshot-ally) y los ajustes de arriba:

- Enchufada en Turbo (30–45 W): 32–37 fps reales en zonas normales y 20–26 en las más cargadas (~2000 draws). La
  generación de fotogramas lo dobla. El límite suele ser la GPU (780M a 2,4–2,6 GHz).
- Con hub y 25 W, a 960×540: 21–36 fps reales.
- Al entrar en una zona nueva hay un tirón corto mientras compila sus pipelines. Es el precio de `RX_VK_PRECOMPILE=0`,
  que ahorra ~7 GB de RAM.

## 6. Lo que probamos y salió peor (no lo uses)

| Ajuste | Qué pasó |
|---|---|
| `RX_VK_VRAM_MB=3072` | DEVICE_LOST y pantallazo azul `0x119` al cargar zonas o partidas. Con 2560 no ha vuelto a pasar. |
| `RX_VK_DRIVER_FAULTS=3` (solo en hookshot-ally) | DEVICE_LOST al cargar la partida. |
| `RX_VK_RECORDER=thread` | El replay de CPU subió a 38 ms. |
| `RX_VK_PER_QUEUE_FENCES=0` + `RX_VK_UPLOAD_BUDGET_MS=8` + `RX_VK_TEX_CAPTURE=0` + `RX_VK_MIRROR_MB=256` | Menos de 1 fps. |
| `RX_VK_UPLOAD_BUDGET_MS=16` | Texturas que parpadean. |
| `RX_VK_IMAGE_BLOCK_MB=64` | No ahorró memoria. |

## Aplicar los parches sobre una versión nueva de Longshot

```sh
git clone https://git.magicbean.dev/MagicBeanDev/Longshot.git
cd Longshot
git apply --3way /ruta/a/este/repo/ally/patches/longshot-ally.diff
```

Si un trozo ya no encaja porque Longshot cambió ese código, `--3way` deja el conflicto marcado en el archivo para
resolverlo a mano.

## Licencia y créditos

GPL-3.0, como Longshot y Hookshot (ver [LICENSE](LICENSE)).

- Longshot es de Team MagicBean y Hookshot de NotRexed y sus colaboradores. Este fork solo añade lo descrito arriba.
- Es un fork no oficial: los problemas de estos parches van aquí, no a Longshot.
