# gbbat.ps1 - Convert a UTF-8 .bat to GB18030 (no BOM, CRLF), or verify it.
#
# Usage:
#   powershell -File gbbat.ps1 -Path C:\path\file.bat            # convert UTF-8 -> GB18030
#   powershell -File gbbat.ps1 -Path C:\path\file.bat -Verify    # check BOM / CRLF
#
# WARNING: convert mode assumes the SOURCE file is UTF-8. Converting a file
# that is already GB18030 destroys its Chinese text (double re-encoding).
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$Verify
)

$gb = [System.Text.Encoding]::GetEncoding(54936)
$Path = [System.IO.Path]::GetFullPath($Path)

if (-not (Test-Path $Path)) {
    Write-Error "file not found: $Path"
    exit 2
}

if ($Verify) {
    $b = [System.IO.File]::ReadAllBytes($Path)
    $s = $gb.GetString($b)
    $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    $loneLf = [regex]::Matches($s, "[^`r]`n").Count
    Write-Output "file:    $Path"
    Write-Output "BOM:     $bom"
    Write-Output "lone LF: $loneLf"
    Write-Output "size:    $($b.Length) bytes"
    if ($bom -or $loneLf -gt 0) { exit 1 }
    exit 0
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$txt = [System.IO.File]::ReadAllText($Path, $utf8)
$txt = ($txt -replace "`r`n", "`n") -replace "`n", "`r`n"
[System.IO.File]::WriteAllBytes($Path, $gb.GetBytes($txt))
Write-Output "converted to GB18030 (no BOM, CRLF): $Path"
exit 0
