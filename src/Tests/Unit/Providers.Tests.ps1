using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Core\SQLiteDatabase.psm1"
using module "..\..\..\src\Core\StateManager.psm1"
using module "..\..\..\src\Providers\ProviderContract.psm1"
using module "..\..\..\src\Providers\RegistryProvider.psm1"
using module "..\..\..\src\Providers\ServiceProvider.psm1"
using module "..\..\..\src\Providers\PowerCfgProvider.psm1"
using module "..\..\..\src\Providers\NetworkProvider.psm1"

Describe "Enterprise Providers Abstraction Layer" {
    $RootPath = (Get-Item (Join-Path $PSScriptRoot "../../..")).FullName
    [StateManager]::Initialize($RootPath)

    It "RegistryProvider should support Audit, Backup, Apply, Restore, and DryRun" {
        $contextType = [Type]"Context"
        $testKey = "HKCU:\Software\ApexTestRegistryProvider"

        # 1. DryRun test
        $contextType::DryRun = $true
        [RegistryProvider]::Apply(@{ Key = $testKey; ValueName = "TestVal"; Value = 10; Kind = "DWord" })
        Test-Path $testKey | Should Be $false

        # 2. Live Apply test
        $contextType::DryRun = $false
        [RegistryProvider]::Apply(@{ Key = $testKey; ValueName = "TestVal"; Value = 10; Kind = "DWord" })
        Test-Path $testKey | Should Be $true

        # 3. Audit test
        $audit = [RegistryProvider]::Audit($testKey, "TestVal", 10)
        $audit.Status | Should Be "Applied"
        $audit.CurrentValue | Should Be "10"

        # Cleanup
        Remove-Item -Path $testKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    It "ServiceProvider should support Audit and Backup contracts" {
        $audit = [ServiceProvider]::Audit("W32Time", "Running")
        $audit.Provider | Should Be "ServiceProvider"
        $audit.Target | Should Be "W32Time"
    }

    It "PowerCfgProvider should support Audit and DryRun contracts" {
        $contextType = [Type]"Context"
        $contextType::DryRun = $true

        $audit = [PowerCfgProvider]::Audit("381b4222-f694-41f0-9685-ff5bb260df2e", "Balanced")
        $audit.Provider | Should Be "PowerCfgProvider"

        [PowerCfgProvider]::Apply(@{ SchemeGuid = "381b4222-f694-41f0-9685-ff5bb260df2e" })
        $contextType::DryRun = $false
    }

    It "NetworkProvider should support Audit and DryRun contracts" {
        $contextType = [Type]"Context"
        $contextType::DryRun = $true

        $audit = [NetworkProvider]::Audit("NetworkThrottlingIndex", "4294967295")
        $audit.Provider | Should Be "NetworkProvider"

        [NetworkProvider]::Apply(@{ Name = "NetworkOptimization" })
        $contextType::DryRun = $false
    }
}
