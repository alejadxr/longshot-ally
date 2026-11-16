<h1 align="center">longshot-ally</h1>

<p align="center">
  <b>Longshot for the ROG Ally</b> · <b>Longshot para la ROG Ally</b><br>
  <a href="GUIDE.md">📘 Guide (English)</a> · <a href="GUIA.md">📗 Guía (español)</a>
</p>

---

## English

An unofficial fork of [Longshot](https://git.magicbean.dev/MagicBeanDev/Longshot), the continuation of Hookshot, with
patches and settings for the **ROG Ally (Ryzen Z1 Extreme, 16 GB, Windows 11)**:

- worker and shader-preparation priorities;
- a pipeline cache that isn't rewritten over and over;
- an optimized task/mesh fallback;
- swapchain and frame-generation recovery;
- the Ally's gyroscope at full rate.

It comes with the settings file and the Windows and Ally settings we measured.

> **The game is not included.** No game files, no console keys, no shaders, no caches, no saves. You need your own copy
> of the game, dumped from your own console.

**Status:** builds with no errors; not tested in play on the Ally yet. The version played every day is
[hookshot-ally](https://github.com/alejadxr/hookshot-ally), with the same patches.

**Quick start:**

1. Build from your copy: on Windows, or with `ally/compilar/compilar.sh` and Docker.
2. Copy the output folder, `ally/longshot_env.txt` and `ally/windows/lanzar.bat` to the Ally.
3. Run `ally/windows/ajustes_ally.reg`.
4. Set GPU memory to 4 GB and Turbo, then start the game with `lanzar.bat`.

All the details are in the **[guide](GUIDE.md)**.

## Español

Fork no oficial de [Longshot](https://git.magicbean.dev/MagicBeanDev/Longshot), la continuación de Hookshot, con parches
y ajustes para la **ROG Ally (Ryzen Z1 Extreme, 16 GB, Windows 11)**:

- prioridades de los hilos de trabajo y de la preparación de shaders;
- una caché de pipelines que no se reescribe una y otra vez;
- un fallback de task/mesh optimizado;
- recuperación de la swapchain y de la generación de fotogramas;
- el giroscopio de la Ally a su frecuencia máxima.

Trae el archivo de ajustes y los ajustes de Windows y de la Ally que medimos.

> **No incluye el juego.** Ni archivos del juego, ni claves de consola, ni shaders, ni cachés, ni partidas. Necesitas tu
> propia copia del juego, sacada de tu propia consola.

**Estado:** compila sin errores; todavía no se ha probado jugando en la Ally. La versión que se juega a diario es
[hookshot-ally](https://github.com/alejadxr/hookshot-ally), con los mismos parches.

**Inicio rápido:**

1. Compila a partir de tu copia: en Windows, o con `ally/compilar/compilar.sh` y Docker.
2. Copia a la Ally la carpeta de salida, `ally/longshot_env.txt` y `ally/windows/lanzar.bat`.
3. Ejecuta `ally/windows/ajustes_ally.reg`.
4. Pon la memoria de GPU a 4 GB y el modo Turbo, y abre el juego con `lanzar.bat`.

Todos los detalles están en la **[guía](GUIA.md)**.

---

Longshot's original README: [README.longshot.md](README.longshot.md) · License: GPL-3.0 ([LICENSE](LICENSE)) ·
Longshot by Team MagicBean, Hookshot by NotRexed and contributors.
