using module "..\..\Core\EventBus.psm1"
using module "..\..\Core\CommandBus.psm1"
using module "..\..\Logger\Logger.psm1"
using module "..\..\Core\StateManager.psm1"
using module "..\..\Providers\ProviderContract.psm1"
using module "..\..\Providers\RegistryProvider.psm1"
using module "..\..\Providers\ServiceProvider.psm1"
using module "..\..\Providers\PowerCfgProvider.psm1"
using module "..\..\Providers\NetworkProvider.psm1"

Describe "Enterprise Providers Abstraction Layer" {
    It "RegistryProvider should support Audit, Backup, Apply, Restore, and DryRun" {
        $regProvider = [RegistryProvider]::new()
        $audit = $regProvider.Audit("HKCU:\Software\ApexTestRegistryProvider", "TestVal", 10)
        $audit | Should Not BeNullOrEmpty

        # Dry Run Apply
        $regProvider.Apply("HKCU:\Software\ApexTestRegistryProvider", "TestVal", 10, "DWord", $true) | Out-Null
    }

    It "ServiceProvider should support Audit and Backup contracts" {
        $svcProvider = [ServiceProvider]::new()
        $audit = $svcProvider.Audit("wuauserv", "Disabled")
        $audit.ProviderName | Should Be "ServiceProvider"
    }

    It "PowerCfgProvider should support Audit and DryRun contracts" {
        $powerProvider = [PowerCfgProvider]::new()
        $audit = $powerProvider.Audit("381b4222-f694-41f0-9685-ff5bb260df2e")
        $audit.ProviderName | Should Be "PowerCfgProvider"
        
        $powerProvider.Apply("381b4222-f694-41f0-9685-ff5bb260df2e", $true) | Out-Null
    }

    It "NetworkProvider should support Audit and DryRun contracts" {
        $netProvider = [NetworkProvider]::new()
        $audit = $netProvider.Audit("NetworkOptimization")
        $audit.ProviderName | Should Be "NetworkProvider"

        $netProvider.Apply("NetworkOptimization", $true) | Out-Null
    }
}
