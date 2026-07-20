using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Domain\Repair\RepairDomain.psm1"

Describe "System Configuration Repair Domain" {
    It "Should simulate repair commands when dry-run is enabled" {
        $contextType = [Type]"Context"
        $contextType::DryRun = $true
        [RepairDomain]::Run()
        $contextType::DryRun = $false
    }
}
