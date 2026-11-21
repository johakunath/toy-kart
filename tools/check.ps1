# All local checks. Run before every handover:
#
#   powershell -ExecutionPolicy Bypass -File tools\check.ps1
#   powershell -ExecutionPolicy Bypass -File tools\check.ps1 -Quick     (parse + one race)
#
# 1. Godot 3 names: scripts must use Godot 4.7 APIs only.
# 2. Import + parse: every script, scene and resource must load. Gamepad mapping and menu flow tests.
# 3. Headless races: the race scene runs by itself, with fake children at the controls.
# Exit code 0 = all good.

param([switch]$Quick)
. "$PSScriptRoot\common.ps1"
$failed = @()

function Report($name, $ok, $detail) {
    if ($ok) { Write-Host ("  PASS  " + $name) -ForegroundColor Green }
    else {
        Write-Host ("  FAIL  " + $name) -ForegroundColor Red
        if ($detail) { $detail | Select-Object -First 25 | ForEach-Object { Write-Host ("        " + $_) } }
        $script:failed += $name
    }
}

Write-Host "Toy Racer checks  (Godot: $(Get-GodotPath))"

# --- 1. No Godot 3 names -----------------------------------------------------------------------
$godot3 = '\b(KinematicBody|Spatial|RigidBody\b(?!3D)|PoolStringArray|PoolVector\w*Array|PoolIntArray|PoolRealArray|Tween\.new\(\)|yield\s*\(|\.instance\s*\(\)|export\s*\(|^\s*export\s+var|^\s*onready\s+var|^\s*tool\s*$|setget\b|\.connect\s*\(\s*"|move_and_slide\s*\([^)]|get_tree\(\)\.change_scene\s*\(|OS\.get_ticks_msec|rand_range\s*\(|\bdeg2rad\b|\brad2deg\b|stepify\s*\(|\.xform\s*\(|translation\b|rect_min_size|rect_position|margin_left|BUTTON_LEFT|KEY_CONTROL\b)'
$hits = @()
Get-ChildItem -Path (Join-Path $ProjectRoot 'scripts'), (Join-Path $ProjectRoot 'tools') -Recurse -Filter *.gd | ForEach-Object {
    $file = $_
    $n = 0
    Get-Content $file.FullName | ForEach-Object {
        $n++
        $code = ($_ -replace '#.*$', '')
        if ($code -match $godot3) { $hits += ("{0}:{1}: {2}" -f $file.Name, $n, $_.Trim()) }
    }
}
Report 'Godot 4.7 names only (no Godot 3 API)' ($hits.Count -eq 0) $hits

# --- 2. Import and parse -----------------------------------------------------------------------
$r = Invoke-Godot @('--headless', '--import')
$errors = Get-ScriptErrors $r.Output
Report 'Import project' ($errors.Count -eq 0) $errors

$r = Invoke-Godot @('--headless', '--script', 'res://tools/parse_check.gd')
$errors = Get-ScriptErrors $r.Output
$ok = ($r.Output -match 'PARSE CHECK: PASS') -and ($errors.Count -eq 0)
Report 'Parse every script, scene and resource' $ok (@($r.Output -split "`r?`n" | Where-Object { $_ -match 'PARSE CHECK|ERROR' }))

$r = Invoke-Godot @('--headless', '--script', 'res://tools/input_check.gd')
$errors = Get-ScriptErrors $r.Output
$ok = ($r.Output -match 'INPUT CHECK: PASS') -and ($errors.Count -eq 0)
Report 'Gamepad mapping: kid and full mode (simulated pad)' $ok (@($r.Output -split "`r?`n" | Where-Object { $_ -match 'INPUT CHECK|ERROR' }))

$r = Invoke-Godot @('--headless', '--fixed-fps', '60', '--script', 'res://tools/menu_check.gd')
$errors = Get-ScriptErrors $r.Output
$ok = ($r.Output -match 'MENU CHECK: PASS') -and ($errors.Count -eq 0)
Report 'Menu flow: pick mode, two players join, race starts, pause' $ok (@($r.Output -split "`r?`n" | Where-Object { $_ -match 'MENU CHECK|ERROR' }))

# --- 3. Headless runs of the race scene --------------------------------------------------------
$scenarios = @(
    @{ Name = 'Race: 2 kids (hands off) + 3 AI, Kid speed'; Args = @('--input=none', '--speed=0') }
)
if (-not $Quick) {
    $scenarios += @(
        @{ Name = 'Race: 2 kids holding left, Kid speed';       Args = @('--input=left', '--speed=0') },
        @{ Name = 'Race: 2 kids mashing buttons, Normal speed'; Args = @('--input=random', '--speed=1') },
        @{ Name = 'Race: kid + full-mode driver, Fast speed';   Args = @('--control=mixed', '--input=right', '--speed=2') },
        @{ Name = 'Race: 1 full-mode driver, no AI';            Args = @('--players=1', '--control=full', '--ai=0', '--speed=1') },
        @{ Name = 'Free drive: 1 kid';                          Args = @('--players=1', '--mode=free') },
        @{ Name = 'Time trial: 1 full-mode driver';             Args = @('--players=1', '--control=full', '--mode=trial', '--speed=1') }
    )
}
foreach ($s in $scenarios) {
    $r = Invoke-Godot (@('--headless', '--fixed-fps', '60', 'res://scenes/race.tscn', '--', '--smoke') + $s.Args)
    $errors = Get-ScriptErrors $r.Output
    $ok = ($r.Output -match 'SMOKE RESULT: PASS') -and ($errors.Count -eq 0) -and ($r.Code -eq 0)
    Report $s.Name $ok (@($r.Output -split "`r?`n" | Where-Object { $_ -match 'SMOKE|ERROR' }))
}

# --- Result ------------------------------------------------------------------------------------
if ($failed.Count -eq 0) {
    Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
    exit 0
}
Write-Host ("CHECKS FAILED: " + ($failed -join '; ')) -ForegroundColor Red
exit 1
