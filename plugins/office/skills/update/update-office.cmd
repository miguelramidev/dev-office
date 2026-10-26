@echo off
rem update-office-version: 1
rem Actualiza la oficina dev-office en todos tus proyectos con un doble click.
rem Abre update-office.sh (en la misma carpeta) con el bash de Git for Windows.
setlocal
set "OFFICE_BASH="
for %%G in ("%ProgramFiles%\Git\bin\bash.exe" "%ProgramFiles(x86)%\Git\bin\bash.exe" "%LocalAppData%\Programs\Git\bin\bash.exe") do (
  if not defined OFFICE_BASH if exist "%%~G" set "OFFICE_BASH=%%~G"
)
if not defined OFFICE_BASH (
  for /f "delims=" %%G in ('where bash 2^>nul ^| findstr /v /i "\\Windows\\"') do (
    if not defined OFFICE_BASH set "OFFICE_BASH=%%G"
  )
)
if not defined OFFICE_BASH (
  echo No encontre el bash de Git for Windows. Instalalo con: winget install Git.Git
  pause
  exit /b 1
)
"%OFFICE_BASH%" "%~dp0update-office.sh"
exit /b %ERRORLEVEL%
