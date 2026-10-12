$ErrorActionPreference = 'Stop'
$movingDayRoot = Split-Path $PSScriptRoot -Parent
Push-Location $movingDayRoot
try {
    New-Item -ItemType Directory -Force build | Out-Null
    & stylua --check src tests tools/board
    if ($LASTEXITCODE) { throw 'StyLua failed' }
    & selene src tests tools/board
    if ($LASTEXITCODE) { throw 'Selene failed' }
    & lune run tests/contracts
    if ($LASTEXITCODE) { throw 'Lune tests failed' }
    & lune run tests/server-logic
    if ($LASTEXITCODE) { throw 'Server logic tests failed' }
    & lune run tests/item-service
    if ($LASTEXITCODE) { throw 'Item service tests failed' }
    & rojo build -o build/moving-day.rbxlx
    if ($LASTEXITCODE) { throw 'Rojo build failed' }
    & rojo build fallback.project.json -o build/fallback.rbxlx
    if ($LASTEXITCODE) { throw 'Fallback Rojo build failed' }
} finally {
    Pop-Location
}
