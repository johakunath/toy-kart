# Builds the Windows game to builds\ToyKart.exe and proves that the exe starts.
#
#   powershell -ExecutionPolicy Bypass -File tools\export.ps1
#
# Uses the "Windows Desktop" preset in export_presets.cfg (one exe, game data embedded).

. "$PSScriptRoot\common.ps1"
$builds = Join-Path $ProjectRoot 'builds'
$exe = Join-Path $builds 'ToyKart.exe'
New-Item -ItemType Directory -Force $builds | Out-Null

Write-Host "Exporting to $exe ..."
$r = Invoke-Godot @('--headless', '--export-release', 'Windows Desktop', $exe)
$problems = @($r.Output -split "`r?`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|export templates|Cannot export|Project export for preset .* failed' })
if (-not (Test-Path $exe) -or $problems.Count -gt 0) {
    Write-Host "EXPORT FAILED" -ForegroundColor Red
    $problems | ForEach-Object { Write-Host ("  " + $_) }
    exit 1
}
Write-Host ("  built: {0:N1} MB" -f ((Get-Item $exe).Length / 1MB))

# Licence texts travel with the game.
$lic = Join-Path $builds 'licenses'
New-Item -ItemType Directory -Force $lic | Out-Null
Copy-Item (Join-Path $ProjectRoot 'licenses\*') $lic -Force -Exclude '.gdignore'

# Start test 1: the exe runs a whole kid-mode race by itself (no window).
$r = Invoke-Tool -Exe $exe -Arguments @('--headless', '--fixed-fps', '60', '--', '--smoke', '--input=none', '--speed=0') -WorkDir $builds
$race_ok = ($r.Output -match 'SMOKE RESULT: PASS') -and ($r.Code -eq 0)
if ($race_ok) { Write-Host "  PASS  exe runs a 2-player kid race with 3 AI karts" -ForegroundColor Green }
else {
    Write-Host "  FAIL  exe race test" -ForegroundColor Red
    $r.Output -split "`r?`n" | Where-Object { $_ -match 'SMOKE|ERROR' } | Select-Object -First 20 | ForEach-Object { Write-Host ("        " + $_) }
}

# Start test 2: the exe opens its window, draws the menu, saves a picture of it, and quits.
$shot = Join-Path $builds 'menu_check.png'
Remove-Item $shot -ErrorAction SilentlyContinue
$r = Invoke-Tool -Exe $exe -Arguments @('--', '--windowed', "--shot=$shot", '--page=mode') -WorkDir $builds
$menu_ok = (Test-Path $shot) -and ((Get-Item $shot).Length -gt 10000)
if ($menu_ok) { Write-Host "  PASS  exe opens a window and draws the menu ($shot)" -ForegroundColor Green }
else { Write-Host "  FAIL  exe window test" -ForegroundColor Red }

if ($race_ok -and $menu_ok) { Write-Host "EXPORT OK: $exe" -ForegroundColor Green; exit 0 }
exit 1
