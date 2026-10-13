$ErrorActionPreference = 'Stop'
$movingDayRoot = Split-Path $PSScriptRoot -Parent
Push-Location $movingDayRoot
try {
    New-Item -ItemType Directory -Force build | Out-Null
    $profileStoreHash = (Get-FileHash src/server/Vendor/ProfileStore.luau -Algorithm SHA256).Hash
    if ($profileStoreHash -ne 'AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F') { throw 'Pinned ProfileStore bytes changed' }
    & stylua --check src tests tools/board
    if ($LASTEXITCODE) { throw 'StyLua failed' }
    & selene src tests tools/board
    if ($LASTEXITCODE) { throw 'Selene failed' }
    & lune run tests/contracts
    if ($LASTEXITCODE) { throw 'Lune tests failed' }
    & lune run tests/job-economy
    if ($LASTEXITCODE) { throw 'Job/economy tests failed' }
    & lune run tests/server-logic
    if ($LASTEXITCODE) { throw 'Server logic tests failed' }
    & lune run tests/item-service
    if ($LASTEXITCODE) { throw 'Item service tests failed' }
    & lune run tests/profile-data
    if ($LASTEXITCODE) { throw 'Profile data tests failed' }
    & lune run tests/crews
    if ($LASTEXITCODE) { throw 'Crew tests failed' }
    & lune run tests/jobs
    if ($LASTEXITCODE) { throw 'Job lifecycle tests failed' }
    & lune run tests/analytics
    if ($LASTEXITCODE) { throw 'Analytics tests failed' }
    & lune run tests/upgrades
    if ($LASTEXITCODE) { throw 'Upgrade tests failed' }
    & lune run tests/receipts
    if ($LASTEXITCODE) { throw 'Receipt tests failed' }
    & lune run tests/pings
    if ($LASTEXITCODE) { throw 'Ping tests failed' }
    & rojo build -o build/moving-day.rbxlx
    if ($LASTEXITCODE) { throw 'Rojo build failed' }
    & rojo build fallback.project.json -o build/fallback.rbxlx
    if ($LASTEXITCODE) { throw 'Fallback Rojo build failed' }
} finally {
    Pop-Location
}
