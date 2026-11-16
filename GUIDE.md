# Longshot for the ROG Ally: guide

**English** · [Español](GUIA.md)

An unofficial fork of [Longshot](https://git.magicbean.dev/MagicBeanDev/Longshot) (the continuation of Hookshot) with
patches and settings for playing on a **ROG Ally (Ryzen Z1 Extreme, 16 GB, Windows 11)**. Everything here was measured on
a ROG Ally RC71L.

> **The game is not included.** This repository has no game files, no console keys, no shaders, no caches and no saves.
> To build it you need your own copy of the game, dumped from your own console.

## Contents

1. [What's in this fork](#1-whats-in-this-fork)
2. [Requirements](#2-requirements)
3. [Quick start](#3-quick-start)
4. [Building](#4-building)
5. [Installing on the Ally](#5-installing-on-the-ally)
6. [The settings file](#6-the-settings-file)
7. [Windows and Ally settings](#7-windows-and-ally-settings)
8. [In-game settings](#8-in-game-settings)
9. [Expected performance](#9-expected-performance)
10. [Troubleshooting](#10-troubleshooting)
11. [Settings that made things worse](#11-settings-that-made-things-worse)
12. [Updating to a newer Longshot](#12-updating-to-a-newer-longshot)
13. [Uninstalling](#13-uninstalling)
14. [License and credits](#14-license-and-credits)

## 1. What's in this fork

| Repository | Based on | Status |
|---|---|---|
| **longshot-ally** (this one) | Longshot `bbe7a07` (15 Nov 2026) + the Ally patches | Builds with no errors. **Not tested in play on the Ally yet.** |
| [hookshot-ally](https://github.com/alejadxr/hookshot-ally) | Hookshot `15646d1` (11 Nov 2026) + the same patches (v5) | The version played every day on the Ally. |

### The patches

| Change | File | How to turn it on | Why |
|---|---|---|---|
| Worker threads at normal priority | `gpu/vk/vk_jobs.cpp` | `RX_VK_JOB_PRIO=normal` | They ran below normal priority, so other programs took their CPU when you entered a new area. |
| Priority of the shader preparation | `gpu/vk/vk_draw.cpp` | `RX_VK_PREPARE_PRIO=high` (or `above`, `normal`, `below`) | The first start's shader preparation finishes sooner. |
| Pipeline cache saving | `gpu/vk/vk_draw.cpp` | always | During play the cache file (~900 MB) was rewritten in full about 15 times per session. Now it is saved only when it has grown enough. |
| Optimized task/mesh fallback | `gpu/vk/vk_draw.cpp` | always (`RX_VK_FALLBACK_NOOPT=1` turns it off) | Without the optimizer, the world's geometry cost ~21 ms of GPU time per frame on the 780M. |
| New surface when the swapchain keeps failing | `gpu/vk/vk_main.cpp` | always | After pressing F11 twice the picture froze (400+ retries). |
| Present fallback in frame generation | `gpu/vk/vk_framegen.cpp` | always | The screen froze while the game kept running (it happened while playing the ocarina). |
| The Ally's gyroscope at 10 ms | `host/hos_imu_rate.c` | always (Windows only) | Windows only sent the Bosch sensor's readings once they passed a threshold: slow aiming moved in steps, and the game turned the gyroscope off every few seconds. |

### What's in the repository

- `GUIDE.md` and `GUIA.md`: this guide, in English and Spanish.
- `ally/longshot_env.txt`: the Ally's settings file ([section 6](#6-the-settings-file)).
- `ally/compilar/`: the Docker build for Linux and macOS (`compilar` means "build").
- `ally/windows/`: a launcher with higher priority, and the registry settings.
- `ally/patches/longshot-ally.diff`: the patches as one file, to apply them to a newer Longshot.
- `README.longshot.md`: Longshot's original README.

The original code and ours are in separate commits: `git show 3cefeec` shows exactly the patches. The only thing taken
out of Longshot is `assets/saves/kokiri-start`, a test save the game doesn't need.

## 2. Requirements

- **A ROG Ally or Ally X** with a Ryzen Z1 or Z1 Extreme. Other chips work, but read about `RX_MARCH` in
  [section 4](#4-building).
- **Windows 11** with the **AMD driver 32.0.32015 (October 2026) or newer**.
- **Your own copy of the game**, in the one version Longshot supports: program `0400486024DEC000`, update `v131072`,
  build `e0f3ccfa`. It can be a `.nup` file, or the `romfs` and `exefs` folders (`--romfs` and `--exefs` instead of
  `--nup`). Add `--check` to the build command to check your copy without building anything.
- **Disk space:** the game folder takes ~26 GB, and the build's work folder ~3 GB more. Keep at least 40 GB free.
- **Something to build on:** a Windows PC (the Ally itself works), or Linux or macOS with Docker.

## 3. Quick start

1. Build the game from your copy ([section 4](#4-building)).
2. Copy the output folder to the Ally, for example to `C:\Games\Longshot`.
3. Copy `ally/longshot_env.txt` and `ally/windows/lanzar.bat` into that folder, next to `image.bin`.
4. Double-click `ally/windows/ajustes_ally.reg` once, then restart Windows.
5. In Armoury Crate, set the GPU memory to 4 GB and pick Turbo. Plug in the charger.
6. Start the game with `lanzar.bat`. The first start prepares the shaders and takes a while.

## 4. Building

The build reads your copy of the game and writes the game folder for Windows.

### Option A: on Windows (the Ally itself or another PC)

These are the steps in Longshot's documentation for building from source (`README.longshot.md`), using this repository
instead of the official one. Run them in a Command Prompt (`cmd`):

1. Install [Python 3](https://www.python.org/downloads/) and [Git](https://git-scm.com/download/win).
2. Clone the repository and install the Python packages:
   ```bat
   git clone https://github.com/alejadxr/longshot-ally.git
   cd longshot-ally
   py -m pip install -r requirements.txt
   ```
3. Download `llvm-mingw-20261104-ucrt-x86_64.zip` from
   [mstorsjo/llvm-mingw](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261104). Unzip it inside the clone and rename
   the folder to `llvm-mingw`, so that `llvm-mingw\bin\clang.exe` exists.
4. Download the Windows `cpm` package (the Vulkan and SPIR-V headers, VMA and FFmpeg):
   [cpm-windows-x64](https://git-cdn.magicbean.dev/api/packages/MagicBeanDev/generic/cpm-windows-x64/hookshot-v2.1.0-dav1d-1.5.4/4eeae3a8d50118dd5c15f2c18dcdc452fbf1dfafceeffcad3bca97aadffe829b-cpm.zip)
   (it's the `tool cpm ... windows-x64` line in `tools.lock`). Unzip it inside the clone, so that `cpm\vulkanheaders`
   exists.
5. Build:
   ```bat
   set LONGSHOT_MINGW=%CD%\llvm-mingw
   set RX_CPM=%CD%\cpm
   py -I nx2/make_game.py --nup "C:\path\to\your-game.nup" --out "C:\Games\Longshot"
   ```
   On the Ally itself that's all: the build picks the CPU on its own. To build on **another** PC for the Ally, also run
   `set RX_MARCH=znver4` before building.

### Option B: Linux or macOS with Docker (what we used)

```sh
git clone https://github.com/alejadxr/longshot-ally.git
cd longshot-ally
ally/compilar/compilar.sh /path/to/your-game.nup ~/LongshotAlly
```

The script downloads llvm-mingw and `cpm` and checks their SHA-256, builds the Docker image, and builds the game for
Windows. The options are at the top of [`ally/compilar/compilar.sh`](ally/compilar/compilar.sh):

- `RX_MARCH`: the CPU the game is built for. The default is `znver4`, for the Ryzen Z1, Z1 Extreme and Z2 Extreme.
  **If your handheld has a Zen 2 or Zen 3 chip** (for example the ROG Xbox Ally with the Z2 A), use `RX_MARCH=x86-64-v3`.
  Otherwise the game closes as soon as it opens.
- `DOCKER_MEM`: the container's memory. On a Mac Pro with `DOCKER_MEM=44g` and 22 threads the build took 2 h 09 min.
- `WORK`: the work folder (`<output>-work` by default). Keep it: the next build is much faster.

Docker Desktop on a Mac starts with little memory: raise it in its settings. On a Mac with Apple Silicon the container
runs emulated as x86, and takes much longer.

## 5. Installing on the Ally

1. Copy the whole output folder to the Ally, for example to `C:\Games\Longshot`.
2. Copy [`ally/longshot_env.txt`](ally/longshot_env.txt) into that folder, next to `image.bin`. If the build already
   made a `longshot_env.txt`, add our lines at the end instead of replacing it.
3. Copy [`ally/windows/lanzar.bat`](ally/windows/lanzar.bat) into the same folder and start the game with it. It starts
   the game at above-normal priority.
4. **The first start prepares the shaders.** It takes a while and that's normal. Later starts are quick.

### Saves

When you start the game directly, saves go in `user\save\` inside the game folder.

**To bring your saves from Hookshot:**

1. Close both games.
2. Back up Hookshot's `user\save` folder.
3. Copy its contents into Longshot's `user\save`.

Hookshot and Longshot use the same format and the same user id (`docs/saves-script.md`). There is also a script for this:
see `scripts/longshot_saves.py import hookshot` in `docs/saves-script.md`.

## 6. The settings file

`longshot_env.txt` sits in the game folder, next to `image.bin`. The game reads it when it starts, so restart the game
after changing it.

- **Format:** one `NAME=VALUE` per line. Lines that start with `#` are ignored.
- **No end-of-line comments:** they would become part of the value.
- **Priority:** a variable already set in the environment wins over the file.

| Line | What it does |
|---|---|
| `RX_VK_PRECOMPILE=0` | Doesn't compile every area's pipelines at start: 13 GB of committed memory at start instead of 20, no paging, and 80 °C instead of 96 °C. The price is a short stutter (300–500 ms) the first time you see something new. |
| `RX_VK_PCACHE_LOAD=0` | Doesn't load the game's pipeline cache (~900 MB) into RAM; the AMD driver's own disk cache stays. Free RAM in play went from ~30 MB to 2–3.6 GB. |
| `RX_VK_KEEP_RETIRED=0` | Releases imported memory the game no longer uses. |
| `RX_VK_IMPORT_HIGH=85` | Evicts idle imports when the import heap is 85 % full. With 16 GB, without these two lines the picture ends up frozen (`present/submit failed (-2)`). |
| `RX_VK_VRAM_MB=2560` | The texture budget. **Don't raise it to 3072:** that gave DEVICE_LOST and blue screen `0x119` when loading areas. |
| `RX_VK_PASS_BARRIER=game` | About 10 % less GPU work. |
| `RX_VK_MESH_OPT=1` | Mesh shader optimizer. Needs the October 2026 AMD driver or newer. |
| `RX_VK_NO_READBACK_WAIT=1` | Doesn't wait for readbacks from the GPU. |
| `RX_VK_JOB_PRIO=normal` | (patch) Worker threads at normal priority. |
| `RX_VK_PREPARE_PRIO=high` | (patch) Shader preparation at high priority. |
| `RX_VK_MESH_NOCULL=2c56dc1006942f74` | Longshot's fix for the hang in Kokiri Forest on handheld AMD GPUs (`docs/common-issues.md`). |

**On a ROG Ally X (24 GB)** there is more RAM to spare: you can try deleting `RX_VK_PRECOMPILE=0` and `RX_VK_PCACHE_LOAD=0`
for fewer stutters. We haven't tested that.

## 7. Windows and Ally settings

This changes performance more than any patch:

- **AMD driver 32.0.32015 (October 2026) or newer.** With the May driver, mesh shaders hung the GPU when the opening
  cutscene ended (DEVICE_LOST). If you have to stay on an old driver, add `RX_VK_TASK_MESH_FALLBACK=1` and remove
  `RX_VK_MESH_OPT=1` from `longshot_env.txt`.
- **GPU memory at 4 GB in Armoury Crate.** With 16 GB of RAM, giving the GPU more makes the game page to disk and stutter.
  With 4 GB, Windows sees ~12 GB.
- **[`ally/windows/ajustes_ally.reg`](ally/windows/ajustes_ally.reg)** (double-click it, then restart) does two things:
  - turns off HAGS (hardware-accelerated GPU scheduling), which gave an AMD driver blue screen `0x119`;
  - gives the GPU 10 s instead of 2 before Windows resets it.

  `deshacer_ajustes_ally.reg` puts both back as they were.
- **Turbo mode in Armoury Crate, always plugged in.** On battery the chip drops to 14–25 W.
- **On a TV through a USB-C hub**, the Ally stays at ~25 W whatever the profile says. Use a 65 W charger or stronger
  (100 W is best) in the hub's PD port.
- **Windows desktop at 1920×1080.** If it's at another resolution, the game renders at that one and stretches it.
- **Close the Xbox Game Bar and other background apps.** RAM is very tight.

## 8. In-game settings

What worked best for us:

- output at 1920×1080;
- render at 50–58 % with FSR 3.1;
- the game's frame generation on;
- anisotropic filtering at 8x.

The AMD driver's AFMF feels worse than the game's own frame generation: leave it off.

## 9. Expected performance

Measured with hookshot-ally and the settings above:

- **Plugged in, Turbo (30–45 W):** 32–37 real fps in normal areas and 20–26 in the heaviest (~2000 draws). Frame
  generation doubles that. The GPU is usually the limit (the 780M at 2.4–2.6 GHz).
- **Through a hub at 25 W, at 960×540:** 21–36 real fps.
- **Entering a new area:** a short stutter while its pipelines compile. That's the price of `RX_VK_PRECOMPILE=0`.

## 10. Troubleshooting

| What happens | Why | What to do |
|---|---|---|
| The game closes as soon as it opens | It was built for a newer CPU than yours | Build again with `RX_MARCH=x86-64-v3`. |
| The first start takes very long | It's preparing the shaders | Normal, only the first time. |
| A short stutter in each new area | It compiles that area's pipelines (`RX_VK_PRECOMPILE=0`) | Normal. |
| The picture freezes while the game goes on | Out of memory for imports | Check `RX_VK_KEEP_RETIRED=0`, `RX_VK_IMPORT_HIGH=85` and GPU memory at 4 GB, and close background apps. |
| DEVICE_LOST when the opening cutscene ends | An old AMD driver and mesh shaders | Update the driver, or use `RX_VK_TASK_MESH_FALLBACK=1` (see section 7). |
| Blue screen `0x119`, or DEVICE_LOST when loading an area | Texture budget too high, or HAGS on | `RX_VK_VRAM_MB=2560` and `ajustes_ally.reg`. |
| Stuck at ~25 W on a hub | The charger is too weak | 65 W or more in the hub's PD port. |
| Blurry or stretched picture | The Windows desktop isn't at 1920×1080 | Set the desktop to 1920×1080. |
| Some textures go black for a moment | The texture budget (2560 MB) is full | Known trade-off. Raising it causes the crashes above. |

The game writes its log in the `logs\` folder inside the game folder: attach it when you report a problem.

## 11. Settings that made things worse

| Setting | What happened |
|---|---|
| `RX_VK_VRAM_MB=3072` | DEVICE_LOST and blue screen `0x119` when loading areas or saves. With 2560 it hasn't happened again. |
| `RX_VK_DRIVER_FAULTS=3` (hookshot-ally only) | DEVICE_LOST when loading the save. |
| `RX_VK_RECORDER=thread` | CPU replay went up to 38 ms per frame. |
| `RX_VK_PER_QUEUE_FENCES=0` + `RX_VK_UPLOAD_BUDGET_MS=8` + `RX_VK_TEX_CAPTURE=0` + `RX_VK_MIRROR_MB=256` | Under 1 fps. |
| `RX_VK_UPLOAD_BUDGET_MS=16` | Flickering textures. |
| `RX_VK_IMAGE_BLOCK_MB=64` | Saved no memory. |
| The AMD driver's AFMF | Felt worse than the game's frame generation. |

## 12. Updating to a newer Longshot

```sh
git clone https://git.magicbean.dev/MagicBeanDev/Longshot.git
cd Longshot
git apply --3way /path/to/longshot-ally/ally/patches/longshot-ally.diff
```

If a hunk no longer fits because Longshot changed that code, `--3way` leaves the conflict marked in the file so you can
fix it by hand. Then build as in [section 4](#4-building).

## 13. Uninstalling

1. Back up `user\save\` from the game folder.
2. Delete the game folder. The caches are inside it, in `cache\`.
3. To undo the registry settings, double-click `ally/windows/deshacer_ajustes_ally.reg` and restart.

## 14. License and credits

GPL-3.0, like Longshot and Hookshot (see [LICENSE](LICENSE)).

- Longshot is by Team MagicBean, and Hookshot by NotRexed and its contributors. This fork only adds what is described
  above.
- It is unofficial: report problems with these patches here, not to Longshot.
