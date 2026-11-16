@echo off
rem Abre el juego con prioridad por encima de lo normal.
rem Copialo a la carpeta del juego (junto a image.bin) y abre el juego con doble clic en este archivo.
cd /d "%~dp0"
for %%E in (longshot.exe bin\longshot.exe hookshot.exe bin\hookshot.exe) do (
    if exist "%%E" (
        start "" /abovenormal "%%E"
        exit /b 0
    )
)
echo No encuentro longshot.exe ni hookshot.exe en %~dp0
pause
