using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Core\RunspaceEngine.psm1"

Describe "Asynchronous Runspace Engine Execution" {
    It "Should execute task script blocks inside background runspace pool" {
        $taskSb = {
            param($val)
            return "RunspaceOutput: $val"
        }

        $result = [RunspaceEngine]::ExecuteAsync($taskSb, "ApexTest")
        $result | Should Be "RunspaceOutput: ApexTest"
    }
}
