# Shared helpers for the tool scripts. Dot-source it:  . "$PSScriptRoot\common.ps1"
# Works in Windows PowerShell 5.1.

$script:ProjectRoot = Split-Path -Parent $PSScriptRoot

function Get-GodotPath {
    if ($env:GODOT_PATH -and (Test-Path $env:GODOT_PATH)) { return $env:GODOT_PATH }
    $dir = Join-Path $env:LOCALAPPDATA 'Programs\Godot'
    $exe = Get-ChildItem -Path $dir -Filter 'Godot_v4.7*_console.exe' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $exe) { throw "Godot 4.7 not found in $dir. Set GODOT_PATH." }
    return $exe.FullName
}

# Runs a program, returns @{ Code = exit code; Output = all text it printed }.
function Invoke-Tool {
    param([string]$Exe, [string[]]$Arguments, [string]$WorkDir = $script:ProjectRoot)
    $out = [System.IO.Path]::GetTempFileName()
    $err = [System.IO.Path]::GetTempFileName()
    try {
        $quoted = $Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
        $p = Start-Process -FilePath $Exe -ArgumentList $quoted -WorkingDirectory $WorkDir `
            -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $text = (Get-Content $out -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content $err -Raw -ErrorAction SilentlyContinue)
        return @{ Code = $p.ExitCode; Output = $text }
    }
    finally {
        Remove-Item $out, $err -ErrorAction SilentlyContinue
    }
}

function Invoke-Godot {
    param([string[]]$Arguments)
    return Invoke-Tool -Exe (Get-GodotPath) -Arguments (@('--path', $script:ProjectRoot) + $Arguments)
}

# Lines that mean a script is broken. Leak notices at exit are not errors.
function Get-ScriptErrors {
    param([string]$Text)
    return @($Text -split "`r?`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error|Invalid call|Invalid access|Nonexistent function|null instance' })
}
