@echo off
chcp 65001 >nul
title Compilar Instalador - Lazarus Portable
cls
echo ===============================================================================
echo            🛠️ GERADOR AUTOMÁTICO DO INSTALADOR (INNO SETUP)
echo ===============================================================================
echo.

set "ISCC_PATH="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"

if "%ISCC_PATH%"=="" (
    echo ❌ ERRO: O compilador do Inno Setup (ISCC.exe) não foi encontrado nos caminhos padrão.
    echo Certifique-se de que o Inno Setup 6 está instalado em seu sistema.
    echo.
    pause
    exit /b 1
)

echo Executando Inno Setup: "%ISCC_PATH%" "%~dp0installer.iss"
"%ISCC_PATH%" "%~dp0installer.iss"

if errorlevel 1 (
    echo.
    echo ❌ Ocorreu um erro ao compilar o instalador.
    pause
    exit /b 1
)

echo.
echo ===============================================================================
echo ✅ INSTALADOR GERADO COM SUCESSO!
echo Arquivo gerado em: %~dp0Output\LazarusPortableSetup.exe
echo ===============================================================================
echo.
pause
