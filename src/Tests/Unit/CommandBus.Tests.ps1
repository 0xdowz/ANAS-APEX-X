using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"

Describe "CommandBus CLI Parsing and Routing" {
    BeforeEach {
        $script:savedHandlers = [CommandBus]::Handlers.Clone()
        [CommandBus]::Handlers.Clear()
    }

    AfterEach {
        [CommandBus]::Handlers.Clear()
        if ($null -ne $script:savedHandlers) {
            foreach ($key in $script:savedHandlers.Keys) {
                [CommandBus]::Handlers[$key] = $script:savedHandlers[$key]
            }
        }
    }

    It "Should parse command line parameters correctly" {
        $raw = @("optimize", "--verbose", "--dry-run", "--profile", "gaming")
        $payload = [CommandBus]::Parse($raw)

        $payload.Command | Should Be "optimize"
        $payload.Verbose | Should Be $true
        $payload.DryRun | Should Be $true
        $payload.Arguments.profile | Should Be "gaming"
    }

    It "Should parse flags with no command parameter" {
        $raw = @("--help")
        $payload = [CommandBus]::Parse($raw)
        $payload.Help | Should Be $true
    }

    It "Should execute registered command handlers" {
        $script:commandRun = $false
        [CommandBus]::RegisterHandler("testcommand", {
            param($payload)
            $script:commandRun = $true
        })

        [CommandBus]::Dispatch(@("testcommand"))
        $script:commandRun | Should Be $true
    }
}
