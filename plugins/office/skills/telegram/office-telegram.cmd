@echo off
rem office-telegram-version: 1
rem Abre la oficina remota por Telegram de dev-office (office-telegram.sh) con el
rem bash de Git for Windows, desde CMD o PowerShell. Acepta los mismos comandos:
rem   .claude\office-telegram.cmd status
rem   .claude\office-telegram.cmd on
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
"%OFFICE_BASH%" "%~dp0office-telegram.sh" %*
exit /b %ERRORLEVEL%
