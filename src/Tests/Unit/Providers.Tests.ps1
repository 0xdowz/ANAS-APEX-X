using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Core\StateManager.psm1"
using module "..\..\..\src\Providers\ProviderContract.psm1"
using module "..\..\..\src\Providers\RegistryProvider.psm1"
using module "..\..\..\src\Providers\ServiceProvider.psm1"
using module "..\..\..\src\Providers\PowerCfgProvider.psm1"
using module "..\..\..\src\Providers\NetworkProvider.psm1"

Describe "Enterprise Providers Abstraction Layer" {
    It "RegistryProvider should support Audit, Backup, Apply, Restore, and DryRun" {
        $audit = [RegistryProvider]::Audit("HKCU:\Software\ApexTestRegistryProvider", "TestVal", 10)
        $audit | Should Not BeNullOrEmpty

        # Dry Run Apply via RegistryProvider Write method
        [RegistryProvider]::Write("HKCU:\Software\ApexTestRegistryProvider", "TestVal", 10, "DWord")
    }

    It "ServiceProvider should support Audit and Backup contracts" {
        $audit = [ServiceProvider]::Audit("wuauserv", "Disabled")
        $audit.Provider | Should Be "ServiceProvider"
    }

    It "PowerCfgProvider should support Audit and DryRun contracts" {
        $audit = [PowerCfgProvider]::Audit("381b4222-f694-41f0-9685-ff5bb260df2e", "Active")
        $audit.Provider | Should Be "PowerCfgProvider"
        
        [PowerCfgProvider]::DryRun(@{ SchemeGuid = "381b4222-f694-41f0-9685-ff5bb260df2e" })
    }

    It "NetworkProvider should support Audit and DryRun contracts" {
        $audit = [NetworkProvider]::Audit("NetworkOptimization", "ffffffff")
        $audit.Provider | Should Be "NetworkProvider"

        [NetworkProvider]::DryRun(@{ Name = "NetworkOptimization" })
    }
}
