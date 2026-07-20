using module "..\..\Core\EventBus.psm1"
using module "..\..\Core\CommandBus.psm1"
using module "..\..\Logger\Logger.psm1"
using module "..\..\Core\RunspaceEngine.psm1"

Describe "Asynchronous Runspace Engine Execution" {
    It "Should execute task script blocks inside background runspace pool" {
        $taskSb = {
            param($val)
            return "RunspaceOutput: $val"
        }

        $result = [RunspaceEngine]::ExecuteTask($taskSb, @("ApexTest"))
        $result | Should Be "RunspaceOutput: ApexTest"
    }
}
