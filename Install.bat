@echo off
chcp 65001 >nul
title Instalador Lazarus Portable Manager
cls

echo ===============================================================================
echo            📦 INSTALADOR LAZARUS PORTABLE MANAGER (WINDOWS)
echo ===============================================================================
echo.

set "DEFAULT_DIR=C:\lazarus"
set /p "TARGET_DIR=Informe o caminho da pasta do Lazarus [%DEFAULT_DIR%]: "

if "%TARGET_DIR%"=="" set "TARGET_DIR=%DEFAULT_DIR%"

echo.
echo [1/4] Verificando diretório de destino: "%TARGET_DIR%"...
if not exist "%TARGET_DIR%\" (
    echo [AVISO] A pasta "%TARGET_DIR%" não existe. Criando diretório...
    mkdir "%TARGET_DIR%"
)

if not exist "%TARGET_DIR%\lazarus.exe" (
    echo ⚠️ ATENÇÃO: lazarus.exe não foi encontrado em "%TARGET_DIR%".
    echo Certifique-se de selecionar a pasta raiz do Lazarus ou seu Pen Drive.
    echo.
)

echo [2/4] Copiando LazarusPortable.exe...
copy /Y "%~dp0LazarusPortable\LazarusPortable.exe" "%TARGET_DIR%\LazarusPortable.exe"
if errorlevel 1 (
    echo ❌ ERRO ao copiar LazarusPortable.exe!
    pause
    exit /b 1
)

echo [3/4] Copiando Manual em HTML e recursos...
if not exist "%TARGET_DIR%\manual" mkdir "%TARGET_DIR%\manual"
copy /Y "%~dp0LazarusPortable\manual\MANUAL.html" "%TARGET_DIR%\manual\MANUAL.html"
copy /Y "%~dp0LazarusPortable\manual\MANUAL.html" "%TARGET_DIR%\MANUAL.html"
if exist "%~dp0LazarusPortable\logo_nova_conect.jpg" (
    copy /Y "%~dp0LazarusPortable\logo_nova_conect.jpg" "%TARGET_DIR%\logo_nova_conect.jpg"
)

echo [4/4] Criando pastas de configuração e backup...
if not exist "%TARGET_DIR%\LazarusConfig" mkdir "%TARGET_DIR%\LazarusConfig"
if not exist "%TARGET_DIR%\Backup" mkdir "%TARGET_DIR%\Backup"

echo.
echo ===============================================================================
echo ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!
echo ===============================================================================
echo Arquivos instalados em: "%TARGET_DIR%"
echo  - %TARGET_DIR%\LazarusPortable.exe
echo  - %TARGET_DIR%\manual\MANUAL.html
echo  - %TARGET_DIR%\MANUAL.html
echo.
echo Pressione qualquer tecla para encerrar...
pause >nul
