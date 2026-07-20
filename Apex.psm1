using module ".\src\Core\EventBus.psm1"
using module ".\src\Core\ModuleRegistry.psm1"
using module ".\src\Core\CommandBus.psm1"
using module ".\src\Logger\Logger.psm1"
using module ".\src\Security\SecurityEngine.psm1"
using module ".\src\Core\StateManager.psm1"
using module ".\src\Core\RuleEngine.psm1"
using module ".\src\Core\RunspaceEngine.psm1"
using module ".\src\Providers\RegistryProvider.psm1"
using module ".\src\Providers\ServiceProvider.psm1"
using module ".\src\Domain\Gaming\GamingDomain.psm1"
using module ".\src\Domain\Network\NetworkDomain.psm1"
using module ".\src\Domain\Analysis\AnalysisDomain.psm1"
using module ".\src\Domain\Benchmark\BenchmarkDomain.psm1"
using module ".\src\Domain\Cleanup\CleanupDomain.psm1"
using module ".\src\Domain\Repair\RepairDomain.psm1"

# ANAS APEX X - Primary PowerShell Module

$ErrorActionPreference = 'Stop'

# Force Console Output to UTF-8 to support box drawing characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Get current script path
$ScriptDir = $PSScriptRoot

# 1. Initialize Registry dynamically at load-time
& ([ScriptBlock]::Create("[ModuleRegistry]::Initialize(`$args[0])")) $ScriptDir

# 2. Register Global Command Handlers for Domain Layer
& ([ScriptBlock]::Create("[CommandBus]::RegisterHandler('optimize', `$args[0])")) {
    param($payload)
    $profileName = "all"
    if ($null -ne $payload.Arguments -and $payload.Arguments.ContainsKey("profile")) {
        $profileName = $payload.Arguments["profile"].ToString().ToLower()
    }
    
    if ($profileName -eq "gaming" -or $profileName -eq "all") {
        & ([ScriptBlock]::Create("[GamingDomain]::Optimize()"))
    }
    if ($profileName -eq "network" -or $profileName -eq "all") {
        & ([ScriptBlock]::Create("[NetworkDomain]::Optimize()"))
    }
}

& ([ScriptBlock]::Create("[CommandBus]::RegisterHandler('analyze', `$args[0])")) {
    param($payload)
    [RunspaceEngine]::ExecuteAsync({
        param($dir)
        & ([ScriptBlock]::Create("[AnalysisDomain]::Run()"))
    }, $ScriptDir)
}

& ([ScriptBlock]::Create("[CommandBus]::RegisterHandler('benchmark', `$args[0])")) {
    param($payload)
    [RunspaceEngine]::ExecuteAsync({
        param($dir)
        & ([ScriptBlock]::Create("[BenchmarkDomain]::Run()"))
    }, $ScriptDir)
}

& ([ScriptBlock]::Create("[CommandBus]::RegisterHandler('clean', `$args[0])")) {
    param($payload)
    [RunspaceEngine]::ExecuteAsync({
        param($dir)
        & ([ScriptBlock]::Create("[CleanupDomain]::Run()"))
    }, $ScriptDir)
}

& ([ScriptBlock]::Create("[CommandBus]::RegisterHandler('repair', `$args[0])")) {
    param($payload)
    [RunspaceEngine]::ExecuteAsync({
        param($dir)
        & ([ScriptBlock]::Create("[RepairDomain]::Run()"))
    }, $ScriptDir)
}

# 3. Main Cmdlet implementation
function Start-Apex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string[]]$RawArgs
    )
    process {
        [CommandBus]::Dispatch($RawArgs)
    }
}

Export-ModuleMember -Function Start-Apex
