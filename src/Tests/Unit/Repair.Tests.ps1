using module "..\..\Core\EventBus.psm1"
using module "..\..\Core\CommandBus.psm1"
using module "..\..\Logger\Logger.psm1"
using module "..\..\Domain\Repair\RepairDomain.psm1"

Describe "System Configuration Repair Domain" {
    It "Should simulate repair commands when dry-run is enabled" {
        $result = [RepairDomain]::Run($true)
        $result.GetType().Name | Should Be "Boolean"
        $result | Should Be $true
    }
}
