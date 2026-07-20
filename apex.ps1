$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
if ([string]::IsNullOrEmpty($dir)) {
    $dir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrEmpty($dir)) {
    $dir = Get-Location
}
Import-Module -Name (Join-Path $dir "Apex.psd1") -Force
try {
    Start-Apex -RawArgs $args
}
catch {
    Write-Error $_
    Exit 1
}
