@echo off
rem EN: Starts the game at above-normal priority. Copy this file into the game folder (next to image.bin) and double-click it.
rem ES: Abre el juego con prioridad por encima de lo normal. Copialo a la carpeta del juego (junto a image.bin) y haz doble clic.
cd /d "%~dp0"
for %%E in (longshot.exe bin\longshot.exe hookshot.exe bin\hookshot.exe) do (
    if exist "%%E" (
        start "" /abovenormal "%%E"
        exit /b 0
    )
)
echo longshot.exe / hookshot.exe not found in %~dp0 - no se encuentra en esta carpeta.
pause
