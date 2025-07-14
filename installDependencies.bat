
@echo off
:: Check for administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script requires administrator privileges.
    echo Right-click the script and select "Run as administrator".
    pause
    exit /b
)

echo.
echo ==== Installing Chocolatey ====
pause
where choco >nul 2>&1
if %errorlevel% neq 0 (

	powershell -NoProfile -ExecutionPolicy Bypass -Command ^
	"[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"

	:: Make `refreshenv` available right away, by defining the $env:ChocolateyInstall
	powershell -Command $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."   
	powershell -Command Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

	echo ==== Refresh environment ====
	call refreshenv 
)

echo ==== Check of chokolatey was installed ====
where choco >nul 
if %ERRORLEVEL% neq 0 (
    echo Chocolatey installation failed.
)

echo.
echo ==== Checking if Node.js is already on pc ====

where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
	echo ==== Installing Node.js LTS ====
	choco install nodejs-lts 
) else (
	pause
	echo ==== Node already on pc proceeding ====
)

where dotnet >nul 2>&1
if %ERRORLEVEL% neq 0 (
	echo ==== Installing .NET SDK ====
	choco install dotnet-sdk 
) else (
	pause
	echo ==== DotNet already on pc proceeding ====
)

echo.
echo .NET SDK:
dotnet --version

echo.
echo ==== Installing NeoVim and grep ====
choco install -y neovim git ripgrep wget fd unzip gzip mingw make
echo.
echo ==== Installation Complete! ====
pause

echo.
echo ==== Verifying Installations ====
echo Node.js:
node -v
echo npm:
npm -v

