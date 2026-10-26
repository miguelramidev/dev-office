@echo off
rem office-agents-version: 1
rem Abre la configuracion de proveedores de dev-office (office-agents.sh) con el
rem bash de Git for Windows, desde CMD o PowerShell. Acepta los mismos comandos:
rem   .claude\office-agents.cmd
rem   .claude\office-agents.cmd set backend.developer codex
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
  exit /b 1
)
"%OFFICE_BASH%" "%~dp0office-agents.sh" %*
exit /b %ERRORLEVEL%
