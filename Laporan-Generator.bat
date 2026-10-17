@echo off
rem ===========================================================================
rem Laporan-Generator.bat - launcher TUI Laporan Generator
rem Butuh PowerShell 7 (pwsh). Pasang dengan: winget install Microsoft.PowerShell
rem ===========================================================================
chcp 65001 >nul
cd /d "%~dp0"

rem Cari pwsh lewat path eksplisit dulu (PATH mesin bisa bermasalah untuk
rem resolusi langsung "pwsh"), lalu fallback ke pencarian PATH.
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe" (
    set "PWSH=%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
    goto :run
)
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
    goto :run
)
where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    set "PWSH=pwsh"
    goto :run
)

echo pwsh ^(PowerShell 7^) tidak ditemukan.
echo Pasang dulu dengan perintah berikut, lalu buka ulang file ini:
echo.
echo   winget install Microsoft.PowerShell
echo.
pause
exit /b 1

:run
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "Laporan-Generator.ps1" %*
pause
