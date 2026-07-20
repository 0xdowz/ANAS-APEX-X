using module "..\..\..\src\Core\EventBus.psm1"
using module "..\..\..\src\Core\CommandBus.psm1"
using module "..\..\..\src\Logger\Logger.psm1"
using module "..\..\..\src\Core\StateManager.psm1"
using module "..\..\..\src\Providers\RegistryProvider.psm1"
using module "..\..\..\src\Providers\ServiceProvider.psm1"
using module "..\..\..\src\Core\CapabilityEngine.psm1"
using module "..\..\..\src\Core\RuleEngine.psm1"

Describe "Rule DSL Engine Schema Parsing" {
    $RootPath = (Get-Item (Join-Path $PSScriptRoot "../../..")).FullName
    [StateManager]::Initialize($RootPath)

    It "Should evaluate OSVersion constraints correctly" {
        # Check high constraint (should fail)
        $constraints = @(
            [PSCustomObject]@{ Type = "OSVersion"; MinBuild = 999999 }
        )
        $res = [RuleEngine]::EvaluateConstraints($constraints)
        $res | Should Be $false

        # Check low constraint (should pass)
        $constraintsPass = @(
            [PSCustomObject]@{ Type = "OSVersion"; MinBuild = 10000 }
        )
        $resPass = [RuleEngine]::EvaluateConstraints($constraintsPass)
        $resPass | Should Be $true
    }

    It "Should parse and apply registry rules" {
        $contextType = [Type]"Context"
        $contextType::DryRun = $false

        $testKey = "HKCU:\Software\ApexRuleTest"
        if (Test-Path $testKey) {
            Remove-Item -Path $testKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }

        $rule = [PSCustomObject]@{
            Name = "RuleTest"
            Description = "Test DSL Rule applying a registry key"
            Constraints = @()
            Actions = @(
                [PSCustomObject]@{
                    Type = "Registry"
                    Key = $testKey
                    Value = "TestVal"
                    Data = "HelloDSL"
                    Kind = "String"
                }
            )
        }

        [RuleEngine]::ApplyRule($rule)

        Test-Path $testKey | Should Be $true
        $val = (Get-ItemProperty -Path $testKey).TestVal
        $val | Should Be "HelloDSL"

        # Clean up
        Remove-Item -Path $testKey -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    It "Should parse and apply rules directly from external JSON DSL file" {
        $contextType = [Type]"Context"
        $contextType::DryRun = $true

        $gamingRulesFile = Join-Path $RootPath "rules/gaming.json"
        Test-Path $gamingRulesFile | Should Be $true

        # Applying rules from file in dry-run mode should execute smoothly
        [RuleEngine]::ApplyRulesFromFile($gamingRulesFile)

        $contextType::DryRun = $false
    }
}
