using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Core\RunspaceEngine.psm1"

Describe "Asynchronous Runspace Engine Execution" {
    It "Should execute task script blocks inside background runspace pool" {
        $contextType = [Type]"Context"
        $contextType::Silent = $true

        $task = {
            param($val)
            Start-Sleep -Milliseconds 100
            return "Runspace_$val"
        }

        $res = [RunspaceEngine]::ExecuteAsync($task, "TestArg")
        $res | Should Not BeNullOrEmpty
        $res[0] | Should Be "Runspace_TestArg"

        $contextType::Silent = $false
    }
}
