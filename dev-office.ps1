# Instala, desinstala o reinstala la oficina dev-office en un proyecto, desde PowerShell.
# Busca el bash de Git for Windows, baja dev-office.sh y lo corre en la carpeta actual.
#
# En la carpeta del proyecto:
#   irm https://raw.githubusercontent.com/miguelramidev/dev-office/main/dev-office.ps1 | iex
#
# Desde una copia del repositorio también se puede: .\dev-office.ps1 (o con install, uninstall...).

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$source = 'https://raw.githubusercontent.com/miguelramidev/dev-office/main/dev-office.sh'

# El bash de Git for Windows (no el de WSL, que no ve los programas de Windows).
$bash = $null
$candidates = @(
  "$env:ProgramFiles\Git\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
  "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) { $candidates += Join-Path (Split-Path (Split-Path $git.Source)) 'bin\bash.exe' }
foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { $bash = $c; break } }

if (-not $bash) {
  Write-Host 'Falta Git for Windows: la oficina lo necesita (sus scripts corren con su bash).'
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    $answer = Read-Host '¿Lo instalo ahora con winget? [S/n]'
    if ($answer -eq '' -or $answer -match '^[sSyY]') {
      winget install --id Git.Git -e --source winget
      Write-Host 'Listo. Cerrá esta terminal, abrí una nueva y volvé a correr el comando.'
    }
  } else {
    Write-Host 'Instalalo desde https://git-scm.com/download/win y volvé a correr el comando.'
  }
  return
}

# El script: el de al lado si esto se corre desde una copia del repositorio; si no, se baja.
$script = $null
if ($PSCommandPath) {
  $local = Join-Path (Split-Path $PSCommandPath) 'dev-office.sh'
  if (Test-Path $local) { $script = $local }
}
if (-not $script) {
  $script = Join-Path $env:TEMP 'dev-office.sh'
  Invoke-WebRequest -UseBasicParsing -Uri $source -OutFile $script
}

$project = (Get-Location).ProviderPath
& $bash ($script -replace '\\', '/') --project ($project -replace '\\', '/') @args
